function t = tfce(vol, E, H, conn, dh)
% TFCE  Threshold-free cluster enhancement of a statistic image.
%   t = seecat.stat.tfce(vol)                  % E = 0.5, H = 2, 26-connectivity
%   t = seecat.stat.tfce(vol, E, H, conn, dh)
%
% Smith & Nichols (2009), as fslmaths -tfce: for heights h = dh, 2dh, ...
% up to the maximum of VOL, every voxel at or above h gets
% e(h)^E * h^H * dh added, e(h) being the size (voxels) of its cluster at
% that height. Only positive values are enhanced; other voxels get 0. DH
% defaults to max(vol)/100. CONN is 6, 18 or 26 (spm_bwlabel).

if nargin < 2 || isempty(E), E = 0.5; end
if nargin < 3 || isempty(H), H = 2; end
if nargin < 4 || isempty(conn), conn = 26; end
vol = double(vol);
vol(~isfinite(vol)) = 0;
t = zeros(size(vol));
top = max(vol(:));
if ~(top > 0)
    return
end
if nargin < 5 || isempty(dh)
    dh = top / 100;
end
% Only the bounding box of the positive voxels is labelled
pos = vol > 0;
[i, j, k] = ind2sub(size(vol), find(pos));
bi = min(i):max(i);
bj = min(j):max(j);
bk = min(k):max(k);
v = vol(bi, bj, bk);
acc = zeros(size(v));
for h = dh:dh:top
    above = v >= h;
    [lab, nc] = spm_bwlabel(double(above), conn);
    if nc == 0
        break
    end
    sz = accumarray(lab(above), 1, [nc 1]);
    acc(above) = acc(above) + sz(lab(above)) .^ E * h ^ H * dh;
end
t(bi, bj, bk) = acc;
end
