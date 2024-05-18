clear all;

addpath ../lib

orignal_plate_json = 'Y:/analysis_plate_clones/A384/info_well_plate_A384_20240317.json';
updated_cali_json = 'Y:/analysis_plate_clones/A384/info_cali_points_on_A384_20240517.json';
orignal_plate_info = read_json(orignal_plate_json);
update_cali_info = read_json(updated_cali_json);

updated_metainfo = update_well_plate_center(orignal_plate_info, update_cali_info);
updated_metainfo.createdfrom = {orignal_plate_json updated_cali_json};
save_json('Y:/analysis_plate_clones/A384/info_well_plate_A384_20240517.json', updated_metainfo);

