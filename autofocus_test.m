%https://micro-manager.org/wiki/Autofocus_manual
%-applying 3x3 median filter to the image to remove noise
%-convolute image with a filter [-2 -1 0; -1 0 1; 0 1 2 ]
%-sum the square of each entry in the convoluted image.

pos_num = 40;
pos_sharp = zeros(20, 40, 'double');
data_dirs = ["/home/hf/ssd-raid/td/20201105/",...
    "/datahub/rawdata/tandeng/iPS-organoids/DOE/20201103-/20201104/"];
for data_dir = data_dirs
    for pos=1:40
        disp(pos)
        name = sprintf('%s/well%dxy%dc1.tiff', data_dir, ceil(pos/4), pos);
        raw_img = loadtiff(name);
        pos_sharp(:, pos) = cal_sharpness(raw_img);
    end
    out_file = sprintf('%ssharpness_crop.mat', data_dir);
    save(out_file, 'pos_sharp');
end

% calculate sharpness of each slice
function sharpness = cal_sharpness(img)
    kernel = [-2 -1 0; -1 0 1; 0 1 2 ];
    z_num = size(img, 3);
    sharpness = zeros(z_num, 1);
    for z=1:z_num
        zslice = medfilt2(img(513:1536, 513:1536, z), [3 3]);
        zsilce = conv2(double(zslice), kernel, 'same');
        sharpness(z) = sum(zslice.*zslice, 'all');
    end
end

% find first maximum
function firstmax = find1max(src)
    firstmax = src(1);
    if length(src) > 1
        z = 2;
    else
        return 
    end
    while(src(z) > firstmax)
        firstmax = src(z);
        z = z+1;
    end
end
