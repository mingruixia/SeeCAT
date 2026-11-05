function Q = registration(epi, mask, P, hdr, valid)
% REGISTRATION  Quantitative checks of normalisation and EPI-T1 alignment.
%   Q = seecat.qc.registration(meanEpi, brainMask, {GM, WM, CSF}, hdr, valid)
%
% All inputs are on the grid of the normalised BOLD data (HDR): the mean
% EPI, the run's brain mask, the subject's normalised tissue probability
% maps (P; {} when there are none) and the voxels inside the field of view.
% Templates: SeeCAT's IXI549Space brain mask and SPM's tissue probability
% maps (TPM.nii), resampled to HDR.
%
%   reg_brain_dice   Dice of the brain mask and the template brain mask
%                    (overall shape and position after normalisation)
%   reg_gm_corr, reg_wm_corr, reg_csf_corr
%                    spatial correlation of the subject's normalised tissue
%                    map with the TPM inside the template or subject brain
%                    (tissue-level fit of the normalisation)
%   reg_gm_dice      Dice of GM > 0.5 and TPM GM > 0.5
%   reg_epi_t1_dice  Dice of a brain mask from the mean EPI's own intensity
%                    (above 20 % of its 98th percentile, largest connected
%                    part) with the brain from the T1w tissue maps (GM + WM +
%                    CSF > 0.5): how well the EPI sits on its T1w. Typical
%                    values are 0.85-0.92 (EPI signal loss near the sinuses
%                    keeps it below 1); compare within a site
% Fields that cannot be computed are NaN.
Q = struct('reg_brain_dice', NaN, 'reg_gm_corr', NaN, 'reg_wm_corr', NaN, 'reg_csf_corr', NaN, ...
    'reg_gm_dice', NaN, 'reg_epi_t1_dice', NaN);
here = fileparts(fileparts(fileparts(mfilename('fullpath'))));
vox = mean(sqrt(sum(hdr.mat(1:3, 1:3) .^ 2)));
res = 3;
if abs(vox - 2) < abs(vox - 3)
    res = 2;
end
tb = seecat.io.read_nii(fullfile(here, 'templates', sprintf('tpl-IXI549Space_res-%d_desc-brain_mask.nii', res)), ...
    'Ref', hdr, 'Interp', 0) > 0;
mask = logical(mask);
Q.reg_brain_dice = dice(mask, tb);
if isempty(P)
    return
end
tpm = fullfile(spm('dir'), 'tpm', 'TPM.nii');
T = seecat.io.read_nii(tpm, 'Volumes', 1:3, 'Ref', hdr, 'Interp', 1);
roi = (tb | mask) & valid;
names = {'gm', 'wm', 'csf'};
for k = 1:3
    a = double(P{k}(roi));
    b = double(reshape(T(:, :, :, k), [], 1));
    b = b(roi(:));
    c = corrcoef(a, b);
    Q.(['reg_' names{k} '_corr']) = c(1, 2);
end
Q.reg_gm_dice = dice(P{1} > 0.5 & valid, T(:, :, :, 1) > 0.5 & valid);
epi = double(epi);
v = epi(valid & epi > 0);
if numel(v) > 100
    s = sort(v);
    e = epi > 0.2 * s(round(0.98 * numel(s))) & valid;
    [L, n] = spm_bwlabel(double(e), 18);
    if n > 0
        c = accumarray(L(L > 0), 1);
        [~, k] = max(c);
        Q.reg_epi_t1_dice = dice(L == k, (P{1} + P{2} + P{3}) > 0.5 & valid);
    end
end
end

function d = dice(a, b)
d = 2 * nnz(a & b) / max(nnz(a) + nnz(b), 1);
end
