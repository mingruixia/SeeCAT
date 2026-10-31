function [r, z, empty] = seed_fc(Y, seeds)
% SEED_FC  Seed-based correlation maps.
%   [r, z, empty] = seecat.conn.seed_fc(Y, seeds)
%
% Y is T x V (good frames only), SEEDS is V x S logical (one column per
% seed, over the same voxels). Each seed's series is the mean of its voxels
% that carry signal (non-zero variance, finite). R and Z (Fisher z) are
% S x V; voxels without variance get 0, and r is kept inside (-1, 1) so z
% stays finite. EMPTY(s) is true when seed s has no voxel with signal; its
% maps are 0.

Y = double(Y);
[T, ~] = size(Y);
sd = std(Y, 0, 1);
live = sd > 0 & all(isfinite(Y), 1);
nS = size(seeds, 2);
ts = zeros(T, nS);
empty = false(1, nS);
for s = 1:nS
    v = seeds(:, s)' & live;
    if ~any(v)
        empty(s) = true;
        continue
    end
    ts(:, s) = mean(Y(:, v), 2);
end
r = zscore0(ts)' * zscore0(Y) / (T - 1);
r(:, ~live) = 0;
r(empty, :) = 0;
r(~isfinite(r)) = 0;
lim = 1 - double(eps('single'));    % double: a single bound would make r single
r = min(max(r, -lim), lim);
z = atanh(r);
end

function X = zscore0(X)
X = X - mean(X, 1);
X = X ./ std(X, 0, 1);
end
