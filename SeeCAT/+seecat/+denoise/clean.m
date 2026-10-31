function [E, info] = clean(Y, R, opt)
% CLEAN  Detrend, regress out confounds and band-pass in one model.
%   [E, info] = seecat.denoise.clean(Y, R, opt)
%
% Y is T x V (time series in columns), R is T x k confound regressors.
% OPT fields:
%   tr             repetition time (s)
%   detrend_order  polynomial order (0 = mean only)
%   band           [low high] in Hz, or [] for no filter
%   bad            T x 1 logical, frames flagged for censoring (or empty)
%   interp         'spline' or 'spectral' (fitted up to the low-pass edge)
%
% Order of operations (Doc/design/batch-api.md, 5.2):
%   1. flagged frames of Y and of every regressor are replaced by
%      interpolation from good frames;
%   2. Y and the regressors (with the trends) are band-passed with the same
%      filter;
%   3. the model is fitted on good frames only; residuals are returned for
%      every frame.
% E has the class of Y and zero mean over good frames. INFO has the rank
% of the model, the number of good frames and the degrees of freedom left.

T = size(Y, 1);
bad = false(T, 1);
if isfield(opt, 'bad') && ~isempty(opt.bad)
    bad = logical(opt.bad(:));
end
good = ~bad;
R = double(R);
sd = std(R, 0, 1);
R = (R(:, sd > 0) - mean(R(:, sd > 0), 1)) ./ sd(sd > 0);   % scale does not change the fit
fmax = [];
if ~isempty(opt.band) && opt.band(2) > 0
    fmax = opt.band(2);
end
if any(bad)
    R = seecat.denoise.interpolate(R, bad, opt.tr, opt.interp, fmax);
end
X = [seecat.denoise.poly_trend(T, opt.detrend_order), R];
filtering = ~isempty(opt.band);
if filtering
    X = seecat.denoise.bandpass(X, opt.tr, opt.band);
end
X = [ones(T, 1), X(:, any(abs(X) > 1e-10, 1))];   % filtering turns the constant into 0
k = rank(X(good, :));
% With few residual degrees of freedom every voxel's residual has nearly the
% same shape and all correlations go to +-1 (ds000030 sub-50052: 29 good
% frames, 28 regressors, every seed correlation 1.00), so refuse.
minDof = 10;
if nnz(good) - k < minDof
    error('SeeCAT:denoise', ['%d good frames and %d regressors leave %d degrees of freedom ' ...
        '(at least %d needed). Exclude this run, or use fewer regressors.'], ...
        nnz(good), k, nnz(good) - k, minDof);
end
pX = pinv(X(good, :));

E = zeros(size(Y), 'like', Y);
block = 5000;
for v0 = 1:block:size(Y, 2)
    v = v0:min(v0 + block - 1, size(Y, 2));
    y = double(Y(:, v));
    if any(bad)
        y = seecat.denoise.interpolate(y, bad, opt.tr, opt.interp, fmax);
    end
    if filtering
        y = seecat.denoise.bandpass(y, opt.tr, opt.band);
    end
    e = y - X * (pX * y(good, :));
    E(:, v) = cast(e - mean(e(good, :), 1), 'like', Y);
end
info = struct('n_regressors', k, 'n_good', nnz(good), 'dof', nnz(good) - k);
end
