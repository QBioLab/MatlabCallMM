function [updated_metainfo]=calibrate_position(...
    input_metainfo, new_cali_plate_info)
%%% apply new calibration data to update capture position
% Because calibration plate and well plate share the same affine matrix between
% stage' change, orignal position will be updated by affine matrix which is obtained
% from orignal & new calibration position.

addpath '../lib';

updated_metainfo = input_metainfo;
%% collect position into matrix
ori_position_list = input_metainfo.position_list;
ori_ref_position_list = input_metainfo.cali_plate.ref_point_list;
new_ref_position_list = new_cali_plate_info.ref_point_list;

position_num=length(ori_position_list);
ori_position_matrix = zeros(3, position_num);
for idx=1:position_num
    ori_position_matrix(1, idx) = ori_position_list(idx).x_um;
    ori_position_matrix(2, idx) = ori_position_list(idx).y_um;
    ori_position_matrix(3, idx) = 1;
end

% well xy center array if it exist
has_well_center_info = false;
well_num = 0;
ori_well_center_matrix = '';
if isfield(input_metainfo, 'well_plate')
    if isfield(input_metainfo.well_plate, 'well_center_xy_array')
        has_well_center_info = true;
        well_center_array = input_metainfo.well_plate.well_center_xy_array;
        well_num = length(well_center_array);
        ori_well_center_matrix = zeros(3, well_num); 
        for idx = 1:well_num
            ori_well_center_matrix(1, idx)= well_center_array(idx, 1);
            ori_well_center_matrix(2, idx)= well_center_array(idx, 2);
            ori_well_center_matrix(3, idx)= 1;
        end
    end
end

% only use the third one to find affine matrix
ref_position_num = 3;
ori_ref_position_matrix = zeros(3, ref_position_num);
new_ref_position_matrix = zeros(3, ref_position_num);
for idx=1:ref_position_num
    ori_ref_position_matrix(1, idx) = ori_ref_position_list(idx).x_um;
    ori_ref_position_matrix(2, idx) = ori_ref_position_list(idx).y_um;
    ori_ref_position_matrix(3, idx) = 1;
    new_ref_position_matrix(1, idx) = new_ref_position_list(idx).x_um;
    new_ref_position_matrix(2, idx) = new_ref_position_list(idx).y_um;
    new_ref_position_matrix(3, idx) = 1;
end

%% transform origal stage positions to new stage representation.
affine_matrix = new_ref_position_matrix * inv(ori_ref_position_matrix);
updated_position_matrix = affine_matrix * ori_position_matrix;
updated_position_list = ori_position_list;
for idx=1:position_num
    updated_position_list(idx).x_um = updated_position_matrix(1, idx);
    updated_position_list(idx).y_um = updated_position_matrix(2, idx);
end
% check stage limit or not?
if has_well_center_info
    updated_well_center_matrix = affine_matrix * ori_well_center_matrix;
    updated_metainfo.well_plate.well_center_xy_array = ...
        updated_well_center_matrix(1:2, :)';
      updated_view_list =  affine_matrix(1:2, 1:2) * input_metainfo.well_plate.view_list';
      updated_metainfo.well_plate.view_list = updated_view_list';
end

%% store updated capture position list & calibration position list
updated_metainfo.cali_plate.ref_point_list = new_ref_position_list;
updated_metainfo.position_list = updated_position_list;
