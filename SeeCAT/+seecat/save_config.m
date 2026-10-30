function save_config(cfg, file)
% SAVE_CONFIG  Write a pipeline configuration as JSON.
%   seecat.save_config(cfg, 'study_prep.json')
%
% The file loads back with seecat.config('study_prep.json').

try
    txt = jsonencode(cfg, 'PrettyPrint', true);   % R2021a+
catch
    txt = jsonencode(cfg);
end
d = fileparts(file);
if ~isempty(d) && ~exist(d, 'dir')
    mkdir(d);
end
fid = fopen(file, 'w', 'n', 'UTF-8');
if fid < 0
    error('SeeCAT:config', 'Cannot write %s', file);
end
c = onCleanup(@() fclose(fid));
fprintf(fid, '%s', txt);
end
