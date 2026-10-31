function S = smoothness(G, mask, hdr)
% SMOOTHNESS  FWHM and resel counts from the residuals of a fitted model.
%   S = seecat.stat.smoothness(G, mask, hdr)
%
% G is the output of seecat.stat.glm (res, ResSS, trRV); MASK the 3D
% analysis mask; HDR its spm_vol header. Same estimator as SPM's
% spm_est_smoothness on the residual images spm_spm writes (Kiebel et al.
% 1999; Worsley 1996): at most 64 standardised residuals res / sqrt(ResSS /
% erdf), NaN outside the mask; their spatial derivatives (spm_sample_vol,
% trilinear) give the resels per voxel; FWHM is their mean, and the resel
% counts of the search volume come from spm_resels_vol. Nothing is written
% to disk (spm_est_smoothness writes RPV.nii to the current folder).
%
% S fields: FWHM (voxels), FWHMmm, R (resel counts, 1 x 4), RPV (resels per
% voxel over the mask voxels), V2R (1 / prod(FWHM)), nVox.

n = size(G.res, 1);
erdf = G.trRV;                                 % spm_spm: erdf = trRV of the model
nSres = min(n, 64);                            % spm_defaults stats.maxres
iRes = round(linspace(1, n, nSres))';
idx = find(mask);
[Ix, Iy, Iz] = ind2sub(size(mask), idx);
sd = sqrt(G.ResSS / erdf);
D = 3 - sum(size(mask) == 1);
L = zeros(numel(idx), 3, 3);
ssq = zeros(numel(idx), 1);
for i = 1:nSres
    vol = nan(size(mask));
    vol(idx) = G.res(iRes(i), :) ./ sd;
    [d, dx, dy, dz] = spm_sample_vol(vol, Ix, Iy, Iz, 1);
    ssq = ssq + d .^ 2;
    L(:, 1, 1) = L(:, 1, 1) + dx .* dx;
    L(:, 1, 2) = L(:, 1, 2) + dx .* dy;
    L(:, 2, 2) = L(:, 2, 2) + dy .* dy;
    L(:, 1, 3) = L(:, 1, 3) + dx .* dz;
    L(:, 2, 3) = L(:, 2, 3) + dy .* dz;
    L(:, 3, 3) = L(:, 3, 3) + dz .* dz;
end
L = L / nSres * (n / erdf);
xyz = [L(:, 1, 1) L(:, 2, 2) L(:, 3, 3)];
img = L(:, 1, 1) .* L(:, 2, 2) .* L(:, 3, 3) + L(:, 1, 2) .* L(:, 2, 3) .* L(:, 1, 3) * 2 - ...
    L(:, 1, 1) .* L(:, 2, 3) .* L(:, 2, 3) - L(:, 1, 2) .* L(:, 1, 2) .* L(:, 3, 3) - ...
    L(:, 1, 3) .* L(:, 2, 2) .* L(:, 1, 3);
img(img < 0) = 0;
img = sqrt(img / (4 * log(2)) ^ D);
xyz = sqrt(xyz / (4 * log(2)));
S.RPV = img;
bad = isnan(ssq) | ssq < sqrt(eps);
img = mean(img(~bad, :));
xyz = mean(xyz(~bad, :));
RESEL = img ^ (1 / D) * (xyz / prod(xyz) ^ (1 / D));
FWHM = 1 ./ RESEL;
FWHM(isnan(FWHM)) = 0;
FWHM(~FWHM) = 1;
S.FWHM = FWHM;
S.FWHMmm = FWHM .* sqrt(sum(hdr.mat(1:3, 1:3) .^ 2));
S.R = spm_resels_vol(double(mask), FWHM)';
S.V2R = 1 / prod(FWHM);
S.nVox = numel(idx);
end
