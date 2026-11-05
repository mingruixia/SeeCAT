function [Yh, info] = covbat(Y, batch, mod, opt)
% COVBAT  ComBat, then harmonisation of the covariance between features.
%   [Yh, info] = seecat.harmonize.covbat(Y, batch, mod)
%   [Yh, info] = seecat.harmonize.covbat(Y, batch, mod, struct('pct_var', 0.95))
%
% Chen et al. (2022, Human Brain Mapping): after ComBat
% (seecat.harmonize.combat, parametric EB), the residuals (data minus the
% site-free mean and covariate effects) are standardised per feature and
% decomposed by PCA; the scores of the components that explain PCT_VAR of
% the variance are themselves harmonised across sites with ComBat (no
% covariates), and the residuals are rebuilt. Site differences in how
% features co-vary (e.g. network structure) are removed as well as
% differences in their means and variances. OPT also passes eb, parametric
% and ref to the ComBat steps: with a reference site, the component scores
% of the other sites are mapped onto the reference site's too, so its data
% stay unchanged. INFO: components used, variance they explain.

if nargin < 3, mod = []; end
if nargin < 4, opt = struct(); end
if ~isfield(opt, 'pct_var'), opt.pct_var = 0.95; end
cb = rmfield(opt, intersect(fieldnames(opt), {'pct_var'}));
[Yc, est] = seecat.harmonize.combat(Y, batch, mod, cb);
mu = est.stand_mean + est.mod_mean;
E = Yc - mu;                                      % residuals after ComBat
sd = std(E, 0, 1);
sd(sd == 0) = 1;
Ez = E ./ sd;
[U, S, W] = svd(Ez - mean(Ez, 1), 'econ');
m = mean(Ez, 1);
ev = diag(S) .^ 2;
k = find(cumsum(ev) / sum(ev) >= opt.pct_var, 1);
scores = U * S;
sh = seecat.harmonize.combat(scores(:, 1:k), batch, [], cb);
Ez2 = m + sh * W(:, 1:k)' + scores(:, k+1:end) * W(:, k+1:end)';
Yh = Ez2 .* sd + mu;
if isfield(cb, 'ref') && ~isempty(cb.ref)          % exactly unchanged (not just up to rounding)
    r = strcmp(cellstr(string(batch)), char(string(cb.ref)));
    Yh(r, :) = Y(r, :);
end
if ~all(isfinite(Yh(:)))
    error('SeeCAT:harmonize', 'CovBat gave non-finite values; nothing is written.');
end
info = struct('components', k, 'variance_explained', sum(ev(1:k)) / sum(ev));
end
