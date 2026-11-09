function [f, n] = group_mask(units, cfg)
% GROUP_MASK  The voxels inside the brain mask of every run, as one mask.
%   [f, n] = seecat.conn.group_mask(units, cfg)
%
% UNITS are the planned runs (seecat.bids.derivative_units: their mask
% fields), after the subject, task and QC selection. The intersection of
% their brain masks, on the grid of the first one, is written to
%   <output_dir>/group/masks/space-<space>[_res-<res>]_desc-group<id>_mask.nii.gz
% with a JSON sidecar listing the runs. <id> is 8 characters of a hash of
% the list of masks, so another selection gets a file of its own and does
% not change this one. The file is written again when its voxels or its
% grid (dimensions and affine, to 1e-4 mm) changed, so units that use it
% are redone only then; it is written to a temporary file first and then
% moved into place. N is its number of voxels; an empty intersection is an
% error.

if isempty(units)
    error('SeeCAT:conn', 'No runs to make a group mask from.');
end
masks = sort({units.mask});
[~, V0] = seecat.io.read_nii(masks{1});
V0 = V0(1);
g = true(V0.dim);
for i = 1:numel(masks)
    m = seecat.io.read_nii(masks{i}, 'Ref', V0, 'Interp', 0) > 0;
    g = g & m;
end
n = nnz(g);
if n == 0
    error('SeeCAT:conn', ['The brain masks of the %d runs have no voxel in common; check the ' ...
        'coverage of the runs (QC report) or leave Group mask off.'], numel(masks));
end
rel = cellfun(@(m) relTo(m, cfg.input_dir), masks, 'UniformOutput', false);
id = seecat.util.hash(strjoin(rel, '|'));
name = ['space-' units(1).space];
r = regexp(masks{1}, '_res-([a-zA-Z0-9]+)_', 'tokens', 'once');
if ~isempty(r)
    name = [name '_res-' r{1}];
end
d = fullfile(cfg.output_dir, 'group', 'masks');
f = fullfile(d, sprintf('%s_desc-group%s_mask.nii.gz', name, id(1:8)));
if exist(f, 'file') == 2
    [old, Vo] = seecat.io.read_nii(f);
    Vo = Vo(1);
    if isequal(Vo.dim(1:3), V0.dim(1:3)) && max(abs(Vo.mat(:) - V0.mat(:))) < 1e-4 && ...
            isequal(old > 0, g)
        return
    end
end
if ~exist(d, 'dir')
    mkdir(d);
end
h = seecat.util.hash(tempname);
tmp = fullfile(d, sprintf('tmp%s_%s', h(1:8), name));
c = onCleanup(@() deleteIf({[tmp '_mask.nii.gz'], [tmp '.json']}));
seecat.io.write_nii(uint8(g), V0, [tmp '_mask.nii.gz'], 'DataType', 'uint8');
seecat.util.write_json([tmp '.json'], struct( ...
    'Description', 'Voxels inside the brain mask of every run listed in Sources', ...
    'Voxels', n, 'NumberOfRuns', numel(masks), 'Sources', {strcat('bids:seecat:', rel(:))}, ...
    'Software', ['SeeCAT ' seecat.version()]));
movefile([tmp '.json'], strrep(f, '.nii.gz', '.json'), 'f');
movefile([tmp '_mask.nii.gz'], f, 'f');
end

function deleteIf(files)
for i = 1:numel(files)
    if exist(files{i}, 'file') == 2
        delete(files{i});
    end
end
end

function r = relTo(f, root)
r = strrep(f, '\', '/');
root = strrep(char(root), '\', '/');
if startsWith(lower(r), lower([root '/']))
    r = r(numel(root) + 2:end);
end
end
