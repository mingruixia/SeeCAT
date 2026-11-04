function [G, lambda] = embed(R, opt)
% EMBED  Connectivity gradients of one connectivity matrix (diffusion map embedding).
%   [G, lambda] = seecat.gradient.embed(R)
%   [G, lambda] = seecat.gradient.embed(R, struct('n_components', 10, 'sparsity', 0.9, ...
%       'kernel', 'normalized_angle', 'alpha', 0.5))
%
% R is a V x V connectivity matrix (e.g. Pearson r between nodes). The steps
% and defaults are those of BrainSpace (Vos de Wael et al. 2020), after
% Margulies et al. (2016):
%   1. Each row keeps its largest (1 - sparsity) share of values (default
%      the top 10 %); the rest is set to 0.
%   2. Affinity between rows: 'normalized_angle' (1 - angle / pi of the
%      cosine similarity; default), 'cosine' (negative values set to 0) or
%      'none' (the sparsified matrix, symmetrised).
%   3. Diffusion map embedding with alpha (0.5; Coifman & Lafon 2006) and
%      diffusion time 0: eigenvalues l scaled as l / (1 - l).
% G is V x n_components (component k in column k, scaled by its lambda), LAMBDA
% the n_components eigenvalues (scaled). The sign of each component is set so
% that its largest absolute value is positive. Rows of R that are all 0 or
% not finite are left out and get NaN.
%
% Memory: R and two more V x V matrices, in double precision up to 8000
% nodes and in single precision above (BrainSpace uses double; single
% changes gradients by about 1e-3 of their range).

def = struct('n_components', 10, 'sparsity', 0.9, 'kernel', 'normalized_angle', 'alpha', 0.5);
if nargin < 2, opt = struct(); end
for f = fieldnames(def)'
    if ~isfield(opt, f{1}) || isempty(opt.(f{1})), opt.(f{1}) = def.(f{1}); end
end
V = size(R, 1);
cls = 'double';
if V > 8000
    cls = 'single';
end
R = cast(R, cls);
R(~isfinite(R)) = 0;
ok = any(R ~= 0, 2);
R = R(ok, ok);
n = size(R, 1);
k = opt.n_components;
if n <= k + 1
    error('SeeCAT:gradient', 'Only %d nodes; need more than %d.', n, k + 1);
end

% 1. row-wise sparsification: keep values >= the row's top (1 - sparsity) cut
keep = max(1, floor((1 - opt.sparsity) * n));    % as BrainSpace: exactly this many per row (1 - 0.9 is
                                                  % 0.0999..., so 120 nodes keep 11, not 12)
B = 2000;
for r0 = 1:B:n
    r = r0:min(r0 + B - 1, n);
    [top, col] = maxk(R(r, :), keep, 2);
    S = zeros(numel(r), n, cls);
    S(sub2ind(size(S), repmat((1:numel(r))', 1, keep), col)) = top;
    R(r, :) = S;
end

% 2. affinity
switch opt.kernel
    case {'normalized_angle', 'cosine'}
        nr = sqrt(sum(R .^ 2, 2));
        nr(nr == 0) = 1;
        R = R ./ nr;
        A = R * R';                               % cosine similarity
        clear R
        A = min(max(A, -1), 1);
        if strcmp(opt.kernel, 'normalized_angle')
            A = 1 - acos(A) / pi;
        else
            A(A < 0) = 0;
        end
    case 'none'
        A = (R + R') / 2;
        A(A < 0) = 0;
        clear R
    otherwise
        error('SeeCAT:gradient', 'Unknown kernel "%s".', opt.kernel);
end
A = (A + A') / 2;                                 % exact symmetry for eigs

% 3. diffusion maps (BrainSpace diffusion_mapping)
d = sum(A, 2);
if opt.alpha > 0
    d = d .^ -opt.alpha;
    A = A .* d .* d';
end
d = sum(A, 2) .^ -0.5;
A = A .* d .* d';
[U, L] = eigs(@(x) double(A * cast(x, cls)), n, k + 1, 'largestreal', 'IsFunctionSymmetric', true, ...
    'Tolerance', 1e-10, 'MaxIterations', 1000);
[l, o] = sort(real(diag(L)), 'descend');
U = real(U(:, o));
psi = U ./ U(:, 1);
lambda = l(2:end) ./ (1 - l(2:end));
E = psi(:, 2:end) .* lambda';
[~, im] = max(abs(E), [], 1);
s = sign(E(sub2ind(size(E), im, 1:k)));
s(s == 0) = 1;
E = E .* s;
G = nan(V, k);
G(ok, :) = E;
lambda = lambda(:)';
end
