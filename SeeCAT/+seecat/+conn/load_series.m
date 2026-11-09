function S = load_series(unit, maskSpec, only, opt)
% LOAD_SERIES  A run's BOLD series, masks and kept frames, for analyses.
%   S = seecat.conn.load_series(unit, 'gm')     % or 'brain', or a mask file
%   S = seecat.conn.load_series(unit, 'brain', true)   % only the analysis-mask voxels
%   S = seecat.conn.load_series(unit, 'gm', true, struct('mask_only', true))
%
% UNIT has bold, mask (subject brain mask) and confounds (from
% seecat.bids.derivative_units). Frames with censor = 1 in the confounds
% table are dropped (decision D3).
%
% The columns of Y are the base voxels: the subject brain mask, limited to
% unit.group_mask when the unit has one (seecat.conn.group_mask: the voxels
% in the brain mask of every run). The analysis mask (MASKSPEC) is taken
% within them. MASKSPEC: 'brain' = the subject mask; 'gm' = SeeCAT's TPM GM
% mask (templates/tpl-IXI549Space_res-<2|3>_label-GM_mask.nii, the
% resolution nearest the data), resampled to the data grid; or a mask file.
%
% OPT.mask_only true: the base voxels are the analysis mask itself, as
% given, not limited to the brain mask (MASKSPEC 'gm' or a file; the group
% mask is not used). Voxels outside a run's brain mask or field of view
% then usually carry no signal (the denoised series is 0 there); see
% S.live. OPT.extra, a function of the header giving a logical volume,
% adds voxels to the base (not to the analysis mask), e.g. the seeds of
% Seed FC.
%
% With ONLY true, the columns outside the analysis mask are left out.
% Fields of S:
%   Y      T x V series of the base voxels (single), kept frames only
%   in     V x 1 logical: voxels of the analysis mask among them
%   brain  V x 1 logical: voxels in the run's brain mask
%   live   1 x V logical: voxels with signal (non-zero variance, finite)
%   xyz    3 x V voxel coordinates (mm)
%   index  V x 1 linear indices into the volume
%   hdr    spm_vol header of the first volume (the output grid)
%   n_frames, n_kept

if nargin < 3 || isempty(only)
    only = false;
end
if nargin < 4
    opt = struct();
end
maskOnly = isfield(opt, 'mask_only') && opt.mask_only;
T = seecat.io.read_tsv(unit.confounds);
keep = true(height(T), 1);
if ismember('censor', T.Properties.VariableNames)
    keep = T.censor == 0;
end
[Y, V] = seecat.io.read_nii(unit.bold, 'Class', 'single');
if size(Y, 4) ~= height(T)
    error('SeeCAT:conn', '%s has %d frames but its confounds table %d.', unit.bold, size(Y, 4), height(T));
end
hdr = V(1);
brain = logical(seecat.io.read_nii(unit.mask, 'Ref', hdr));
switch maskSpec
    case 'brain'
        if maskOnly
            error('SeeCAT:conn', ['"Use the mask as given" needs a mask other than the brain mask: ' ...
                'gm or a mask file.']);
        end
        m = brain;
    case 'gm'
        vox = mean(sqrt(sum(hdr.mat(1:3, 1:3) .^ 2)));
        res = 3;
        if abs(vox - 2) < abs(vox - 3)
            res = 2;
        end
        here = fileparts(fileparts(fileparts(mfilename('fullpath'))));
        f = fullfile(here, 'templates', sprintf('tpl-IXI549Space_res-%d_label-GM_mask.nii', res));
        m = seecat.io.read_nii(f, 'Ref', hdr, 'Interp', 0) > 0;
    otherwise
        m = seecat.io.read_nii(maskSpec, 'Ref', hdr, 'Interp', 0) > 0;
end
m = m(:, :, :, 1);
if maskOnly
    base = m;
    if isfield(opt, 'extra') && ~isempty(opt.extra)
        base = base | opt.extra(hdr);
    end
else
    base = brain;
    if isfield(unit, 'group_mask') && ~isempty(unit.group_mask)
        base = base & seecat.io.read_nii(unit.group_mask, 'Ref', hdr, 'Interp', 0) > 0;
    end
end
idx = find(base(:));
if isempty(idx)
    if maskOnly
        error('SeeCAT:conn', 'The mask has no voxel on the grid of %s; check its space.', unit.bold);
    end
    error('SeeCAT:conn', ['No voxel of the brain mask%s of %s lies on its BOLD grid; check the ' ...
        'space of the masks.'], ternary(isfield(unit, 'group_mask') && ~isempty(unit.group_mask), ...
        ' and group mask', ''), unit.bold);
end
in = m(idx);
if only
    idx = idx(in);
    in = true(numel(idx), 1);
end
Y = reshape(Y, [], size(Y, 4))';
S.Y = Y(keep, idx);
S.index = idx;
S.in = in(:);
S.brain = brain(idx);
S.live = std(S.Y, 0, 1) > 0 & all(isfinite(S.Y), 1);
S.hdr = hdr;
[i, j, k] = ind2sub(hdr.dim, idx);
S.xyz = hdr.mat(1:3, :) * [i j k ones(numel(idx), 1)]';
S.n_frames = height(T);
S.n_kept = nnz(keep);
end

function s = ternary(c, a, b)
if c
    s = a;
else
    s = b;
end
end
