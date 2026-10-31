function A = atlases(extra)
% ATLASES  Atlases available for labelling coordinates (design gui.md, G4).
%   A = seecat.view.atlases()
%   A = seecat.view.atlases({'my_atlas.nii', 'my_atlas.tsv'})   % plus a user atlas
%
% Only atlases the user already has are used; nothing is bundled:
%   Neuromorphometrics  spm/tpm/labels_Neuromorphometrics.nii + .xml (SPM)
%   AAL, Brodmann       BrainNet Viewer 2.0 lookup files, when it is on the path
%   user atlases        NIfTI + TSV with columns index and name
% A is a struct array: name, vol (3D label image), mat (voxel -> mm, 1-based),
% names (containers.Map index -> label), notice (credit to show with labels).

A = struct('name', {}, 'vol', {}, 'mat', {}, 'names', {}, 'notice', {});
f = fullfile(spm('dir'), 'tpm', 'labels_Neuromorphometrics.nii');
if exist(f, 'file')
    V = spm_vol(f);
    A(end+1) = struct('name', 'Neuromorphometrics', 'vol', spm_read_vols(V), 'mat', V.mat, ...
        'names', xmlLabels(strrep(f, '.nii', '.xml')), ...
        'notice', 'Neuromorphometrics labels (CC BY-NC): provided by Neuromorphometrics, Inc. under academic subscription; MRI from OASIS.');
end
bnv = brainnetDir();
if ~isempty(bnv)
    a = fullfile(bnv, 'BrainNet_AAL_Label.mat');
    if exist(a, 'file')
        s = load(a);
        A(end+1) = struct('name', 'AAL', 'vol', s.AAL_vol, 'mat', s.AAL_hdr.mat, ...
            'names', containers.Map(num2cell(1:numel(s.AAL_label)), cellstr(s.AAL_label(:))'), ...
            'notice', 'AAL (Tzourio-Mazoyer et al. 2002), lookup from BrainNet Viewer 2.0.');
    end
    b = fullfile(bnv, 'BrainNet_Brodmann_Label.mat');
    if exist(b, 'file')
        s = load(b);
        ids = unique(s.Brodmann_vol(s.Brodmann_vol > 0))';
        A(end+1) = struct('name', 'Brodmann', 'vol', s.Brodmann_vol, 'mat', s.Brodmann_hdr.mat, ...
            'names', containers.Map(num2cell(ids), arrayfun(@(k) sprintf('BA %d', k), ids, 'UniformOutput', false)), ...
            'notice', 'Brodmann areas (MRIcroN digitisation; approximate), lookup from BrainNet Viewer 2.0.');
    end
end
if nargin > 0 && ~isempty(extra)
    V = spm_vol(extra{1});
    T = seecat.io.read_tsv(extra{2});
    [~, n] = fileparts(extra{1});
    A(end+1) = struct('name', n, 'vol', spm_read_vols(V), 'mat', V.mat, ...
        'names', containers.Map(num2cell(double(T.index(:))'), cellstr(string(T.name(:)))'), 'notice', '');
end
end

function d = brainnetDir()
d = '';
w = which('BrainNetViewer');
if ~isempty(w)
    c = fullfile(fileparts(w), 'src', 'matlab', 'BrainNetViewer');
    if exist(c, 'dir')
        d = c;
    end
end
end

function M = xmlLabels(f)
t = fileread(f);
tok = regexp(t, '<index>(\d+)</index>\s*<name>([^<]*)</name>', 'tokens');
idx = cellfun(@(x) str2double(x{1}), tok);
nm = cellfun(@(x) strtrim(x{2}), tok, 'UniformOutput', false);
M = containers.Map(num2cell(idx), nm);
end
