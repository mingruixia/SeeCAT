function h = nii_info(file)
% NII_INFO  Image size and spacing from a NIfTI header, without the data.
%   h = seecat.io.nii_info('sub-01_task-rest_bold.nii.gz')
%
% h.dim     1 x 4 (x, y, z, volumes; 1 where the header has fewer)
% h.pixdim  1 x 4 (voxel size in mm, then the volume spacing)
% h.tr      volume spacing in seconds (NaN when the header has none)
% h.geom    the header bytes of the voxel size and orientation (qfac,
%           pixdim 1-3, qform and sform), to tell whether images share a grid
%
% Only the header is read, also from .nii.gz, so listing many runs stays
% quick. NIfTI-1 and NIfTI-2, either byte order.

if ~exist(file, 'file')
    error('SeeCAT:read', 'File not found: %s', file);
end
b = headBytes(file, 544);
le = typecast(b(1:4), 'int32');
nifti2 = any(le == [540 swapbytes(int32(540))]);
swap = ~any(le == [348 540]);
if nifti2
    dim = num(b, 17, 8, 'int64', swap);
    pix = num(b, 105, 8, 'double', swap);
    units = double(num(b, 501, 1, 'int32', swap));
    geom = [b(105:136), b(345:496)];
else
    dim = num(b, 41, 8, 'int16', swap);
    pix = num(b, 77, 8, 'single', swap);
    units = double(b(124));
    geom = [b(77:92), b(253:328)];
end
dim = double(dim);
n = max(1, min(dim(1), 7));
d = ones(1, 4);
d(1:min(n, 4)) = dim(2:min(n, 4) + 1);
h.dim = d;
h.pixdim = reshape(double(pix(2:5)), 1, []);
scale = struct('s', 1, 'ms', 1e-3, 'us', 1e-6);
t = h.pixdim(4);
switch bitand(units, 56)
    case 16
        t = t * scale.ms;
    case 24
        t = t * scale.us;
end
if ~(t > 0)
    t = NaN;
end
h.tr = t;
h.geom = geom;
end

function v = num(b, at, n, cls, swap)
w = struct('int16', 2, 'int32', 4, 'int64', 8, 'single', 4, 'double', 8).(cls);
v = typecast(b(at:at + n * w - 1), cls);
if swap
    v = swapbytes(v);
end
end

function b = headBytes(file, n)
% The first N bytes as uint8 (fewer if the file is shorter)
if endsWith(file, '.gz', 'IgnoreCase', true)
    s = java.util.zip.GZIPInputStream(java.io.FileInputStream(file));
    c = onCleanup(@() s.close()); %#ok<NASGU>
    b = zeros(1, n, 'uint8');
    for k = 1:n
        x = s.read();
        if x < 0
            b = b(1:k - 1);
            break
        end
        b(k) = x;
    end
else
    fid = fopen(file, 'r');
    b = fread(fid, n, '*uint8')';
    fclose(fid);
end
if numel(b) < 348
    error('SeeCAT:read', 'Not a NIfTI file: %s', file);
end
b(end+1:n) = 0;
end
