% Initlize microscope
if ~exist('mmc', 'var')
    trigger_serial_port = 'COM6';
    [mmc, trigger]=initialize_mm_and_trigger(trigger_serial_port);
    return;
end 

% load metainfo
[file_name, file_dir]= uigetfile('.json');
metainfo_file = [file_dir file_name];
metainfo = read_json(metainfo_file);
metainfo.createdfrom = metainfo_file;

sample_name=metainfo.sample_name;
data_dir = metainfo.data_dir;

% start scaning
output_metainfo = rapid_scan_wellplate_dev(mmc, trigger, metainfo);

% save metainfo
output_json_file = sprintf("%s/%s.json", data_dir, sample_name);
save_json( output_json_file, output_metainfo);
