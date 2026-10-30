function write_json(file, value)
% WRITE_JSON  Write a MATLAB value as JSON (UTF-8), creating the folder.
%   seecat.util.write_json('out.json', s)

try
    txt = jsonencode(value, 'PrettyPrint', true);   % R2021a+
catch
    txt = jsonencode(value);
end
d = fileparts(file);
if ~isempty(d) && ~exist(d, 'dir')
    mkdir(d);
end
fid = fopen(file, 'w', 'n', 'UTF-8');
if fid < 0
    error('SeeCAT:io', 'Cannot write %s', file);
end
c = onCleanup(@() fclose(fid));
fprintf(fid, '%s', txt);
end
