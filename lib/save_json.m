function [] = save_json(fname, json_struct)
% save matlab struct to json file
json_file = fopen(fname, 'w');
isOctave = exist('OCTAVE_VERSION', 'builtin') ~= 0;
json_txt='';
if isOctave
    json_txt = jsonencode(json_struct, 'PrettyPrint', true);
    fprintf(json_file, json_txt);
    fclose(json_file);
else % matlab
    %addpath jsonlab
    %json_txt = jsonencode(json_struct, 'PrettyPrint', true);
    json_txt = jsonencode(json_struct);
    json_txt = prettyjson(json_txt);
    fprintf(json_file, json_txt);
    fclose(json_file);
end
end
