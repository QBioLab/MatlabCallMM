addpath ../lib

orignal_json = 'Y:/analysis_plate_clones/A384/A384-10x-all_well-template-Ti2-20240514.json';
updated_cali_plate_json = 'Y:/analysis_plate_clones/calibration_xy_positions_plates/cali_plate_prior_livecell_20240514.json';
orignal_metainfo = read_json(orignal_json);
update_cali_plate_info = read_json(updated_cali_plate_json);
updated_metainfo = calibrate_position(orignal_metainfo, update_cali_plate_info);
updated_metainfo.createdfrom = orignal_json;
save_json('livecell_prior_updated.json', updated_metainfo);

