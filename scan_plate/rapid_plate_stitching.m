clear all
%metainfo_file = 'E:\XJF\20240422\plate1-sto-gfp-conditioned-medium\plate1-sto-gfp-conditioned-medium.json';
metainfo_file = 'E:\XJF\20240420\plate1-sto-gfp-conditioned-medium\plate1-sto-gfp-conditioned-medium.json';
metainfo_json=fileread(metainfo_file);
metainfo = jsondecode(metainfo_json);

% camera : photometrics kinitex (3200x3200 6.5um)
nx=metainfo.roi(3); 
ny=metainfo.roi(4);
Shrink=0.5;
ny1=nx*Shrink;
nx1=ny1;
M=10.0;
pixel_size=6.5/M/Shrink; %% pixel size in assembled image: 1um

tiff_options.overwrite = true;
tiff_options.message = false;
load('E:\analysis_plate_clones\backgrounds\IVS96_center_10XAPO_Kinitex_2720.mat','factors','dark_mean');
shrinked_flat_field=imresize(factors,Shrink);
shrinked_dark_field=imresize(dark_mean,Shrink);

% load shape factor for each image to facilitate merging neighboring images
% load weight factor for the assembled images with Shrink ratio
plate.exp=metainfo.sample_name;
plate.folder_input=metainfo.data_dir;
plate.folder_out=['E:\analysis_plate_clones\assembled_plates\XJF\20240420\' plate.exp '-test'];
plate.nc=length(metainfo.channel_sequence);
plate.channel_index=metainfo.channel_sequence +1;
plate.channel = [];
for ch_counter=1:plate.nc
    ch_idx = plate.channel_index(ch_counter);
    plate.channel=[plate.channel  string(metainfo.chsetup(ch_idx).name)];
end
plate.well_list = int32(metainfo.well_plate.well_list); 
plate.nwell=length(plate.well_list);
plate.perw=metainfo.well_plate.npw;
plate.rotation=0.00;%4.25; % calibrated using A384-20240317 A1 well
plate.scale=0.9895;% calibrated using A384-20240317 A1 well

% revise the positions of each optical field relative to well center, 
% to avoid rotating or resize image diretctly, the positions were rotated and scaled instead
transformation_matrix = [cosd(plate.rotation) -sind(plate.rotation); ...
                        sind(plate.rotation) cosd(plate.rotation)]/plate.scale;

% calculate the size of the entire well assembly
view_list=metainfo.well_plate.view([2 3 4 1], :);
transformed_view_center=ceil(transformation_matrix* view_list'/pixel_size)';
min_well_image_pixel=floor(min(transformed_view_center))-nx1/2;
max_well_image_pixel=ceil(max(transformed_view_center))+(nx1/2);
well_pixel_sizes=max_well_image_pixel-min_well_image_pixel;

for well_count=1:plate.nwell
    well_idx=plate.well_list(well_count);
    well_assembled=zeros(well_pixel_sizes(2),well_pixel_sizes(1),plate.nc,'uint16');
    for pos_i_perw=1:plate.perw
        pos_id = (well_count-1)*plate.perw + pos_i_perw;
        view = transformed_view_center(pos_i_perw,:);
        jy=(1:ny1)-ny1/2+view(2)-min_well_image_pixel(:,2);
        jx=(1:nx1)-nx1/2+view(1)-min_well_image_pixel(:,1);
        for i_ch=1:plate.nc
            tiff_name=sprintf('%s\\ch%d\\well%d_%d_pos%dc%d.tiff', ...
		    plate.folder_input,i_ch,well_idx, pos_i_perw, pos_id, i_ch);                
            raw_img=loadtiff(tiff_name);
            shrinked_img=imresize(raw_img,Shrink);
            %flat_field=factors_shrink(:,:,plate.channel_index(i_ch)-1);
            %flatted_img=(double(shrinked_img)-dark_mean_shrink).*flat_field;
            %tempy = rolling_ball(temp1,10,30,0.5);
            %flatted_img=uint16(flatted_img);
            well_assembled(jy,jx,i_ch)=shrinked_img;
        end
    end 
    for i_ch=1:plate.nc
         file_per_well=sprintf('%s\\%s\\well%03d_%s.tif',...
                  plate.folder_out, plate.channel(i_ch), well_idx, plate.channel(i_ch)); 
       saveastiff(well_assembled(:,:,i_ch),file_per_well,tiff_options);
    end
    %clear well_assembled file_per_well
end
