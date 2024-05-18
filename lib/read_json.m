function [json_dict] = read_json(fname)
%UNTITLED
fname(strfind(fname,'\'))='/';% avoid json error
try
    disp(['loading ' fname]);
    
    json_txt=fileread(fname);
    json_dict = jsondecode(json_txt);
catch
    error("open this json file fail");
end
end
