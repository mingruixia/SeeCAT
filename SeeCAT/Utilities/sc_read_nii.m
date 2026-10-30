function [Y, V] = sc_read_nii(img, varargin)
% SC_READ_NII  Read a NIfTI image, a 4D series or a list of images.
%   [Y, V] = sc_read_nii(f)
%   [Y, V] = sc_read_nii(f, 'Volumes', idx)
%   [Y, V] = sc_read_nii(f, 'Ref', refHdr, 'Interp', 1)
%   [Y, V] = sc_read_nii(f, 'Class', 'single')
%
% F is a file name (.nii or .nii.gz) or a cell array of file names; 3D and 4D
% files can be mixed, and their volumes are stacked in order.
%
% Y is X x Y x Z x T in stored voxel order. Nothing is flipped: V(k).mat maps
% the voxels of volume k to world space.
% V is the spm_vol header array, one element per returned volume.
%
% Options:
%   'Volumes'  indices into the stacked volume list (default: all).
%   'Ref'      spm_vol header; every volume is resampled to its grid and V
%              becomes the reference header repeated per volume.
%   'Interp'   SPM interpolation order used with 'Ref' (default 0, nearest).
%   'Class'    'double' (default) or 'single'.
%
% Without 'Ref', all volumes must share one voxel grid. Volumes of a single
% 4D file are read as stored even if realignment gave them different
% affines; separate files with different affines are an error.
% For .nii.gz input the file is unpacked to a temporary folder that is
% deleted on return, so V(k).fname names the .gz file only for reference.

p = inputParser;
p.addParameter('Volumes', [], @(x) isnumeric(x) && all(x(:) >= 1));
p.addParameter('Ref', [], @(x) isempty(x) || isstruct(x));
p.addParameter('Interp', 0, @isscalar);
p.addParameter('Class', 'double', @(x) any(strcmp(x, {'double', 'single'})));
p.parse(varargin{:});
opt = p.Results;

files = cellstr(img);
if isempty(files)
    error('SeeCAT:read', 'No image given.');
end

% Unpack .nii.gz to a private temporary folder
tmpDir = '';
local = files;
for i = 1:numel(files)
    if ~exist(files{i}, 'file')
        error('SeeCAT:read', 'File not found: %s', files{i});
    end
    if endsWith(files{i}, '.gz', 'IgnoreCase', true)
        if isempty(tmpDir)
            tmpDir = tempname;
            mkdir(tmpDir);
        end
        d = fullfile(tmpDir, sprintf('%04d', i));
        local(i) = gunzip(files{i}, d);
    end
end
cleanup = onCleanup(@() removeTmp(tmpDir)); %#ok<NASGU>

% Volume list: file index and volume index within the file
V = cell(numel(local), 1);
for i = 1:numel(local)
    v = spm_vol(local{i});
    for k = 1:numel(v)
        v(k).fname = files{i};
        v(k).private = [];
    end
    V{i} = v(:);
end
nPerFile = cellfun(@numel, V);
V = vertcat(V{:});
fileOf = repelem((1:numel(local))', nPerFile);
volOf = cell2mat(arrayfun(@(n) (1:n)', nPerFile, 'UniformOutput', false));

sel = opt.Volumes(:);
if isempty(sel)
    sel = (1:numel(V))';
elseif any(sel > numel(V))
    error('SeeCAT:read', 'Volume index %d exceeds the %d volumes available.', max(sel), numel(V));
end
V = V(sel);
fileOf = fileOf(sel);
volOf = volOf(sel);

if ~isempty(opt.Ref)
    ref = opt.Ref(1);
    dim = ref.dim(1:3);
    Y = zeros([dim numel(sel)], opt.Class);
    for k = 1:numel(sel)
        h = spm_vol(local{fileOf(k)});
        Y(:, :, :, k) = sc_resample_to_ref(h(volOf(k)), ref, opt.Interp);
    end
    R = rmfield(ref, intersect(fieldnames(ref), {'private'}));
    R.n = [1 1];
    V = repmat(R, numel(sel), 1);
    for k = 1:numel(sel)
        V(k).n = [k 1];
    end
    return
end

dim = V(1).dim(1:3);
for k = 2:numel(V)
    if ~isequal(V(k).dim(1:3), dim)
        error('SeeCAT:read', ['Images have different dimensions:\n  %s\n  %s\n' ...
            'Pass ''Ref'' to resample them to one grid.'], V(1).fname, V(k).fname);
    end
    if fileOf(k) ~= fileOf(1) && max(abs(V(k).mat(:) - V(1).mat(:))) > 1e-4
        error('SeeCAT:read', ['Images are on different voxel grids:\n  %s\n  %s\n' ...
            'Pass ''Ref'' to resample them to one grid.'], V(1).fname, V(k).fname);
    end
end

% Read file by file; nifti() applies the scaling and reads 4D blocks at once
Y = zeros([dim numel(sel)], opt.Class);
for f = unique(fileOf, 'stable')'
    k = find(fileOf == f);
    N = nifti(local{f});
    Y(:, :, :, k) = cast(N.dat(:, :, :, volOf(k)), opt.Class);
end
end

function removeTmp(d)
if ~isempty(d) && exist(d, 'dir')
    rmdir(d, 's');
end
end
