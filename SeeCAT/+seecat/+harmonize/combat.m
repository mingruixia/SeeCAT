function [Yh, est] = combat(Y, batch, mod, opt)
% COMBAT  Remove site (batch) effects from features, keeping covariate effects.
%   Yh = seecat.harmonize.combat(Y, batch)
%   [Yh, est] = seecat.harmonize.combat(Y, batch, mod, opt)
%
% Y is n x V (one row per map, one column per voxel), BATCH n x 1 (site of
% each row: numbers, text or a cellstr), MOD n x p covariates whose effects
% are kept (no intercept; e.g. group dummies, age), or []. OPT fields
% (defaults in brackets):
%   eb          empirical Bayes shrinkage of the site estimates [true]
%   parametric  parametric priors (Johnson et al. 2007) or non-parametric
%               (Monte-Carlo integration over the other features) [true]
%   mean_only   adjust the site means only, not the variances [false]
%   ref         a site whose data are left unchanged; the others are
%               mapped onto it (M-ComBat style) [none]
%   np_features non-parametric only: at most this many other features
%               form the prior of a feature (a fixed random subset) [5000]
%
% The model and estimates follow neuroCombat (Fortin et al. 2017, 2018):
% per feature Y = site + MOD * beta + error, the error scaled per site;
% data are standardised by the pooled variance, site location (gamma) and
% scale (delta) are estimated per feature and shrunk across features
% (EB), then removed. EST holds gamma_star, delta_star (sites x V),
% var_pooled, stand_mean, mod_mean and the site levels.

if nargin < 3, mod = []; end
if nargin < 4, opt = struct(); end
def = struct('eb', true, 'parametric', true, 'mean_only', false, 'ref', [], 'np_features', 5000);
for f = fieldnames(def)'
    if ~isfield(opt, f{1}), opt.(f{1}) = def.(f{1}); end
end
Y = double(Y);
[n, V] = size(Y);
[lv, ~, b] = unique(cellstr(string(batch)), 'sorted');
nb = numel(lv);
if nb < 2
    error('SeeCAT:harmonize', 'Only one site; nothing to harmonise.');
end
Xb = double(b == 1:nb);
refLevel = [];
if ~isempty(opt.ref)
    refLevel = find(strcmp(lv, char(string(opt.ref))));
    if isempty(refLevel)
        error('SeeCAT:harmonize', 'Reference site "%s" is not among the sites.', char(string(opt.ref)));
    end
    Xb(:, refLevel) = 1;                          % as neuroCombat
end
counts = accumarray(b, 1, [nb 1]);
if any(counts < 2)
    error('SeeCAT:harmonize', 'Site %s has fewer than 2 maps.', strjoin(lv(counts < 2), ', '));
end
X = [Xb, double(mod)];
if rank(X) < size(X, 2)
    error('SeeCAT:harmonize', 'Sites and covariates are collinear (e.g. a covariate constant within sites).');
end

% standardise across features
B = X \ Y;                                        % p x V
if isempty(refLevel)
    grand = (counts' / n) * B(1:nb, :);
else
    grand = B(refLevel, :);
end
stand = repmat(grand, n, 1);
if isempty(refLevel)
    vp = mean((Y - X * B) .^ 2, 1);
else
    r = b == refLevel;
    vp = mean((Y(r, :) - X(r, :) * B) .^ 2, 1);
end
vp(vp == 0) = median(vp(vp ~= 0));
tmp = X;
tmp(:, 1:nb) = 0;
modMean = tmp * B;
s = (Y - stand - modMean) ./ sqrt(vp);

% site location and scale per feature
gh = (Xb' * Xb) \ (Xb' * s);                      % nb x V
dh = ones(nb, V);
if ~opt.mean_only
    for i = 1:nb
        dh(i, :) = var(s(b == i, :), 0, 1);
    end
end
dh(dh == 0) = 1;
gbar = mean(gh, 2);
t2 = var(gh, 0, 2);

gs = gh;
ds = dh;
if opt.eb
    for i = 1:nb
        si = s(b == i, :);
        if opt.parametric
            if opt.mean_only
                gs(i, :) = (t2(i) * gh(i, :) + gbar(i)) / (t2(i) + 1);     % postmean with n = 1, d = 1
            else
                m = mean(dh(i, :));
                v2 = var(dh(i, :));
                a = (2 * v2 + m ^ 2) / v2;
                bb = (m * v2 + m ^ 3) / v2;
                [gs(i, :), ds(i, :)] = itSol(si, gh(i, :), dh(i, :), gbar(i), t2(i), a, bb);
            end
        else
            [gs(i, :), ds(i, :)] = intEprior(si, gh(i, :), dh(i, :), opt.np_features);
        end
    end
end
if ~isempty(refLevel)
    gs(refLevel, :) = 0;
    ds(refLevel, :) = 1;
end
if opt.mean_only
    ds(:) = 1;
end

% adjust
Yh = s;
for i = 1:nb
    k = b == i;
    Yh(k, :) = (s(k, :) - Xb(k, :) * gs) ./ sqrt(ds(i, :));
end
Yh = Yh .* sqrt(vp) + stand + modMean;
if ~isempty(refLevel)
    Yh(b == refLevel, :) = Y(b == refLevel, :);
end
est = struct('sites', {lv}, 'gamma_star', gs, 'delta_star', ds, 'gamma_hat', gh, 'delta_hat', dh, ...
    'var_pooled', vp, 'stand_mean', grand, 'mod_mean', modMean, 'beta', B);
end

function [g, d] = itSol(sd, gh, dh, gbar, t2, a, b)
% Parametric EB: iterate the posterior means of gamma and delta
n = size(sd, 1);
gOld = gh;
dOld = dh;
change = 1;
while change > 1e-4
    g = (t2 * n * gh + dOld * gbar) ./ (t2 * n + dOld);
    sum2 = sum((sd - g) .^ 2, 1);
    d = (0.5 * sum2 + b) / (n / 2 + a - 1);
    change = max(max(abs(g - gOld) ./ abs(gOld)), max(abs(d - dOld) ./ abs(dOld)));
    gOld = g;
    dOld = d;
end
end

function [g, d] = intEprior(sd, gh, dh, maxF)
% Non-parametric EB: posterior means over the other features' estimates,
% weighted by the likelihood of this feature's data (log-sum-exp for
% stability; neuroCombat's direct product underflows for large n)
[n, V] = size(sd);
others = 1:V;
rs = RandStream('mt19937ar', 'Seed', 0);
if V - 1 > maxF
    others = sort(randperm(rs, V, maxF + 1));
end
G = gh(others);
D = dh(others);
g = zeros(1, V);
d = zeros(1, V);
for j = 1:V
    use = others ~= j;
    gj = G(use);
    dj = D(use);
    x = sd(:, j);
    sum2 = sum(x .^ 2) - 2 * sum(x) * gj + n * gj .^ 2;           % sum((x - g)^2) for each g
    logLH = -n / 2 * log(2 * pi * dj) - sum2 ./ (2 * dj);
    w = exp(logLH - max(logLH));
    g(j) = sum(gj .* w) / sum(w);
    d(j) = sum(dj .* w) / sum(w);
end
end
