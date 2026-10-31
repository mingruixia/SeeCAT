function files = make_templates(out_dir, vox)
% MAKE_TEMPLATES  Group masks in IXI549Space from SPM's tissue probability maps.
%   files = seecat.util.make_templates(out_dir, 3)
%   files = seecat.util.make_templates(out_dir, [2 3])
%
% For each voxel size, on the grid SPM normalisation writes with SeeCAT's
% default bounding box ([-90 -126 -72; 90 90 108]; 61x73x61 at 3 mm,
% 91x109x91 at 2 mm), writes uint8 masks with JSON sidecars:
%   tpl-IXI549Space_res-<v>_desc-brain_mask.nii   GM + WM + CSF > 0.5
%   tpl-IXI549Space_res-<v>_label-GM_mask.nii     GM  > 0.2
%   tpl-IXI549Space_res-<v>_label-WM_mask.nii     WM  > 0.9
%   tpl-IXI549Space_res-<v>_label-CSF_mask.nii    CSF > 0.7
% The thresholds are those of the masks SeeCAT 1.0 shipped. Each target
% voxel's probability is the mean of 3 x 3 x 3 trilinear samples of
% spm/tpm/TPM.nii (1.5 mm) spread over the voxel, so thin structures keep
% their partial volume. The masks are uncompressed .nii so that SPM-based
% code can read them directly.

if nargin < 2
    vox = [2 3];
end
tpm = fullfile(spm('dir'), 'tpm', 'TPM.nii');
if ~exist(tpm, 'file')
    error('SeeCAT:templates', 'SPM tissue probability maps not found: %s', tpm);
end
bb = [-90 -126 -72; 90 90 108];
masks = {
    'desc-brain', 1:3, 0.5, 'GM + WM + CSF'
    'label-GM',   1,   0.2, 'GM'
    'label-WM',   2,   0.9, 'WM'
    'label-CSF',  3,   0.7, 'CSF'
    };
[~, spmRel] = spm('Ver');
files = {};
if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end
for v = vox(:)'
    [M, dim] = grid(bb, v);
    P = zeros([dim 3]);
    for k = 1:3
        P(:, :, :, k) = averaged(spm_vol(sprintf('%s,%d', tpm, k)), M, dim);
    end
    for i = 1:size(masks, 1)
        name = sprintf('tpl-IXI549Space_res-%g_%s_mask.nii', v, masks{i, 1});
        f = fullfile(out_dir, name);
        m = sum(P(:, :, :, masks{i, 2}), 4) > masks{i, 3};
        o = struct('fname', f, 'dim', dim, 'dt', [spm_type('uint8') spm_platform('bigend')], ...
            'mat', M, 'pinfo', [1; 0; 0], ...
            'descrip', sprintf('SeeCAT %s > %g from SPM TPM', masks{i, 4}, masks{i, 3}));
        spm_write_vol(o, double(m));
        seecat.util.write_json(regexprep(f, '\.nii$', '.json'), struct( ...
            'Type', masks{i, 4}, 'Threshold', masks{i, 3}, ...
            'Description', sprintf('%s probability > %g, mean over each voxel', masks{i, 4}, masks{i, 3}), ...
            'Sources', {{'spm/tpm/TPM.nii'}}, 'SPMVersion', spmRel, ...
            'GeneratedBy', struct('Name', 'SeeCAT', 'Version', seecat.version(), ...
            'Code', 'seecat.util.make_templates')));
        files{end+1, 1} = f; %#ok<AGROW>
    end
end
end

function [M, dim] = grid(bb, v)
% As spm_run_norm/spm_get_bbox write it: voxel centres from bb(1,:) in
% steps of v, x flipped (radiological storage, as SPM's default output)
dim = round(diff(bb) / v + 1);
M = [-v 0 0 0; 0 v 0 0; 0 0 v 0; 0 0 0 1];
M(1:3, 4) = [bb(2, 1) + v; bb(1, 2) - v; bb(1, 3) - v];
end

function p = averaged(V, M, dim)
% Mean of 3x3x3 trilinear samples per target voxel
[i, j, k] = ndgrid(1:dim(1), 1:dim(2), 1:dim(3));
off = [-1 0 1] / 3;
p = zeros(dim);
for a = off
    for b = off
        for c = off
            xyz = M * [i(:) + a, j(:) + b, k(:) + c, ones(numel(i), 1)]';
            src = V.mat \ xyz;
            p(:) = p(:) + spm_sample_vol(V, src(1, :)', src(2, :)', src(3, :)', 1);
        end
    end
end
p = p / 27;
end
