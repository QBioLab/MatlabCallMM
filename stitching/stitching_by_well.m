function [plate]= stitching_by_well(metainfo)
% if all the well share the same layout
% Used parameters from metainfo:
%   metainfo.smaple_name
%   metainfo.roi
%   metainfo.data_dir
%   metainfo.active_channel_sequence
%   metainfo.well_plate.view_list
%   metainfo.well_plate.picked_well_list
%   metainfo.camera_affine_matrix
%   metainfo.chsetup


tiff_options.overwrite = true;
tiff_options.message = true;

%% parse neccessary info from metainfo
plate.sample=metainfo.sample_name;
plate.view_dir = metainfo.data_dir;
plate.assembly_dir = metainfo.assembly_dir;
plate.view_position_list = metainfo.well_plate.view_list;
%plate.view_fname_list = string(metainfo.log.fname_list);
plate.view_size = [metainfo.roi(3); metainfo.roi(4)]; % ?[dimension x, dimension y]
plate.channel_index=metainfo.active_channel_sequence;
plate.well_list = int32(metainfo.well_plate.picked_well_list);
well_num = length(plate.well_list);
try 
    affine_string = metainfo.camera_affine_matrix;
    camera_affine_matrix = reshape(sscanf(affine_string, '%f;%f;%f;%f;%f;%f'),3,2);
    plate.affine_matrix = camera_affine_matrix(1:2, 1:2); % scaling & rate, no translate
    % BUG: translate may required to fit roi setting
catch 
    plate.affine_matrix = [-0.6459012629133096, -0.00140452112843774;...
        -0.0014006888550221026, 0.6456566462658601;];
end

channel_num = length(plate.channel_index);
plate.channel = [];
for ch_count = 1:channel_num
    ch_idx = plate.channel_index(ch_count);
    plate.channel = [plate.channel  string(metainfo.chsetup(ch_idx).name)];
end

%% layout single well assembly
view_num = length(plate.view_position_list);
%view_position_matrix_in_stage = zeros(2, view_num);
view_position_matrix_in_stage = plate.view_position_list';
view_position_matrix_in_camera = ceil(inv(plate.affine_matrix) * view_position_matrix_in_stage);
min_scan_border = floor(min(view_position_matrix_in_camera, [], 2));
max_scan_border =  ceil(max(view_position_matrix_in_camera, [], 2)); % find maxima in column
assembly_size = max_scan_border - min_scan_border +1 + plate.view_size;
assembly_map=build_stitching_map(view_position_matrix_in_camera, plate.view_size, assembly_size);

%% assign view image to assembly image
parfor well_count = 1:well_num
    well_idx = plate.well_list(well_count);
    for ch_idx = 1:channel_num
        assembly = zeros(assembly_size(1), assembly_size(2), 'uint16');
        for view_idx=1:view_num
            view_position_in_camera = view_position_matrix_in_camera(:, view_idx);
            view_position_in_assembly = view_position_in_camera - min_scan_border +1;
            % plus 1 becuase matlab count from 1
            
            % New feature: wait image here for online version
            view_fname= sprintf("%s/ch%d/well%d_%d_c%d.tiff", ...
                plate.view_dir, ch_idx, well_idx, view_idx, ch_idx);
            raw_img=loadtiff(view_fname);
            raw_img = raw_img';
            % transpose to column-major for matlab;
            % New feature: single view processing here
        
            view_range1_in_assembly = view_position_in_assembly(1) : ...
                  view_position_in_assembly(1) + plate.view_size(1)-1;
            view_range2_in_assembly = view_position_in_assembly(2) : ...
                  view_position_in_assembly(2) + plate.view_size(2)-1;
            view_mask = uint16(assembly_map(view_range1_in_assembly, view_range2_in_assembly) == view_idx);
            assembly(view_range1_in_assembly, view_range2_in_assembly) = raw_img .* view_mask +...
                assembly(view_range1_in_assembly, view_range2_in_assembly);
        end
        assembly_fname=sprintf('%s/ch%d/well_%d.tif', plate.assembly_dir, ch_idx, well_idx); 
        % New feature: shrink here
        saveastiff(assembly, assembly_fname, tiff_options);
    end
end
