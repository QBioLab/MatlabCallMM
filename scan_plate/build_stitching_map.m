function [assembled_map]=build_stitching_mask(view_list, view_pixel_sizes, well_pixel_sizes)

view_num=length(view_list);
min_well_image_pixel=floor(min(view_list))-view_pixel_sizes/2;
max_well_image_pixel=ceil(max(view_list))+view_pixel_sizes/2;
assembled_mask=zeros(well_pixel_sizes(2),well_pixel_sizes(1), view_num ,'uint16');
for view_idx=1:view_num
	view = view_list(view_idx, :);
    num_y = view_pixel_sizes(2);
    num_x = view_pixel_sizes(1);
    jy=(1:num_y)-num_y/2+view(2)-min_well_image_pixel(:,2);
    jx=(1:num_x)-num_x/2+view(1)-min_well_image_pixel(:,1);
    assembled_mask(jy, jx, view_idx)=1;
end

for pixel_y_idx=1:well_pixel_sizes(2)
    for pixel_x_idx=1:well_pixel_sizes(1)
        views_has_pixel=[];
        for view_idx=1:view_num
            has_pixel = assembled_mask(pixel_y_idx, pixel_x_idx, view_idx);
            if has_pixel == 1
                views_has_pixel = [views_has_pixel view_idx];
            end
        end
        pixel_num_along_all_view = length(views_has_pixel);
        % calculate Hamiton distance to each view center
        if pixel_num_along_all_view > 1
            dist_along_all_view = [];
            for view_idx = views_has_pixel
                view_center = view_list(view_idx, :)-min_well_image_pixel;
                dist = abs(pixel_x_idx - view_center(1)) + abs(pixel_y_idx-view_center(2));
                dist_along_all_view = [dist_along_all_view dist];
            end
            % find the view with shortest distance
            shortest_dist_view_idx=views_has_pixel(1);
            shortest_dist=dist_along_all_view(1);
            for count = 1:pixel_num_along_all_view
                dist = dist_along_all_view(count);
                if  dist < shortest_dist
                    view_idx = views_has_pixel(count);
                    shortest_dist = dist;
                    shortest_dist_view_idx = view_idx;
                end
            end
            % set 0 for views without shortest dist
            for view_idx=views_has_pixel
                if view_idx~=shortest_dist_view_idx
                    assembled_mask(pixel_y_idx, pixel_x_idx, view_idx) = 0; 
                end
            end
        end
    end
end

map =  zeros(well_pixel_sizes(2), well_pixel_sizes(1), 'uint16');
for view_idx=1:plate.perw
    map = view_map + assembled_mask(:, :, view_idx).*view_idx;
end

end
