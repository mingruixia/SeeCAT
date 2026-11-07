function S = load_series(unit, maskSpec, only)
% LOAD_SERIES  A run's BOLD series, masks and kept frames, for analyses.
%   S = seecat.conn.load_series(unit, 'gm')     % or 'brain', or a mask file
%   S = seecat.conn.load_series(unit, 'brain', true)   % only the analysis-mask voxels
%
% With ONLY true, the columns outside the analysis mask are left out (Y,
% index, xyz, brain and in then hold the analysis-mask voxels only); Seed FC
% and Gradients use it with 'brain', so a group mask limits every voxel
% they use.
%
% UNIT has bold, mask (subject brain mask) and confounds (from
% seecat.bids.derivative_units). Frames with censor = 1 in the confounds
% table are dropped (decision D3). Fields of S:
%   Y      T x V series of the subject-mask voxels (single), kept frames only
%   brain  V x 1 true (the columns of Y are the subject-mask voxels)
%   in     V x 1 logical: voxels of the analysis mask (MASKSPEC) among them
%   xyz    3 x V voxel coordinates (mm)
%   index  V x 1 linear indices into the volume
%   hdr    spm_vol header of the first volume (the output grid)
%   n_frames, n_kept
% MASKSPEC: 'brain' = the subject mask; 'gm' = SeeCAT's TPM GM mask
% (templates/tpl-IXI549Space_res-<2|3>_label-GM_mask.nii, the resolution
% nearest the data), resampled to the data grid; or a mask file. The
% analysis mask is always limited to the subject mask, and to
% unit.group_mask when the unit has one (seecat.conn.group_mask: the
% voxels in the brain mask of every run).

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
idx = find(brain(:));
Y = reshape(Y, [], size(Y, 4))';
S.Y = Y(keep, idx);
S.index = idx;
S.hdr = hdr;
[i, j, k] = ind2sub(hdr.dim, idx);
S.xyz = hdr.mat(1:3, :) * [i j k ones(numel(idx), 1)]';
switch maskSpec
    case 'brain'
        m = true(size(idx));
    case 'gm'
        vox = mean(sqrt(sum(hdr.mat(1:3, 1:3) .^ 2)));
        res = 3;
        if abs(vox - 2) < abs(vox - 3)
            res = 2;
        end
        here = fileparts(fileparts(fileparts(mfilename('fullpath'))));
        f = fullfile(here, 'templates', sprintf('tpl-IXI549Space_res-%d_label-GM_mask.nii', res));
        g = seecat.io.read_nii(f, 'Ref', hdr, 'Interp', 0) > 0;
        m = g(idx);
    otherwise
        g = seecat.io.read_nii(maskSpec, 'Ref', hdr, 'Interp', 0) > 0;
        m = g(idx);
end
if isfield(unit, 'group_mask') && ~isempty(unit.group_mask)
    g = seecat.io.read_nii(unit.group_mask, 'Ref', hdr, 'Interp', 0) > 0;
    m = m(:) & g(idx);
end
S.in = m(:);
S.brain = true(numel(idx), 1);
if nargin > 2 && only
    S.Y = S.Y(:, S.in);
    S.index = S.index(S.in);
    S.xyz = S.xyz(:, S.in);
    S.brain = S.brain(S.in);
    S.in = true(nnz(S.in), 1);
end
S.n_frames = height(T);
S.n_kept = nnz(keep);
end
