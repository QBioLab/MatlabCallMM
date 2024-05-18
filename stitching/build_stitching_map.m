function [map]=build_stitching_map(view_position_list, view_size, assembly_size)
%% generate mask for each view

view_num=length(view_position_list);
min_assembly_border = floor(min(view_position_list, [], 2)); % smallest almong column
max_assembly_border = ceil(max(view_position_list, [], 2)) + view_size;
view_start_list_in_assembly = int16(view_position_list - min_assembly_border) +1; % matlab count form 1
% fill all view in assembly
assembled_mask=zeros(assembly_size(1),assembly_size(2), view_num, 'uint16');
for view_idx=1:view_num
	view_start_in_assembly = view_start_list_in_assembly(:, view_idx);
    view_indices_1 = view_start_in_assembly(1):view_start_in_assembly(1)+view_size(1);
    view_indices_2 = view_start_in_assembly(2):view_start_in_assembly(2)+view_size(2);
    assembled_mask(view_indices_1, view_indices_2, view_idx)=1;    
end

for idx1 = 1:assembly_size(1)
    for idx2 = 1:assembly_size(2)
        % find the views which have pixel in current assembly coordinate
        views_has_pixel=[];
        for view_idx=1:view_num
            has_pixel = assembled_mask(idx1, idx2, view_idx);
            if has_pixel == 1
                views_has_pixel = [views_has_pixel view_idx];
            end
        end
        pixel_num_along_all_view = length(views_has_pixel);
        % calculate Hamiton distance to each view center
        if pixel_num_along_all_view > 1
            dist_along_all_view = [];
            for view_idx = views_has_pixel
                view_center = view_start_list_in_assembly(:, view_idx) + int16(view_size/2);
                dist = abs(idx1 - view_center(1)) + abs(idx2 - view_center(2));
                dist_along_all_view = [dist_along_all_view dist];
            end
            % search the view with shortest distance
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
                    assembled_mask(idx1, idx2, view_idx) = 0; 
                end
            end
        end
    end
end

map =  zeros(assembly_size(1), assembly_size(2), 'uint16');
for view_idx=1:view_num
    map = map + assembled_mask(:, :, view_idx).*view_idx;
end

end
