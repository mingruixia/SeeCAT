function dst = work_copy(src, dst)
% WORK_COPY  Copy (or unpack, for .nii.gz) an image to DST, a .nii path.
% SPM writes realignment of 4D files to a .mat next to the image; it is
% copied too, so the copy carries the same affines.
d = fileparts(dst);
if ~exist(d, 'dir')
    mkdir(d);
end
if endsWith(src, '.gz')
    tmp = tempname(d);
    f = gunzip(src, tmp);
    movefile(f{1}, dst, 'f');
    rmdir(tmp, 's');
else
    copyfile(src, dst, 'f');
end
% A .mat left from an interrupted run would give the copy stale affines
mat = regexprep(src, '\.nii(\.gz)?$', '.mat');
dstMat = regexprep(dst, '\.nii$', '.mat');
if exist(mat, 'file') && ~endsWith(src, '.gz')
    copyfile(mat, dstMat, 'f');
elseif exist(dstMat, 'file')
    delete(dstMat);
end
end
