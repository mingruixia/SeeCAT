function G = glm(Y, X, con, opt)
% GLM  Fit a linear model to every voxel and compute T/F contrasts.
%   G = seecat.stat.glm(Y, X, con)
%   G = seecat.stat.glm(Y, X, con, struct('V', V, 'Ximg', Ximg))
%
% Y    n x nVox data (one row per map)
% X    n x p design
% CON  struct array: name, type ('t' or 'F'), weights (k x p, k = 1 for T)
% OPT  V     n x n error covariance (from seecat.stat.reml; default I).
%            Data and design are whitened with W = V^(-1/2), with the small
%            entries of W set to 0 as in spm_spm, and the df follow SPM's
%            Satterthwaite approximation (trRV, trMV), so they can be
%            fractional.
%      Ximg  n x nVox x q image covariates: appended to X as columns p+1..p+q,
%            different at each voxel (CON weights then have p+q columns).
%
% G fields:
%   beta     (p[+q]) x nVox
%   res      n x nVox whitened residuals
%   ResSS    1 x nVox
%   trRV, trRVRV, erdf   residual traces and effective df
%   con(k)   name, type, weights, df ([1 erdf] or [df1 erdf]), stat (T or F),
%            effect (T only: c * beta), p (upper tail), z (same p)
% Estimability of each contrast is checked; an error names the contrast.

if nargin < 4
    opt = struct();
end
[n, nVox] = size(Y);
Y = double(Y);
X = double(X);
if isfield(opt, 'V') && ~isempty(opt.V)
    W = sqrtm(inv(opt.V));
    W = real(W) .* (abs(W) > 1e-6);           % as spm_spm
    Vw = W * opt.V * W';
else
    W = eye(n);
    Vw = eye(n);
end
hasImg = isfield(opt, 'Ximg') && ~isempty(opt.Ximg);

if ~hasImg
    KX = W * X;
    pKX = pinv(KX);
    KWY = W * Y;
    beta = pKX * KWY;
    res = KWY - KX * beta;
    [trRV, trRVRV] = traces(KX, Vw);
    G = struct('beta', beta, 'res', res, 'ResSS', sum(res .^ 2, 1), ...
        'trRV', trRV, 'trRVRV', trRVRV, 'erdf', trRV ^ 2 / trRVRV);
    ResMS = G.ResSS / trRV;
    for k = 1:numel(con)
        G.con(k) = contrast(con(k), KX, pKX, beta, KWY, ResMS, Vw, G.erdf); %#ok<AGROW>
    end
    return
end

% Image covariates: one design per voxel, solved voxel by voxel
q = size(opt.Ximg, 3);
p = size(X, 2) + q;
beta = zeros(p, nVox);
res = zeros(n, nVox);
stat = zeros(numel(con), nVox);
effect = zeros(numel(con), nVox);
df1 = zeros(numel(con), 1);
for v = 1:nVox
    Xv = [X, reshape(opt.Ximg(:, v, :), n, q)];
    KX = W * Xv;
    pKX = pinv(KX);
    KWY = W * Y(:, v);
    b = pKX * KWY;
    r = KWY - KX * b;
    if v == 1
        [trRV, trRVRV] = traces(KX, Vw);
        erdf = trRV ^ 2 / trRVRV;
    end
    beta(:, v) = b;
    res(:, v) = r;
    ResMS = sum(r .^ 2) / trRV;
    for k = 1:numel(con)
        c = contrast(con(k), KX, pKX, b, KWY, ResMS, Vw, erdf);
        stat(k, v) = c.stat;
        effect(k, v) = c.effect;
        df1(k) = c.df(1);
    end
end
G = struct('beta', beta, 'res', res, 'ResSS', sum(res .^ 2, 1), ...
    'trRV', trRV, 'trRVRV', trRVRV, 'erdf', erdf);
for k = 1:numel(con)
    c = con(k);
    G.con(k) = finish(c.name, c.type, c.weights, [df1(k) erdf], stat(k, :), effect(k, :)); %#ok<AGROW>
end
end

function c = contrast(def, KX, pKX, beta, KWY, ResMS, Vw, erdf)
w = double(def.weights);
if size(w, 2) ~= size(KX, 2)
    error('SeeCAT:stat', 'Contrast %s has %d weights; the design has %d columns.', def.name, size(w, 2), size(KX, 2));
end
% Estimable: the weights lie in the row space of the design
if norm(w - w * pinv(KX) * KX, 'fro') > 1e-6 * max(1, norm(w, 'fro'))
    error('SeeCAT:stat', 'Contrast %s is not estimable with this design.', def.name);
end
if strcmpi(def.type, 't')
    Bcov = pKX * Vw * pKX';
    eff = w * beta;
    stat = eff ./ sqrt(ResMS * (w * Bcov * w'));
    df = [1 erdf];
else
    % Extra sum of squares of the contrast's subspace of the design
    X1 = KX * pinv(KX' * KX) * w';
    M = X1 * pinv(X1);
    ESS = sum((M * KWY) .^ 2, 1);
    trMV = trace(M * Vw);
    trMVMV = trace(M * Vw * M * Vw);
    stat = (ESS / trMV) ./ ResMS;
    eff = nan(1, size(beta, 2));
    df = [trMV ^ 2 / trMVMV, erdf];
end
c = finish(def.name, def.type, w, df, stat, eff);
end

function c = finish(name, type, w, df, stat, eff)
stat(~isfinite(stat)) = 0;
if strcmpi(type, 't')
    p = 1 - spm_Tcdf(stat, df(2));
    pos = stat > 0;
    if any(pos)
        p(pos) = spm_Tcdf(-stat(pos), df(2));        % precise upper tail
    end
else
    p = 1 - spm_Fcdf(stat, df);
end
p = max(p, realmin);
z = -spm_invNcdf(p);
c = struct('name', name, 'type', lower(type), 'weights', w, 'df', df, ...
    'stat', stat, 'effect', eff, 'p', p, 'z', z);
end

function [trRV, trRVRV] = traces(KX, Vw)
R = eye(size(KX, 1)) - KX * pinv(KX);
RV = R * Vw;
trRV = trace(RV);
trRVRV = sum(sum(RV .* RV'));
end
