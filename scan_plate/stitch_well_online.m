function []=stitch_well_online(frame, frame_info, metainfo)
addpath ../lib

Shrink=0.5;
tiff_options.overwrite = true;
tiff_options.message = false;

% load shape factor for each image to facilitate merging neighboring images
% load weight factor for the assembled images with Shrink ratio
well.folder_out = metainfo.well_plate.assembly_folder;
well_assembly_map = metainfo.well_plate.well_assembly_map;

well_idx = frame_info.well;
view_id = frame_info.view_id;
channel = frame_info.channel;
well_fname = sprintf('%s\\%s\\well%03d_%s.tif', well.folder_out, channel, well_idx, channel); 
try % load existed assemmbly file
    well_assembled = loadtiff(well_fname);
catch % if no existed assembly file, new it
    well_assembled = zeros(well_pixel_sizes(2), well_pixel_sizes(1), 'uint16');
end
% revise the positions of each optical field relative to well center, 
% to avoid rotating or resize image diretctly, the positions were rotated and scaled instead
%jy=(1:ny1)-ny1/2+view(2)-min_well_image_pixel(:,2);
%jx=(1:nx1)-nx1/2+view(1)-min_well_image_pixel(:,1);
jy = metainfo.well_plate.assembly.jy
jx = metainfo.well_plate.assembly.jx
well_assembly_unmask = zeros(well_pixel_sizes(2), well_pixel_sizes(1), 'uint16');
shrinked_frame = imresize(frame, Shrink);
%subtracted_background = rolling_ball(shrinked_img,10,30,0.5);
well_assembly_unmask(jy, jx) = shrinked_frame;
view_mask = well_assembly_map(:, :) == view_id;
well_assembled = well_assembled + well_assembly_unmask.*view_mask;

saveastiff(well_assembled, well_fname, tiff_options);
end
