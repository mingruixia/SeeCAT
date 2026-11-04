function s = iqm_stats(data, w)
% IQM_STATS  MRIQC's summary statistics of DATA weighted by a probability map.
%   s = seecat.qc.iqm_stats(data, w)
%
% As mriqc.qc.anatomical.summary_stats: data rounded to integers and weights
% to 3 decimals; weighted mean and SD (statsmodels DescrStatsW, ddof 0) and
% weighted 5/50/95th percentiles (statsmodels' rule: the first value whose
% cumulative weight reaches the target, the midpoint on an exact tie);
% kurtosis (Fisher) and MAD (median absolute deviation from the weighted
% median, divided by 0.6745) of the voxels with w > half its maximum;
% n = sum of the weights. All but n are rounded to 4 decimals, as MRIQC.
w0 = double(w(:));
x = round(double(data(:)));
w = round(w0 * 1000) / 1000;
keep = w ~= 0;
xs = x(keep);
ws = w(keep);
W = sum(ws);
s.mean = sum(ws .* xs) / W;
s.stdv = sqrt(sum(ws .* (xs - s.mean) .^ 2) / W);
[v, ~, g] = unique(xs);                           % sorted values, summed weights
cw = cumsum(accumarray(g, ws));
q = zeros(1, 3);
p = [0.05 0.5 0.95];
for i = 1:3
    t = p(i) * cw(end);
    k = find(cw >= t, 1);
    if isempty(k), k = numel(cw); end
    q(i) = v(k);
    if abs(t - cw(k)) < 1e-10 && k < numel(cw)
        q(i) = (v(k) + v(k + 1)) / 2;
    end
end
s.p05 = q(1);
s.median = q(2);
s.p95 = q(3);
th = double(data(:));
th = th(w0 > 0.5 * max(w0));                      % weights before rounding, as MRIQC
m = mean(th);
s.k = mean((th - m) .^ 4) / mean((th - m) .^ 2) ^ 2 - 3;
s.mad = median(abs(th - s.median)) / 0.6744897501960817;
s.n = sum(w0);
for f = {'mean', 'median', 'p95', 'p05', 'k', 'stdv', 'mad'}   % MRIQC rounds to 4 decimals
    s.(f{1}) = round(s.(f{1}), 4);
end
end
