addpath '../lib';
datahub = '//data.qblab.science/datahub/';
metainfo_ori = read_json([datahub '/rawdata/test-sample/test-sample.json']);
metainfo = metainfo_ori;
% append information
%metainfo.camera_affine_matrix = [-0.6441953385558242,-4.5368433916700507e-4;...
%                5.067213479323705e-5,0.6435726559809668];
%fname_length = length(metainfo_ori.log.fname_list);
%updated_fname_list = string(reshape(metainfo_ori.log.fname_list, 1, fname_length/1));
%metainfo.log.fname_list = updated_fname_list;

%stitching_info = stitching_by_view(metainfo);
stitching_info = stitching_by_well(metainfo);
