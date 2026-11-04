function save_config(cfg, file)
% SAVE_CONFIG  Write a pipeline configuration as JSON.
%   seecat.save_config(cfg, 'study_prep.json')
%
% The file loads back with seecat.config('study_prep.json'). JSON has no
% Inf or NaN, so numbers holding them are written as text, e.g.
% "distance_edges": "[0 75 Inf]"; seecat.config turns them back into numbers.

seecat.util.write_json(file, encode(cfg));
end

function v = encode(v)
if isstruct(v)
    for i = 1:numel(v)
        for f = fieldnames(v)'
            v(i).(f{1}) = encode(v(i).(f{1}));
        end
    end
elseif iscell(v)
    v = cellfun(@encode, v, 'UniformOutput', false);
elseif isnumeric(v) && ~all(isfinite(v(:)))
    v = mat2str(v);
end
end
