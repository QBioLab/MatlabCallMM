function [plate]=stitching_well(metainfo)
addpath ../lib

tiff_options.overwrite = true;
tiff_options.message = true;
%% parse neccessary info from metainfo
plate.sample=metainfo.sample_name;
plate.view_dir = metainfo.data_dir;
plate.folder_out = metainfo.assembly_dir;
plate.affine_matrix = metainfo.camera_affine_matrix; % scaling & rate, no translate
plate.view_position_list = metainfo.position_list;
plate.view_fname_list = string(metainfo.log.fname_list);
plate.view_size = [metainfo.roi(3); metainfo.roi(4)]; % [dimension x, dimension y]

plate.nc=length(metainfo.channel_sequence);
plate.channel_index=metainfo.channel_sequence +1;
plate.channel = [];
for ch_counter=1:plate.nc
    ch_idx = plate.channel_index(ch_counter);
    plate.channel=[plate.channel  string(metainfo.chsetup(ch_idx).name)];
end

%% layout this assembly
view_num = length(plate.view_position_list);
view_position_matrix_in_stage = zeros(2, view_num);
for idx=1:view_num
    view_position_matrix_in_stage(1, idx) = plate.view_position_list(idx).x_um;
    view_position_matrix_in_stage(2, idx) = plate.view_position_list(idx).y_um;
end
view_position_matrix_in_camera = ceil(inv(plate.affine_matrix) * view_position_matrix_in_stage);
min_scan_border = floor(min(view_position_matrix_in_camera, [], 2));
max_scan_border =  ceil(max(view_position_matrix_in_camera, [], 2)); % find maxima in column
assembly_size = end_scan_point - start_scan_point +1 + plate.view_size;

%assembly_map=build_stitching_map(view_position_matrix_in_camera, plate.view_size, assembly_size);

%% assign view image to assembly image
for ch_idx=1:plate.nc
    clear assembly;
    assembly = zeros(assembly_size(1), assembly_size(2), 'uint16');
    for view_idx=1:view_num
        view_position_in_camera = view_position_matrix_in_camera(:, view_idx);
        view_position_in_assembly = view_position_in_camera - start_scan_point +1;
        % add 1 becuase matlab count from 1
        
        view_fname= sprintf("%s/%s", plate.view_dir, ...
            plate.view_fname_list(ch_idx, view_idx));
        raw_img=loadtiff(view_fname);
        
        view_range1_in_assembly = view_position_in_assembly(1) : ...
                  view_position_in_assembly(1) + plate.view_size(1)-1;
        view_range2_in_assembly = view_position_in_assembly(2) : ...
                  view_position_in_assembly(2) + plate.view_size(2)-1;
        % ? generate coordinate from assembly_mask directly for performance?
        %view_mask = assembly_map(view_range_in_assembly(1), view_range_in_assembly(2)) == pos_idx;
        %assembly(view_range_in_assembly(1), view_range_in_assembly(2), ch_idx) = raw_img .* view_mask;
        assembly(view_range1_in_assembly, view_range2_in_assembly) = raw_img;
    end 

    assembly_fname=sprintf('%s/assembly_%s_%s.tif', ...
        plate.folder_out, plate.sample, plate.channel(ch_idx)); 
    saveastiff(assembly, assembly_fname, tiff_options);
end
