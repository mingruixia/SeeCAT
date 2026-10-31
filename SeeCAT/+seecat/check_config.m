function check_config(cfg)
% CHECK_CONFIG  Error listing every problem in a pipeline configuration.
%   seecat.check_config(cfg)
%
% Reports unknown fields (usually typos), missing fields and invalid values
% together, so that a config can be fixed in one pass. Raises SeeCAT:config.

if ~isstruct(cfg) || ~isscalar(cfg) || ~isfield(cfg, 'pipeline')
    error('SeeCAT:config', 'A config needs a "pipeline" field, e.g. "prep".');
end
[def, spec] = seecat.util.pipeline_defaults(cfg.pipeline);

msgs = unknownFields(cfg, def, '');
for i = 1:size(spec, 1)
    path = spec{i, 1};
    [val, found] = getPath(cfg, path);
    if ~found
        msgs{end+1} = sprintf('%s is missing.', path); %#ok<AGROW>
        continue
    end
    try
        ok = spec{i, 2}(val);
    catch
        ok = false;
    end
    if ~isequal(ok, true)
        msgs{end+1} = sprintf('%s must be %s.', path, spec{i, 3}); %#ok<AGROW>
    end
end

if ~isempty(msgs)
    error('SeeCAT:config', 'Invalid %s configuration:\n  - %s', cfg.pipeline, strjoin(msgs, '\n  - '));
end
end

function msgs = unknownFields(s, def, prefix)
msgs = {};
for f = fieldnames(s)'
    k = f{1};
    path = [prefix k];
    if ~isfield(def, k)
        msgs{end+1} = sprintf('%s is not a known option.', path); %#ok<AGROW>
    elseif isscalar(def) && isscalar(s) && isstruct(def.(k)) && isstruct(s.(k)) && ...
            ~isempty(fieldnames(def.(k)))      % a default with no fields is free-form (e.g. stat.maps)
        msgs = [msgs, unknownFields(s.(k), def.(k), [path '.'])]; %#ok<AGROW>
    end
end
end

function [val, found] = getPath(s, path)
val = s;
found = true;
for k = strsplit(path, '.')
    if ~isstruct(val) || ~isfield(val, k{1})
        val = [];
        found = false;
        return
    end
    val = val.(k{1});
end
end
