function save_config(cfg, file)
% SAVE_CONFIG  Write a pipeline configuration as JSON.
%   seecat.save_config(cfg, 'study_prep.json')
%
% The file loads back with seecat.config('study_prep.json').

seecat.util.write_json(file, cfg);
end
