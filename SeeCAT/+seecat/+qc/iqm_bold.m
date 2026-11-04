function Q = iqm_bold(Y, mask, fd, vox, dummy)
% IQM_BOLD  MRIQC image quality metrics of a BOLD run.
%   Q = seecat.qc.iqm_bold(Y, mask, fd, vox, dummy)
%
% Y      4D head-motion-corrected series (native EPI space, dummy scans
%        removed, not otherwise processed)
% mask   3D brain mask on the same grid
% fd     framewise displacement per frame (Power), first frame excluded or 0
% vox    voxel size (mm); DUMMY: non-steady-state volumes removed
%
% As MRIQC 24 (interfaces.functional.FunctionalQC, nipype ComputeDVARS and
% TSNR, mriqc.qc.functional.gsr), on the mean EPI and the series:
%   snr, fber, efc, gsr_x, gsr_y, tsnr (median over the mask),
%   dvars_std, dvars_nstd, dvars_vstd (means over frames), fd_mean, fd_num,
%   fd_perc (FD > 0.2 mm), summary_fg_* and summary_bg_*.
% The AFNI-based metrics are re-implemented after their definitions
% (MRIQC calls AFNI): aor (3dToutcount -fraction, quadratic detrend),
% aqi (3dTqual: 1 - Spearman r with the median volume, mean over time),
% gcor (global correlation, @compute_gcor) and fwhm_* (seecat.qc.iqm_fwhm,
% in voxels as MRIQC reports them).

Y = double(Y);
Y(~isfinite(Y) | Y < 0) = 0;
mask = logical(mask);
nt = size(Y, 4);
epi = mean(Y, 4);
Q = struct();
fg = seecat.qc.iqm_stats(epi, mask);
bg = seecat.qc.iqm_stats(epi, ~mask);
Q.snr = fg.median / (fg.stdv * sqrt(fg.n / (fg.n - 1)));
Q.fber = fber(epi, mask);
Q.efc = seecat.qc.iqm_efc(epi, []);
Q.gsr_x = gsr(epi, mask, 1);
Q.gsr_y = gsr(epi, mask, 2);
M = reshape(Y, [], nt);
M = M(mask(:), :);                                 % voxels x time
sd = std(M, 1, 2);
mu = mean(M, 2);
ts = zeros(size(mu));                              % as nipype TSNR
ok = sd > 1e-3;
ts(ok) = mu(ok) ./ sd(ok);
Q.tsnr = median(ts);
[Q.dvars_std, Q.dvars_nstd, Q.dvars_vstd] = dvars(M);
fd = double(fd(:));
if numel(fd) == nt
    fd = fd(2:end);
end
Q.fd_mean = mean(fd);
Q.fd_num = nnz(fd > 0.2);
Q.fd_perc = Q.fd_num * 100 / (numel(fd) + 1);
Q.aor = aor(M);
Q.aqi = aqi(M);
Q.gcor = gcor(M);
fw = seecat.qc.iqm_fwhm(Y, mask, vox) ./ vox;
Q.fwhm_x = fw(1);
Q.fwhm_y = fw(2);
Q.fwhm_z = fw(3);
Q.fwhm_avg = mean(fw);
Q.dummy_trs = dummy;
for f = {'mean', 'median', 'stdv', 'p05', 'p95', 'mad', 'k', 'n'}
    Q.(['summary_fg_' f{1}]) = fg.(f{1});
    Q.(['summary_bg_' f{1}]) = bg.(f{1});
end
end

function r = fber(img, mask)
fg = median(abs(img(mask)) .^ 2);
bg = median(abs(img(~mask)) .^ 2);
r = -1;
if bg >= 1e-3
    r = round(fg / bg, 4);
end
end

function g = gsr(epi, mask, axis)
% Ghost to signal: the brain mask moved by half the field of view
n2 = circshift(double(mask), floor(size(mask, axis) / 2), axis);
n2 = n2 .* (1 - mask);
n2 = n2 + 2 * (1 - n2 - mask);
ghost = mean(epi(n2 == 1)) - mean(epi(n2 == 2));
g = ghost / median(epi(n2 == 0));
end

function [s, n, v] = dvars(M)
% nipype compute_dvars (intensity normalisation 1000, zero-variance voxels out)
M = M / median(M(:)) * 1000;
srt = sort(M, 2);
nt = size(M, 2);
lower = @(p) srt(:, floor((nt - 1) * p / 100) + 1);   % numpy percentile, method 'lower'
sdv = (lower(75) - lower(25)) / 1.349;
keep = sdv > 1e-7;
M = M(keep, :);
sdv = sdv(keep);
x = M - mean(M, 2);
r0 = sum(x .^ 2, 2) / nt;
r1 = sum(x(:, 1:end-1) .* x(:, 2:end), 2) / nt;
ar1 = r1 ./ r0;                                    % Yule-Walker, order 1
dsd = sqrt((1 - ar1) * 2) .* sdv;
dm = diff(M, 1, 2);
nstd = sqrt(mean(dm .^ 2, 1));
s = mean(nstd / mean(dsd));
n = mean(nstd);
v = mean(sqrt(mean((dm ./ dsd) .^ 2, 1)));
end

function a = aor(M)
% 3dToutcount -fraction: per frame, the share of voxels whose detrended
% value is further than alpha * MAD from the voxel's median, alpha from the
% normal quantile of 0.001/N (as AFNI), quadratic trend removed
nt = size(M, 2);
t = linspace(-1, 1, nt)';
X = [ones(nt, 1), t, 1.5 * t .^ 2 - 0.5];
R = (M' - X * (X \ M'))';
med = median(R, 2);
mad = median(abs(R - med), 2);
alpha = -sqrt(2) * erfcinv(2 * (1 - 0.001 / nt)) * sqrt(pi / 2);
alpha = abs(alpha);
out = abs(R - med) > alpha * mad & mad > 0;
a = mean(mean(out, 1));
end

function q = aqi(M)
% 3dTqual: 1 - Spearman correlation of each volume with the median volume
med = median(M, 2);
rm = tiedrank(med);
nt = size(M, 2);
c = zeros(1, nt);
for k = 1:nt
    rk = tiedrank(M(:, k));
    c(k) = 1 - corrPearson(rk, rm);
end
q = mean(c);
end

function r = tiedrank(x)
[s, o] = sort(x);
n = numel(x);
r = zeros(n, 1);
r(o) = 1:n;
d = [true; diff(s) ~= 0; true];
idx = find(d);
for i = 1:numel(idx) - 1                            % average ranks of ties
    a = idx(i);
    b = idx(i + 1) - 1;
    if b > a
        r(o(a:b)) = (a + b) / 2;
    end
end
end

function c = corrPearson(a, b)
a = a - mean(a);
b = b - mean(b);
c = sum(a .* b) / sqrt(sum(a .^ 2) * sum(b .^ 2));
end

function g = gcor(M)
x = M - mean(M, 2);
nr = sqrt(sum(x .^ 2, 2));
x = x(nr > 0, :) ./ nr(nr > 0);
gm = mean(x, 1);
g = sum(gm .^ 2);
end
