function [updated_plate]=update_well_plate_center(...
    input_plate, new_cali_info)
%% apply new calibration data to update capture position

addpath '../lib';

%% collect position into matrix
ori_center_list = input_plate.well_list;
ori_ref_point_list = input_plate.cali_info.ref_point_list;
new_ref_point_list = new_cali_info.ref_point_list;
updated_plate = input_plate;


position_num=length(ori_center_list);
ori_center_matrix = zeros(3, position_num);
for idx=1:position_num
    ori_center_matrix(1, idx) = ori_center_list(idx).center_x_um;
    ori_center_matrix(2, idx) = ori_center_list(idx).center_y_um;
    ori_center_matrix(3, idx) = 1;
end

% only use the third one to find affine matrix
ref_point_num = 3;
ori_ref_point_matrix = zeros(3, ref_point_num);
new_ref_point_matrix = zeros(3, ref_point_num);
for idx=1:ref_point_num
    ori_ref_point_matrix(1, idx) = ori_ref_point_list(idx).x_um;
    ori_ref_point_matrix(2, idx) = ori_ref_point_list(idx).y_um;
    ori_ref_point_matrix(3, idx) = 1;
    new_ref_point_matrix(1, idx) = new_ref_point_list(idx).x_um;
    new_ref_point_matrix(2, idx) = new_ref_point_list(idx).y_um;
    new_ref_point_matrix(3, idx) = 1;
end

%% transform origal stage positions to new stage representation.
affine_matrix = new_ref_point_matrix * inv(ori_ref_point_matrix);
updated_center_matrix = affine_matrix * ori_center_matrix;

updated_plate.cali_info = new_cali_info;
for idx=1:position_num
    updated_plate.well_list(idx).center_x_um = updated_center_matrix(1, idx);
    updated_plate.well_list(idx).center_y_um = updated_center_matrix(2, idx);
end
