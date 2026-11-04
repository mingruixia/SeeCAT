function f = iqm_fwhm(img, mask, vox)
% IQM_FWHM  Smoothness (FWHM, mm) along x, y, z from first differences.
%   f = seecat.qc.iqm_fwhm(img, mask, vox)
%
% The classic estimate behind AFNI 3dFWHMx (Forman et al. 1995): with v the
% variance of the image in MASK and d the variance of its differences
% between neighbours (both voxels in the mask) along an axis,
% FWHM = vox * sqrt(-2 ln 2 / ln(1 - d / (2 v))). IMG may be 4D (then a
% linear trend is removed per voxel and the estimate is averaged over
% volumes, as 3dFWHMx -detrend does with its own detrending).
img = double(img);
nt = size(img, 4);
if nt > 1
    Y = reshape(img, [], nt)';
    t = (1:nt)' - (nt + 1) / 2;
    X = [ones(nt, 1), t];
    Y = Y - X * (X \ Y);
    img = reshape(Y', size(img));
end
f = zeros(1, 3);
for ax = 1:3
    acc = zeros(1, nt);
    for k = 1:nt
        v = img(:, :, :, k);
        a = v(mask);
        va = var(a, 1);
        sz = size(v);
        lo = repmat({':'}, 1, 3);
        hi = lo;
        lo{ax} = 1:sz(ax) - 1;
        hi{ax} = 2:sz(ax);
        both = mask(lo{:}) & mask(hi{:});
        d = v(hi{:}) - v(lo{:});
        vd = var(d(both), 1);
        r = 1 - vd / (2 * va);
        acc(k) = NaN;
        if r > 0 && r < 1
            acc(k) = vox(ax) * sqrt(-2 * log(2) / log(r));
        end
    end
    f(ax) = mean(acc, 'omitnan');
end
end
