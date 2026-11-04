function P = permutation(Y, X, con, mask, opt)
% PERMUTATION  TFCE with familywise error from permutations (max statistic).
%   P = seecat.stat.permutation(Y, X, con, mask, opt)
%
% Y is n x nVox (the voxels of the 3D logical MASK, in order), X the n x p
% design, CON the contrasts (name, type, weights, and stat: the observed
% statistic from seecat.stat.glm). OPT fields:
%   scheme   'flip' (sign flipping: one-sample designs), 'perm' (rows
%            exchanged: two-sample, ANOVA, regression) or 'within' (rows
%            exchanged within each block: paired, repeated measures)
%   blocks   n x 1 block of each row (for 'within', e.g. the subject)
%   n_perm   number of permutations, the unpermuted one included [5000]
%   E, H     TFCE extent and height exponents [0.5, 2]
%   V        n x n error covariance, as for seecat.stat.glm [I]
%   workers  parfor workers (0 = serial) [0]
%   seed     random seed [0]
%
% Freedman & Lane (1983), as FSL randomise and PALM: for each contrast the
% data are reduced to the residuals of the nuisance part of the design
% (the design's subspace orthogonal to the contrast), these are permuted
% (or sign flipped) and the full model is fitted again. With a covariance
% V everything is done on the whitened data and design. TFCE (seecat.stat.tfce,
% 26-connectivity, dh = max/100) is applied to the positive part of the
% T (or F) image of every permutation and the maximum is kept; a voxel's
% FWE p is the share of permutations whose maximum reaches its TFCE value.
% When fewer distinct permutations exist than asked (e.g. 2^n sign flips
% for a small one-sample test), all of them are used.
%
% P(k) fields: name, tfce (1 x nVox, observed), p_fwe (1 x nVox),
% n_perm (permutations used), scheme, max_null (n_perm x 1).

def = struct('scheme', 'perm', 'blocks', [], 'n_perm', 5000, 'E', 0.5, 'H', 2, ...
    'V', [], 'workers', 0, 'seed', 0);
for f = fieldnames(def)'
    if ~isfield(opt, f{1}) || isempty(opt.(f{1}))
        opt.(f{1}) = def.(f{1});
    end
end
[n, nVox] = size(Y);
if nVox ~= nnz(mask)
    error('SeeCAT:stat', 'Permutation: %d voxels, the mask has %d.', nVox, nnz(mask));
end
Y = double(Y);
X = double(X);
if ~isempty(opt.V)
    W = sqrtm(inv(opt.V));
    W = real(W) .* (abs(W) > 1e-6);           % as spm_spm and seecat.stat.glm
    Vw = W * opt.V * W';
else
    W = eye(n);
    Vw = eye(n);
end
KX = W * X;
pKX = pinv(KX);
KWY = W * Y;
R = eye(n) - KX * pKX;
trRV = trace(R * Vw);

% Fixed parts of each contrast's statistic and its nuisance residuals
K = numel(con);
C = cell(K, 1);
for k = 1:K
    w = double(con(k).weights);
    c.T = strcmpi(con(k).type, 't');
    c.w = w;
    if c.T
        c.den = w * (pKX * Vw * pKX') * w';
    else
        X1 = KX * pinv(KX' * KX) * w';
        c.M = X1 * pinv(X1);
        c.trMV = trace(c.M * Vw);
    end
    Z = KX * null(w);                          % nuisance: the design orthogonal to the contrast
    if isempty(Z)
        c.Rz = KWY;
    else
        c.Rz = KWY - Z * (pinv(Z) * KWY);
    end
    C{k} = c;
end

[idx, sgn] = draws(n, opt);
B = size(idx, 2);
maxNull = zeros(B, K);
obs = cell(K, 1);
for k = 1:K
    obs{k} = seecat.stat.tfce(onMask(con(k).stat, mask), opt.E, opt.H, 26);
    maxNull(1, k) = max(obs{k}(:));
end
E = opt.E;
H = opt.H;
parfor (b = 2:B, opt.workers)
    row = zeros(1, K);
    for k = 1:K
        c = C{k};
        Ys = c.Rz(idx(:, b), :) .* sgn(:, b);
        s = statistic(c, Ys, KX, pKX, trRV);
        t = seecat.stat.tfce(onMask(s, mask), E, H, 26);
        row(k) = max(t(:));
    end
    maxNull(b, :) = row;
end
P = struct('name', {}, 'tfce', {}, 'p_fwe', {}, 'n_perm', {}, 'scheme', {}, 'max_null', {});
for k = 1:K
    t = obs{k}(mask)';
    p = mean(maxNull(:, k) >= t, 1);           % the unpermuted maximum counts too
    P(k) = struct('name', con(k).name, 'tfce', t, 'p_fwe', p, 'n_perm', B, ...
        'scheme', opt.scheme, 'max_null', maxNull(:, k));
end
end

function s = statistic(c, Ys, KX, pKX, trRV)
beta = pKX * Ys;
ResMS = sum((Ys - KX * beta) .^ 2, 1) / trRV;
if c.T
    s = (c.w * beta) ./ sqrt(ResMS * c.den);
else
    s = (sum((c.M * Ys) .^ 2, 1) / c.trMV) ./ ResMS;
end
s(~isfinite(s)) = 0;
end

function [idx, sgn] = draws(n, opt)
% Column 1 is the unpermuted data; then OPT.n_perm - 1 random draws, or
% every distinct one when there are fewer
B = opt.n_perm;
rs = RandStream('mt19937ar', 'Seed', opt.seed);
switch opt.scheme
    case 'flip'
        if n < 31 && 2 ^ n <= B                % all sign patterns
            B = 2 ^ n;
            sgn = 1 - 2 * double(dec2bin(0:B - 1, n)' == '1');
        else
            sgn = [ones(n, 1), 1 - 2 * (rand(rs, n, B - 1) > 0.5)];
        end
        idx = repmat((1:n)', 1, B);
    case 'perm'
        if n <= 7 && factorial(n) <= B
            idx = flipud(perms(1:n))';
            B = size(idx, 2);
        else
            idx = zeros(n, B);
            idx(:, 1) = 1:n;
            for b = 2:B
                idx(:, b) = randperm(rs, n);
            end
        end
        sgn = ones(n, B);
    case 'within'
        [g, ~] = findgroups(opt.blocks(:));
        rows = accumarray(g, (1:n)', [], @(x) {x});
        two = all(cellfun(@numel, rows) == 2);
        nb = numel(rows);
        if two && nb < 31 && 2 ^ nb <= B       % all swaps within pairs
            B = 2 ^ nb;
            swap = dec2bin(0:B - 1, nb)' == '1';
            idx = repmat((1:n)', 1, B);
            for q = 1:nb
                r = rows{q};
                idx(r, swap(q, :)) = repmat(flipud(r), 1, nnz(swap(q, :)));
            end
        else
            idx = repmat((1:n)', 1, B);
            for b = 2:B
                for q = 1:nb
                    r = rows{q};
                    idx(r, b) = r(randperm(rs, numel(r)));
                end
            end
        end
        sgn = ones(n, B);
    otherwise
        error('SeeCAT:stat', 'Unknown permutation scheme "%s".', opt.scheme);
end
end

function v = onMask(x, mask)
v = zeros(size(mask));
v(mask) = x;
end
