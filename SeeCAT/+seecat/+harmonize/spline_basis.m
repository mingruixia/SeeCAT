function B = spline_basis(x, df)
% SPLINE_BASIS  Natural cubic spline basis of x (no intercept), as R's ns(x, df).
%   B = seecat.harmonize.spline_basis(age, 3)
%
% DF columns: x itself and DF - 1 truncated-power terms (Hastie, Tibshirani
% & Friedman, The Elements of Statistical Learning, eq. 5.4-5.5), with
% boundary knots at the range of x and DF - 1 inner knots at its
% quantiles. The columns span the same space as R's ns(), which the
% ComBat-GAM implementation (neuroHarmonize) and mgcv-style smooths use;
% the fit (and so the harmonised data) does not depend on the basis chosen.
% Columns are centred and scaled to unit SD for numerical stability.

x = double(x(:));
if df == 1
    B = (x - mean(x)) / std(x);
    return
end
q = linspace(0, 1, df + 1);
s = sort(x);
k = unique(interp1(linspace(0, 1, numel(s)), s, q));   % quantiles (no toolbox needed)
K = numel(k);
if K < 3
    B = (x - mean(x)) / std(x);
    return
end
d = @(j) (max(x - k(j), 0) .^ 3 - max(x - k(K), 0) .^ 3) / (k(K) - k(j));
B = x;
for j = 1:K - 2
    B = [B, d(j) - d(K - 1)]; %#ok<AGROW>
end
B = (B - mean(B, 1)) ./ std(B, 0, 1);
end
