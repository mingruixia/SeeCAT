function vol = resample(img, refHdr, interp)
% RESAMPLE  Read IMG on the voxel grid of REFHDR.
%   vol = seecat.io.resample(img, refHdr)          % nearest neighbour
%   vol = seecat.io.resample(img, refHdr, interp)  % SPM interpolation order
%
% IMG is a file name or spm_vol header; REFHDR is an spm_vol header (only
% .dim and .mat are used, so a 4D header works too). If the grids already
% match the image is read directly. Voxels outside IMG's field of view are 0.

if nargin < 3
    interp = 0;
end
if ischar(img) || isstring(img)
    img = spm_vol(char(img));
end
img = img(1);
refHdr = refHdr(1);
dim = refHdr.dim(1:3);

if isequal(img.dim(1:3), dim) && max(abs(img.mat(:) - refHdr.mat(:))) < 1e-4
    vol = spm_read_vols(img);
    return
end

vol = zeros(dim);
[x, y] = ndgrid(1:dim(1), 1:dim(2));
M = img.mat \ refHdr.mat;   % reference voxel -> image voxel
for z = 1:dim(3)
    xyz = M * [x(:)'; y(:)'; z * ones(1, numel(x)); ones(1, numel(x))];
    vol(:, :, z) = reshape(spm_sample_vol(img, xyz(1, :), xyz(2, :), xyz(3, :), interp), dim(1:2));
end
vol(isnan(vol)) = 0;
end
