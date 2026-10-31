function C = compcor(Y, n, order, good)
% COMPCOR  Principal components of noise-region time series (Behzadi 2007).
%   C = seecat.denoise.compcor(Y, n, order, good)
%
% Y is T x V (voxels of one tissue mask). Each voxel is detrended
% (polynomial of ORDER) and scaled to unit variance. The components come
% from the GOOD frames only (T x 1 logical; default all), so high-motion
% frames cannot dominate them, and are then evaluated for every frame.
% C is T x n, each column with zero mean and unit variance over good
% frames; fewer than N columns are returned when the data do not support N.

T = size(Y, 1);
if nargin < 4 || isempty(good)
    good = true(T, 1);
end
good = logical(good(:));
Y = double(Y);
P = seecat.denoise.poly_trend(T, order);
Y = Y - P * (P(good, :) \ Y(good, :));
sd = std(Y(good, :), 0, 1);
keep = sd > 0 & all(isfinite(Y), 1);
Y = Y(:, keep) ./ sd(keep);
n = min([n, nnz(good) - 1, size(Y, 2)]);
if n < 1
    C = zeros(T, 0);
    return
end
[~, ~, V] = svd(Y(good, :), 'econ');
C = Y * V(:, 1:n);
C = (C - mean(C(good, :), 1)) ./ std(C(good, :), 0, 1);
end
