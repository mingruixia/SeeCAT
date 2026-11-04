function [A, ref] = align(G, ref, n_iter)
% ALIGN  Procrustes alignment of gradients across runs.
%   [A, ref] = seecat.gradient.align(G)            % generalized, 10 iterations
%   A = seecat.gradient.align(G, ref, 1)           % to a fixed reference
%
% G is a cell array of V x k gradient sets (same nodes; NaN rows are left
% out of the fit and stay NaN). As BrainSpace's procrustes_alignment: each
% set is rotated (orthogonal transform, reflections allowed, no centring or
% scaling) to the reference; without REF the first set starts as the
% reference, and each iteration replaces it by the mean of the aligned sets
% (up to N_ITER times, until the change is below 1e-5).

if nargin < 3, n_iter = 10; end
ok = true(size(G{1}, 1), 1);
for i = 1:numel(G)
    ok = ok & all(isfinite(G{i}), 2);
end
D = cellfun(@(g) g(ok, :), G, 'UniformOutput', false);
if nargin < 2 || isempty(ref)
    first = cellfun(@(d) rot(d, D{1}), D(2:end), 'UniformOutput', false);
    r = mean(cat(3, D{1}, first{:}), 3);
else
    r = ref(ok, :);
end
dist = Inf;
for it = 1:n_iter
    out = cellfun(@(d) rot(d, r), D, 'UniformOutput', false);
    newR = mean(cat(3, out{:}), 3);
    nd = sum((r - newR) .^ 2, 'all');
    if nargin < 2 || isempty(ref) || n_iter > 1
        r = newR;
    end
    if isfinite(dist) && abs(nd - dist) < 1e-5
        break
    end
    dist = nd;
end
A = cell(size(G));
for i = 1:numel(G)
    A{i} = nan(size(G{i}));
    A{i}(ok, :) = out{i};
end
ref = nan(size(G{1}));
ref(ok, :) = r;
end

function a = rot(s, t)
[u, ~, v] = svd((t' * s)');
a = s * (u * v');
end
