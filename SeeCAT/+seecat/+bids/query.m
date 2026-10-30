function F = query(L, varargin)
% QUERY  Select files of a BIDS layout by entity, suffix and extension.
%   F = seecat.bids.query(L, 'suffix', 'bold', 'task', 'rest')
%   F = seecat.bids.query(L, 'sub', {'01', '02'}, 'suffix', 'T1w', 'ext', {'.nii', '.nii.gz'})
%
% Filters are name-value pairs. Values are a label or a cell array of
% labels; an empty value ('' or {}) matches anything. Names are 'suffix', 'ext',
% 'datatype' or any entity key ('sub', 'ses', 'task', 'acq', 'run', ...).
% A file without an entity that is filtered on does not match.
% F is a subset of L.files, in layout order.

if mod(numel(varargin), 2)
    error('SeeCAT:bids', 'Filters must be name-value pairs.');
end
keep = true(numel(L.files), 1);
for i = 1:2:numel(varargin)
    key = varargin{i};
    want = cellstr(varargin{i+1});
    if all(cellfun(@isempty, want))
        continue
    end
    switch key
        case {'suffix', 'ext', 'datatype'}
            have = {L.files.(key)}';
        otherwise
            have = arrayfun(@(f) entity(f, key), L.files, 'UniformOutput', false);
    end
    keep = keep & ismember(have, want);
end
F = L.files(keep);
end

function v = entity(f, key)
if isfield(f.ent, key)
    v = f.ent.(key);
else
    v = char(0);          % no file label can contain char(0)
end
end
