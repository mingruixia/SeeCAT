function Q = iqm_anat(T1, inu, pv, head, air, rot, vox)
% IQM_ANAT  MRIQC image quality metrics of a T1w image.
%   Q = seecat.qc.iqm_anat(T1, inu, pv, head, air, rot, vox)
%
% T1    bias-corrected T1w (any scale; it is rescaled so that the median of
%       eroded WM with probability >= 0.9 is 1000, as MRIQC's Harmonize)
% inu   intensity non-uniformity (bias) field, raw = corrected x inu
% pv    {CSF, GM, WM} partial-volume (probability) maps on the T1 grid
% head, air, rot   logical masks: head, background air, and voxels outside
%       the field of view or zeroed (e.g. defacing), left out of EFC/FBER
% vox   voxel size (mm)
%
% Definitions follow MRIQC 24 (mriqc.qc.anatomical and
% interfaces.anatomical.StructuralQC); seecat.qc.iqm_stats gives the
% weighted summary statistics MRIQC takes from statsmodels:
%   cjv, cnr, snr_csf/gm/wm/total, snrd_* (Dietrich), efc, fber, wm2max,
%   inu_med, inu_range, icvs_* (volume fractions), rpve_*, fwhm_x/y/z/avg
%   (in voxels; classic first-difference estimate within the head, an
%   approximation of AFNI 3dFWHMx), summary_<tissue>_<stat>.
% Left out: qi_1, qi_2 (artefact fitting) and tpm_overlap.

T1 = double(T1);
T1(~isfinite(T1) | T1 < 0) = 0;
wm = pv{3} >= 0.9;
wm = seecat.qc.iqm_morph(wm, 'erode');
T1 = T1 * 1000 / median(T1(wm));
names = {'csf', 'gm', 'wm', 'bg'};
P = [pv(:)', {double(air)}];
S = struct();
for k = 1:4
    S.(names{k}) = seecat.qc.iqm_stats(T1, P{k});
end
Q = struct();
snrs = zeros(1, 3);
for k = 1:3
    s = S.(names{k});
    snrs(k) = s.median / (s.stdv * sqrt(s.n / (s.n - 1)));
    Q.(['snr_' names{k}]) = snrs(k);
end
Q.snr_total = mean(snrs);
DF = 0.6551364;
for k = 1:3
    s = S.(names{k});
    if S.bg.mad > 1
        Q.(['snrd_' names{k}]) = DF * s.median / S.bg.mad;
    elseif S.bg.stdv > 1e-3
        Q.(['snrd_' names{k}]) = DF * s.median / S.bg.stdv;
    else
        Q.(['snrd_' names{k}]) = -1;
    end
end
Q.snrd_total = mean([Q.snrd_csf, Q.snrd_gm, Q.snrd_wm]);
Q.cnr = abs(S.wm.median - S.gm.median) / sqrt(S.bg.stdv ^ 2 + S.gm.stdv ^ 2 + S.wm.stdv ^ 2);
Q.cjv = (S.wm.mad + S.gm.mad) / abs(S.wm.median - S.gm.median);
Q.fber = fber(T1, head, rot);
Q.efc = seecat.qc.iqm_efc(T1, rot);
Q.wm2max = S.wm.median / prctileLinear(T1(:), 99.95);
seg = (pv{1} + pv{2} + pv{3}) > 0.5;           % brain, as MRIQC's segmentation > 0
b = double(inu(seg));
Q.inu_med = median(b);
Q.inu_range = abs(prctileLinear(b, 95) - prctileLinear(b, 5));
tot = sum(pv{1}(:)) + sum(pv{2}(:)) + sum(pv{3}(:));
for k = 1:3
    Q.(['icvs_' names{k}]) = sum(pv{k}(:)) / tot;
    Q.(['rpve_' names{k}]) = rpve(pv{k});
end
fw = seecat.qc.iqm_fwhm(T1, head, vox) ./ vox;
Q.fwhm_x = fw(1);
Q.fwhm_y = fw(2);
Q.fwhm_z = fw(3);
Q.fwhm_avg = mean(fw);
for k = 1:4
    for f = {'mean', 'median', 'stdv', 'p05', 'p95', 'mad', 'k', 'n'}
        Q.(sprintf('summary_%s_%s', names{k}, f{1})) = S.(names{k}).(f{1});
    end
end
end

function r = fber(img, head, rot)
fg = median(abs(img(head)) .^ 2);
airm = ~head & ~rot;
bg = median(abs(img(airm)) .^ 2);
r = -1;
if bg >= 1e-3
    r = round(fg / bg, 4);
end
end

function v = rpve(p)
p = double(p(:));
p(p < 0) = 0;
p(p >= 1) = 1;
total = nnz(p > 0);
pos = p(p > 0);
up = prctileLinear(pos, 98);
lo = prctileLinear(pos, 2);
p(p < lo) = 0;
p(p > up) = 0;
v = (sum(p(p > 0.5)) + sum(1 - p(p <= 0.5))) / total;
end

function q = prctileLinear(x, p)
% numpy's default percentile (linear interpolation between order statistics)
x = sort(double(x(:)));
n = numel(x);
h = (n - 1) * p / 100 + 1;
lo = floor(h);
hi = min(lo + 1, n);
q = x(lo) + (h - lo) * (x(hi) - x(lo));
end
