function s = svg_lines(x, Y, opt)
% SVG_LINES  A small inline SVG line chart (no MATLAB figures needed).
%   s = seecat.qc.svg_lines(x, Y, opt)
%
% X is 1 x T, Y is K x T (one series per row; NaN breaks a line). OPT:
%   names     1 x K labels (legend)
%   colors    1 x K CSS colours
%   ylabel    axis label
%   hline     y value of a dashed reference line (e.g. FD threshold), or []
%   shade     1 x T logical: frames shaded in the background (censored)
%   width, height   pixels (default 900 x 160)
% Returns the SVG element as text.

W = field(opt, 'width', 900);
H = field(opt, 'height', 160);
names = field(opt, 'names', {});
colors = field(opt, 'colors', {'#3b6fb6', '#d1495b', '#2a9d8f', '#e9a03b', '#7b5ea7', '#6c757d'});
padL = 56; padR = 12; padT = 10; padB = 24;
pw = W - padL - padR;
ph = H - padT - padB;
yv = Y(isfinite(Y));
if isempty(yv), yv = [0 1]; end
y0 = min(yv);
y1 = max(yv);
if isfield(opt, 'hline') && ~isempty(opt.hline)
    y0 = min(y0, opt.hline);
    y1 = max(y1, opt.hline);
end
if y1 <= y0, y1 = y0 + 1; end
y1 = y1 + 0.05 * (y1 - y0);
X = @(v) padL + (v - x(1)) / max(x(end) - x(1), eps) * pw;
Yp = @(v) padT + (1 - (v - y0) / (y1 - y0)) * ph;
b = sprintf('<svg viewBox="0 0 %d %d" width="100%%" role="img" xmlns="http://www.w3.org/2000/svg" class="chart">', W, H);
if isfield(opt, 'shade') && any(opt.shade)
    dx = pw / max(numel(x) - 1, 1);
    for i = find(opt.shade(:)')
        b = [b sprintf('<rect x="%.1f" y="%d" width="%.1f" height="%d" class="shade"/>', X(x(i)) - dx / 2, padT, dx, ph)]; %#ok<AGROW>
    end
end
b = [b sprintf('<line x1="%d" y1="%d" x2="%d" y2="%d" class="axis"/>', padL, padT + ph, padL + pw, padT + ph)];
b = [b sprintf('<line x1="%d" y1="%d" x2="%d" y2="%d" class="axis"/>', padL, padT, padL, padT + ph)];
for v = [y0, (y0 + y1) / 2, y1]
    b = [b sprintf('<text x="%d" y="%.1f" class="tick" text-anchor="end">%s</text>', padL - 4, Yp(v) + 4, num(v))]; %#ok<AGROW>
end
b = [b sprintf('<text x="%d" y="%d" class="tick">%s</text>', padL, H - 6, num(x(1)))];
b = [b sprintf('<text x="%d" y="%d" class="tick" text-anchor="end">%s</text>', padL + pw, H - 6, num(x(end)))];
if isfield(opt, 'ylabel')
    b = [b sprintf('<text x="12" y="%.1f" class="label" transform="rotate(-90 12 %.1f)" text-anchor="middle">%s</text>', ...
        padT + ph / 2, padT + ph / 2, opt.ylabel)];
end
if isfield(opt, 'hline') && ~isempty(opt.hline)
    b = [b sprintf('<line x1="%d" y1="%.1f" x2="%d" y2="%.1f" class="ref"/>', padL, Yp(opt.hline), padL + pw, Yp(opt.hline))];
end
for k = 1:size(Y, 1)
    seg = isfinite(Y(k, :));
    d = '';
    pen = false;
    for i = 1:numel(x)
        if seg(i)
            d = [d sprintf('%s%.1f %.1f ', ternary(pen, 'L', 'M'), X(x(i)), Yp(Y(k, i)))]; %#ok<AGROW>
            pen = true;
        else
            pen = false;
        end
    end
    b = [b sprintf('<path d="%s" fill="none" stroke="%s" stroke-width="1.3"/>', d, colors{mod(k - 1, numel(colors)) + 1})]; %#ok<AGROW>
end
for k = 1:numel(names)
    b = [b sprintf('<text x="%d" y="%d" class="legend" fill="%s">%s</text>', padL + 8 + 110 * (k - 1), padT + 12, ...
        colors{mod(k - 1, numel(colors)) + 1}, names{k})]; %#ok<AGROW>
end
s = [b '</svg>'];
end

function t = num(v)
t = sprintf('%.3g', v);
end

function v = ternary(c, a, b)
if c, v = a; else, v = b; end
end

function v = field(s, k, d)
v = d;
if isfield(s, k)
    v = s.(k);
end
end
