function V = nii_grid(file)
% NII_GRID  The voxel grid of a NIfTI image, without its data.
%   V = seecat.io.nii_grid('sub-01_task-rest_desc-denoised_bold.nii.gz')
%
% V is the spm_vol header of the first volume (V.dim, V.mat), e.g. for the
% 'Ref' option of seecat.io.read_nii. Only the header is read: of a .nii.gz
% file the first bytes are unpacked, not the series, so the grids of many
% runs are found quickly. The affine is the one spm_vol gives.
if ~exist(file, 'file')
    error('SeeCAT:read', 'File not found: %s', file);
end
if ~endsWith(file, '.gz', 'IgnoreCase', true)
    V = spm_vol([file ',1']);
    V.private = [];
    return
end
b = headBytes(file, 544);
tmp = [tempname '.nii'];
c = onCleanup(@() deleteIf(tmp));
fid = fopen(tmp, 'w');
fwrite(fid, noExtension(b), 'uint8');
fclose(fid);
V = spm_vol([tmp ',1']);
V.fname = file;
V.private = [];
end

function b = noExtension(b)
% The header alone: the bytes that announce header extensions are cleared,
% as the extensions are not in the copy
le = typecast(b(1:4), 'int32');
if any(le == [540 swapbytes(int32(540))])          % NIfTI-2
    b(541:544) = 0;
else
    b = b(1:352);
    b(349:352) = 0;
end
end

function b = headBytes(file, n)
% The first N unpacked bytes of a .gz file as uint8
s = java.util.zip.GZIPInputStream(java.io.FileInputStream(file));
c = onCleanup(@() s.close());
b = zeros(1, n, 'uint8');
for k = 1:n
    x = s.read();
    if x < 0
        b = b(1:k - 1);
        break
    end
    b(k) = x;
end
if numel(b) < 352
    error('SeeCAT:read', 'Not a NIfTI file: %s', file);
end
end

function deleteIf(f)
if exist(f, 'file') == 2
    delete(f);
end
end
