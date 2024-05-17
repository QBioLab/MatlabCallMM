clear all;

addpath ../lib

orignal_json = 'Y:/analysis_plate_clones/A384/A384-10x-all_well-template-Ti2-20240516.json';
updated_cali_plate_json = 'Y:/analysis_plate_clones/A384/cali_points_on_A384_20240517.json';
orignal_metainfo = read_json(orignal_json);
update_cali_plate_info = read_json(updated_cali_plate_json);
updated_metainfo = calibrate_position(orignal_metainfo, update_cali_plate_info);
updated_metainfo.createdfrom = orignal_json;
save_json('livecell_updated_20240517.json', updated_metainfo);

