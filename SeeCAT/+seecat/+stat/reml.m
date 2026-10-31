function [V, info] = reml(Y, X, I, var, dep, i0)
% REML  Error covariance (non-sphericity) of a group model, as SPM does.
%   [V, info] = seecat.stat.reml(Y, X, I, var, dep, i0)
%
% Y    n x nVox data (analysis mask), X n x p design.
% I    n x f factor levels (e.g. [subject, condition]); VAR(i) true for a
%      factor whose levels have their own variance; DEP(i) true for the
%      factor within whose levels observations are correlated (subject, for
%      repeated measures).
% I0   design columns of the reduced model for the first-pass F (subject
%      effects); the other columns are the "effects of interest".
%
% Same steps as spm_non_sphericity + spm_est_non_sphericity:
%   - covariance components: one per level of each VAR factor; one per pair
%     of cells of the other factors, within the levels of the DEP factor;
%   - voxels whose effects-of-interest F exceeds p < 0.001 (stats.fmri.ufp)
%     give the pooled covariance Cy of their data scaled by the residual SD;
%   - V = spm_reml(Cy, X, Q), scaled so that trace(V) = n.
% With fewer than two components, or no voxel passing, V = I (sphericity)
% and info.fallback says why.

n = size(Y, 1);
info = struct('components', 0, 'voxels', 0, 'h', [], 'fallback', '');
Q = components(I, var, dep);
info.components = numel(Q);
if numel(Q) < 2
    V = eye(n);
    info.fallback = 'one covariance component: sphericity';
    return
end
% First pass: ordinary fit, effects-of-interest F
Y = double(Y);
pX = pinv(X);
res = Y - X * (pX * Y);
ResSS = sum(res .^ 2, 1);
trRV = n - rank(X);
i1 = setdiff(1:size(X, 2), i0);
X0 = X(:, i0);
if isempty(X0)
    R0 = eye(n);
else
    R0 = eye(n) - X0 * pinv(X0);
end
X1o = R0 * X(:, i1);
M = X1o * pinv(X1o);
trMV = rank(X1o);
ESS = sum((M * Y) .^ 2, 1);
UF = spm_invFcdf(1 - 0.001, [trMV, trRV]);
j = ESS / trMV > UF * ResSS / trRV;
info.voxels = nnz(j);
if ~any(j)
    V = eye(n);
    info.fallback = 'no voxel passed the first-pass F (p < 0.001): sphericity';
    return
end
Yj = Y(:, j) .* sqrt(trRV ./ ResSS(j));
Cy = (Yj * Yj') / nnz(j);
[V, h] = spm_reml(Cy, X, Q);
V = full(V) * n / trace(V);
info.h = full(h(:))';
end

function Q = components(I, var, dep)
[n, f] = size(I);
l = max(I, [], 1);
Q = {};
for i = find(var)
    for j = 1:l(i)
        Q{end+1} = spdiags(double(I(:, i) == j), 0, n, n); %#ok<AGROW>
    end
end
X = ones(n, 1);
for i = find(~dep & (l > 1))
    Xi = sparse(1:n, I(:, i), 1, n, l(i));
    Xj = X;
    X = sparse(n, 0);
    for a = 1:size(Xi, 2)
        for b = 1:size(Xj, 2)
            X(:, end+1) = Xi(:, a) & Xj(:, b); %#ok<AGROW>
        end
    end
end
for i = find(dep)
    q = sparse(1:n, I(:, i), 1, n, l(i));
    P = q * q';
    for a = 1:size(X, 2)
        for b = a + 1:size(X, 2)
            Q{end+1} = (X(:, a) * X(:, b)' + X(:, b) * X(:, a)') .* P; %#ok<AGROW>
        end
    end
end
if f == 0
    Q = {};
end
end
