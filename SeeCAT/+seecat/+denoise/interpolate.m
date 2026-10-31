function Y = interpolate(Y, bad, tr, method)
% INTERPOLATE  Replace flagged frames with values estimated from good frames.
%   Y = seecat.denoise.interpolate(Y, bad, tr, 'spline')
%   Y = seecat.denoise.interpolate(Y, bad, tr, 'lombscargle')
%
% Y is T x V (columns are time series), BAD a T x 1 logical, TR in seconds.
%   spline       cubic spline through the good frames; flagged frames
%                before the first or after the last good frame take the
%                nearest good value (a spline would extrapolate wildly).
%   lombscargle  least-squares spectral fit to the good frames, evaluated
%                at the flagged frames (Power et al. 2014; oversampling 8,
%                frequencies up to the Nyquist rate of the good frames).
% Good frames are never changed.

bad = logical(bad(:));
if ~any(bad)
    return
end
good = ~bad;
if nnz(good) < 4
    error('SeeCAT:denoise', 'Only %d good frames; cannot interpolate.', nnz(good));
end
t = (0:numel(bad) - 1)' * tr;
cls = class(Y);
switch method
    case 'spline'
        tg = t(good);
        inner = bad & t > tg(1) & t < tg(end);
        if any(inner)
            Y(inner, :) = cast(interp1(tg, double(Y(good, :)), t(inner), 'spline'), cls);
        end
        first = find(good, 1);
        last = find(good, 1, 'last');
        Y(1:first - 1, :) = repmat(Y(first, :), first - 1, 1);
        Y(last + 1:end, :) = repmat(Y(last, :), numel(bad) - last, 1);
    case 'lombscargle'
        Y(bad, :) = cast(lombScargle(double(Y(good, :)), t(good), t(bad)), cls);
    otherwise
        error('SeeCAT:denoise', 'Unknown interpolation method "%s".', method);
end
end

function yb = lombScargle(h, tg, tb)
% Fit sinusoids at each frequency to the good frames (the offset tau makes
% the sine and cosine terms orthogonal), then sum them at the flagged times.
ofac = 8;
hifac = 1;
N = numel(tg);
span = tg(end) - tg(1);
f = (1 / (span * ofac):1 / (span * ofac):hifac * N / (2 * span))';
w = 2 * pi * f;
mu = mean(h, 1);
sd = std(h, 0, 1);
h = h - mu;
tau = atan2(sum(sin(2 * w * tg'), 2), sum(cos(2 * w * tg'), 2)) ./ (2 * w);
Cg = cos(w .* (tg' - tau));                     % nf x N
Sg = sin(w .* (tg' - tau));
c = (Cg * h) ./ sum(Cg .^ 2, 2);                % nf x V
s = (Sg * h) ./ sum(Sg .^ 2, 2);
fitGood = Cg' * c + Sg' * s;                    % N x V
yb = cos(w .* (tb' - tau))' * c + sin(w .* (tb' - tau))' * s;
% Oversampling inflates the amplitude; scale to the spread of the data
scale = sd ./ std(fitGood, 0, 1);
scale(~isfinite(scale)) = 0;
yb = yb .* scale + mu;
end
