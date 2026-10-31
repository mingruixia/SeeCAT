function img = carpet(Y, groups, opt)
% CARPET  Carpet plot (Power 2017) as a grayscale image.
%   img = seecat.qc.carpet(Y, groups)
%
% Y is T x V (frames x voxels), GROUPS a V x 1 index (1 GM, 2 WM, 3 CSF, or
% all 1); rows are ordered by group, separated by a white line. Each voxel
% is detrended (linear) and z-scored on the kept frames (OPT.keep, T x 1
% logical; default all); values are shown from -2 to 2, and frames not kept
% are tinted red. Rows are averaged in bins so the image is at most
% OPT.rows high (default 600); each frame is OPT.width pixels wide
% (default 2). IMG is RGB.

if nargin < 3
    opt = struct();
end
maxRows = 600;
w = 2;
if isfield(opt, 'rows'), maxRows = opt.rows; end
if isfield(opt, 'width'), w = opt.width; end
T = size(Y, 1);
keep = true(T, 1);
if isfield(opt, 'keep') && ~isempty(opt.keep)
    keep = logical(opt.keep(:));
end
Y = double(Y);
t = [ones(T, 1), linspace(-1, 1, T)'];
Y = Y - t * (t(keep, :) \ Y(keep, :));
sd = std(Y(keep, :), 0, 1);
Y = Y ./ sd;
Y(:, ~(sd > 0)) = 0;
G = unique(groups(:))';
share = arrayfun(@(g) nnz(groups == g), G) / numel(groups);
parts = {};
for k = 1:numel(G)
    y = Y(:, groups == G(k))';
    nr = max(1, round(share(k) * maxRows));
    bins = min(nr, size(y, 1));
    edges = round(linspace(0, size(y, 1), bins + 1));
    b = zeros(bins, T);
    for i = 1:bins
        b(i, :) = mean(y(edges(i) + 1:edges(i + 1), :), 1);
    end
    b = b / max(std(reshape(b(:, keep), [], 1)), eps);
    parts{end+1} = b; %#ok<AGROW>
    if k < numel(G)
        parts{end+1} = 2 * ones(2, T); %#ok<AGROW>
    end
end
c = cat(1, parts{:});
g = (min(max(c, -2), 2) + 2) / 4;
img = repmat(g, 1, 1, 3);
sep = all(c == 2, 2);                               % separator rows stay white
drop = repmat(~keep', size(g, 1), 1) & ~sep;
r = img(:, :, 1); gc = img(:, :, 2); bc = img(:, :, 3);
r(drop) = 0.55 * r(drop) + 0.45;
gc(drop) = 0.55 * gc(drop);
bc(drop) = 0.55 * bc(drop);
img = cat(3, r, gc, bc);
img = repelem(img, 1, w);
end
