"""
Rapid scan all given positions using photometrics smart streaming.
Python version using pycromanager.

Version History:
    20240318 - integrate mm gui @HF (MATLAB)
    20240416 - renew metadata framework @HF (MATLAB)
    20260430 - convert to Python/pycromanager
"""

import os
import json
import time
from concurrent.futures import ThreadPoolExecutor
import numpy as np
import tifffile
from pycromanager import Core


def trigger_camera(trigger_serial):
    """Send camera exposure trigger via serial port."""
    trigger_cmd = "&CAMEXP#"
    try:
        trigger_serial.write(trigger_cmd.encode())
    except Exception:
        trigger_serial.close()
        trigger_serial.open()
        trigger_serial.write(trigger_cmd.encode())


def rapid_scan_pvcam(mmc, trigger, input_metainfo):
    """
    Rapid scan all given positions using Photometrics SMART Streaming.

    Parameters
    ----------
    mmc : pycromanager.Core
        Micro-Manager core object.
    trigger : serial.Serial
        Serial port object for LED trigger control.
    input_metainfo : dict
        Dictionary containing scan metadata.

    Returns
    -------
    dict
        output_metainfo with acquisition logs.
    """
    output_metainfo = dict(input_metainfo)

    # Load input metainfo parameters
    position_list = input_metainfo["position_list"]
    pos_num = len(position_list)
    roi_x0, roi_y0, roi_w, roi_h = input_metainfo["roi"]
    exposure_seq = input_metainfo["exposure_sequence"]
    chsetup = input_metainfo["chsetup"]
    active_channel_seq = input_metainfo["active_channel_sequence"]
    channel_num = int(len(active_channel_seq))
    data_dir = input_metainfo["data_dir"]

    # Pre-allocate log information
    output_metainfo["log"] = {
        "time_list": [0 for i in range(pos_num)],
        "z_list": [0 for i in range(pos_num)],
    }
	#output_metainfo["log"] = {
    #    "time_list": np.zeros(pos_num, dtype=np.float64),
    #    "z_list": np.zeros(pos_num, dtype=np.float64),
    #}
    output_metainfo["log"]["pfs"] = mmc.get_position("PFSOffset")
    output_metainfo["camera_affine_matrix"] = str(mmc.get_pixel_size_affine_as_string())

    # Initialize Microscope
    # Move to origin position
    mmc.set_property("PFS", "FocusMaintenance", "Off")
    x_ori = position_list[0]["x_um"]
    y_ori = position_list[0]["y_um"]

    mmc.set_xy_position(x_ori, y_ori)
    mmc.set_property("XYStage", "Speed", "51.00mm/sec")
    mmc.set_property("XYStage", "Tolerance", "Open")
    mmc.set_property("Turret1Shutter", "State", "1")  # open shutter
    mmc.wait_for_system()
    mmc.set_property("PFS", "FocusMaintenance", "On")
    z_last_PFS = mmc.get_position("ZDrive")
    mmc.set_roi(roi_x0, roi_y0, roi_w, roi_h)
    W = mmc.get_image_width()
    H = mmc.get_image_height()

    # Generate SMARTStreamingValues string and DLED-Trigger string
    SMARTStreamingValues_ms = ""
    led_seq_string_list = list("&SQ0000#") # example: &SQ2130#  trigger order: TRG2, TRG1, TRG3, disable
    for ch_count in range(channel_num):
        exposure = exposure_seq[ch_count]
        SMARTStreamingValues_ms += f"{exposure:.3f};"
        ch_idx = int(active_channel_seq[ch_count]) - 1 # because we count from 1 in json's chsetup
        led_port = chsetup[ch_idx]["ex_port"] 
        led_seq_string_list[ch_count+3] = f"{led_port}"
    led_seq_string = "".join(led_seq_string_list)

    # Enable Photometrics Smartstreaming and multi-trigger
    mmc.set_property("Camera-1", "SMARTStreamingEnabled", "Yes")
    mmc.set_property("Camera-1", "SMARTStreamingValues[ms]", SMARTStreamingValues_ms)
    mmc.set_property("Camera-1", "Port", "Dynamic Range")
    mmc.set_property("Camera-1", "Trigger-Expose Out-Mux", str(channel_num))
    mmc.set_property("Camera-1", "TriggerMode", "Edge Trigger")
    mmc.set_property("FilterTurret1", "Label", "5-89000 - 00Empty")

    # Initilize D-LED_Trigger
    try:
        trigger.write(led_seq_string.encode())  # send LED control sequence
    except Exception:
        trigger.close()
        trigger.open()
        trigger.write(led_seq_string.encode())
        trigger.read_all()  # clear serial port buffer

    # Continued acquisition
    pos_idx = 1  # 1-based index matching MATLAB
    cur_frame = 1
    tags_list = []
    fname_list = []
    frame_num = channel_num * pos_num

    mmc.clear_circular_buffer()
    if mmc.is_sequence_running():
        mmc.stop_sequence_acquisition()
    mmc.start_sequence_acquisition(frame_num, 0, True)
    time.sleep(1.0)

    # Move and Capture first frame
    x_um = position_list[pos_idx - 1]["x_um"]
    y_um = position_list[pos_idx - 1]["y_um"]
    mmc.set_xy_position(x_um, y_um)
    mmc.wait_for_system()

    start_time = time.time()
    trigger_camera(trigger)

    # Thread pool for non-blocking TIFF writes
    executor = ThreadPoolExecutor(max_workers=3)
    futures = []

    while mmc.get_remaining_image_count() > 0 or mmc.is_sequence_running():
        if mmc.get_remaining_image_count() > 0:
            # Obtain current frame from MM circular buffer
            tagged = mmc.pop_next_tagged_image()
            ch_idx = (cur_frame - 1) % channel_num + 1
            pos_idx = int(np.ceil(cur_frame / channel_num))
            name = position_list[pos_idx - 1]["name"]
            output_metainfo["log"]["z_list"][pos_idx - 1] = z_last_PFS
            elapsed = time.time() - start_time
            output_metainfo["log"]["time_list"][pos_idx - 1] = elapsed
            fname = f"ch{ch_idx}/{name}_c{ch_idx}.tiff"

            print(
                f"Sample:{input_metainfo['sample_name']} pos:{name} "
                f"captured/total:{pos_idx}/{pos_num} "
                f"z(um){int(z_last_PFS)} time(s):{int(elapsed)}"
            )

            if pos_idx < pos_num:
                # When last channel was done, move stage to next XY position
                # TODO: disable PFS at this time
                if ch_idx == channel_num:
                    next_pos_idx = pos_idx + 1
                    x_um = position_list[next_pos_idx - 1]["x_um"]
                    y_um = position_list[next_pos_idx - 1]["y_um"]
                    mmc.set_xy_position(x_um, y_um)
                    mmc.wait_for_system()
                    z_last_PFS = mmc.get_position("ZDrive")

            # Trigger next exposure until the end
            if cur_frame < frame_num:
                trigger_camera(trigger)
                cur_frame += 1

            # Save file during next exposure
            #tags = json.loads(tagged.tags.toString())
            tags = tagged.tags
            tags_list.append(tags)
            fname_list.append(fname)

            # Convert pixel buffer to numpy image
            img_raw = np.frombuffer(tagged.pix, dtype=np.uint16)
            img = img_raw.reshape((H, W))  # row-major from C++

            save_path = os.path.join(data_dir, fname)
            os.makedirs(os.path.dirname(save_path), exist_ok=True)

            # Non-blocking TIFF write
            #futures.append(executor.submit(tifffile.imwrite, save_path, img, imagej=True, metadata=tags))
            futures.append(executor.submit(tifffile.imwrite, save_path, img))
            # TODO: save with tag information
        else:
            time.sleep(0.01)

    mmc.stop_sequence_acquisition()
    elapsed_total = time.time() - start_time
    print(f"Capture Finished: {elapsed_total / 3600:.2f} hr")

    # Wait for all background writes to complete
    executor.shutdown(wait=True)

    # Record all position and setting information
    output_metainfo["log"]["tags_list"] = tags_list
    output_metainfo["log"]["fname_list"] = fname_list

    # Home microscope settings
    trigger.write("&SQ0000#".encode())  # disable SMARTStreaming on trigger
    try:
        trigger.read_all()  # clear serial port buffer
    except Exception:
        pass
    mmc.set_property("PFS", "FocusMaintenance", "Off")
    mmc.set_xy_position(x_ori, y_ori)
    mmc.set_config("Kinetix-left", "multipass-89000")

    return output_metainfo


if __name__ == "__main__":
    import serial
    from tkinter import *
    from tkinter import filedialog

    #Load metadata
    root = Tk()
    root.withdraw()
    root.json_file =  filedialog.askopenfilename(             
                    title = "Please Select JSON file",
                    filetypes = (("json file","*.json"),
                    ("all files","*.*")))         
    json_file = root.json_file        
    with open(json_file, "r") as f:
        input_metainfo = json.load(f)

    # Connect to Micro-Manager core
    mmc = Core()

    # Connect to trigger serial port (adjust port name as needed)
    trigger = serial.Serial("COM6", 115200, timeout=1)

    output_metainfo = rapid_scan_pvcam(mmc, trigger, input_metainfo)
    data_dir = output_metainfo['data_dir']
    sample_name = output_metainfo['sample_name']
    output_json_file = "%s/%s.json"%(data_dir, sample_name)
    with open(output_json_file, "w") as f:
        json.dump(output_metainfo, f)
