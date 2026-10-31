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
    mat = regexprep(src, '\.nii$', '.mat');
    if exist(mat, 'file')
        copyfile(mat, regexprep(dst, '\.nii$', '.mat'), 'f');
    end
end
end
