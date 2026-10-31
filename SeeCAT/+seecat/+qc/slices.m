function rgb = slices(vol, hdr, overlays, opt)
% SLICES  Montage of axial, coronal and sagittal slices as an RGB image.
%   rgb = seecat.qc.slices(vol, hdr, overlays)
%   rgb = seecat.qc.slices(vol, hdr, overlays, struct('n', 5, 'scale', 3))
%
% VOL is a 3D image (e.g. the mean BOLD), HDR its header (for orientation).
% OVERLAYS is a struct array with mask (3D logical, same grid), color
% ([r g b] in 0..1), style ('edge' or 'fill') and alpha (fill only).
% Rows: axial, coronal, sagittal; N slices each, spread over the volume's
% non-zero extent. Shown in neurological convention (left on the left,
% anterior and superior up), each pixel enlarged SCALE times.

if nargin < 3
    overlays = struct('mask', {}, 'color', {}, 'style', {}, 'alpha', {});
end
if nargin < 4
    opt = struct();
end
n = field(opt, 'n', 5);
sc = field(opt, 'scale', 3);
% Reorient to world-aligned index order: x left->right, y post->ant, z inf->sup
mirror = diag(hdr.mat(1:3, 1:3)) < 0;
vol = reorient(vol, mirror);
for k = 1:numel(overlays)
    overlays(k).mask = reorient(overlays(k).mask, mirror);
end
nz = vol ~= 0 & isfinite(vol);
v = sort(vol(nz));
lim = v(max(1, round([0.01 0.99] * numel(v))))';
g = min(max((vol - lim(1)) / max(diff(lim), eps), 0), 1);
g(~isfinite(g)) = 0;

rows = cell(3, 1);
for ax = 3:-1:1                                  % axial, coronal, sagittal
    ext = find(any(any(nz, otherDims(ax, 1)), otherDims(ax, 2)));
    pos = round(linspace(ext(1) + 0.2 * numel(ext), ext(end) - 0.2 * numel(ext), n));
    tiles = cell(1, n);
    for i = 1:n
        img = repmat(cut(g, ax, pos(i)), 1, 1, 3);
        for k = 1:numel(overlays)
            m = cut(overlays(k).mask, ax, pos(i)) > 0;
            if strcmp(overlays(k).style, 'edge')
                m = m & ~erode2(m);
                a = 1;
            else
                a = overlays(k).alpha;
            end
            for c = 1:3
                ch = img(:, :, c);
                ch(m) = (1 - a) * ch(m) + a * overlays(k).color(c);
                img(:, :, c) = ch;
            end
        end
        tiles{i} = repelem(img, sc, sc);
    end
    rows{4 - ax} = cat(2, tiles{:});
end
w = max(cellfun(@(r) size(r, 2), rows));
for r = 1:3
    rows{r}(:, end+1:w, :) = 0;
end
rgb = cat(1, rows{:});
end

function v = reorient(v, mirror)
for d = 1:3
    if mirror(d)
        v = flip(v, d);
    end
end
end

function d = otherDims(ax, k)
o = setdiff(1:3, ax);
d = o(k);
end

function s = cut(v, ax, p)
% 2D slice with superior/anterior up and left on the left
switch ax
    case 3
        s = rot90(v(:, :, p));                   % x across, y up
    case 2
        s = rot90(squeeze(v(:, p, :)));          % x across, z up
    case 1
        s = rot90(squeeze(v(p, :, :)));          % y across, z up
end
end

function e = erode2(m)
e = m;
e(2:end, :) = e(2:end, :) & m(1:end-1, :);
e(1:end-1, :) = e(1:end-1, :) & m(2:end, :);
e(:, 2:end) = e(:, 2:end) & m(:, 1:end-1);
e(:, 1:end-1) = e(:, 1:end-1) & m(:, 2:end);
end

function v = field(s, k, d)
v = d;
if isfield(s, k)
    v = s.(k);
end
end
