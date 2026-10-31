function cfg = config(source)
% CONFIG  Configuration of a SeeCAT pipeline.
%   cfg = seecat.config('prep')          % every option at its default
%   cfg = seecat.config('study.json')    % load; missing fields take defaults
%   cfg = seecat.config(cfg)             % fill missing fields of a struct
%
% Edit the returned struct and pass it to seecat.run. seecat.check_config
% reports invalid values; seecat.save_config writes the struct as JSON.

if isstring(source)
    source = char(source);
end
if ischar(source) && ~endsWith(source, '.json', 'IgnoreCase', true)
    cfg = seecat.util.pipeline_defaults(source);
    return
end
if ischar(source)
    if ~exist(source, 'file')
        error('SeeCAT:config', 'Config file not found: %s', source);
    end
    try
        source = jsondecode(fileread(source));
    catch err
        error('SeeCAT:config', 'Cannot parse %s: %s', source, err.message);
    end
end
if ~isstruct(source) || ~isscalar(source) || ~isfield(source, 'pipeline')
    error('SeeCAT:config', 'A config needs a "pipeline" field, e.g. "prep".');
end
cfg = merge(seecat.util.pipeline_defaults(source.pipeline), source);
end

function out = merge(def, in)
% Values from IN over DEF. Unknown fields are kept so that check_config
% can report them.
out = def;
for f = fieldnames(in)'
    k = f{1};
    val = in.(k);
    if isfield(def, k)
        d = def.(k);
        if isstruct(d) && ~isscalar(d)                % a list of records (e.g. seeds)
            val = records(d, val);
        elseif isstruct(d) && isstruct(val) && isscalar(val)
            val = merge(d, val);
        elseif iscell(d) && isnumeric(val) && isempty(val)
            val = {};                                  % JSON [] for an empty list
        elseif iscell(d) && ischar(val)
            val = {val};
        elseif iscell(d) && iscell(val)
            val = val(:)';
        elseif islogical(d) && isnumeric(val) && isscalar(val) && any(val == [0 1])
            val = logical(val);
        elseif isnumeric(d) && isnumeric(val) && isvector(val) && isrow(d)
            val = val(:)';                             % JSON arrays decode as columns
        end
    end
    out.(k) = val;
end
end

function out = records(def, val)
% A list of records: JSON gives a struct array, or a cell array when the
% records have different fields. Missing fields are filled with [].
if isempty(val)
    out = def;
    return
end
if isstruct(val)
    val = num2cell(val);
end
if ~iscell(val) || ~all(cellfun(@isstruct, val))
    out = val;                                   % left for check_config to report
    return
end
names = fieldnames(def)';
for i = 1:numel(val)
    names = union(names, fieldnames(val{i})', 'stable');
end
out = repmat(cell2struct(cell(numel(names), 1), names, 1), 1, numel(val));
for i = 1:numel(val)
    for f = fieldnames(val{i})'
        v = val{i}.(f{1});
        if isnumeric(v) && iscolumn(v)
            v = v';
        end
        out(i).(f{1}) = v;
    end
end
end
