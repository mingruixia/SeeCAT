function T = compare_outputs(dirA, dirB, outCsv)
% COMPARE_OUTPUTS  Voxel-wise comparison of every NIfTI file present under
% both DIRA and DIRB (matched by relative path).
%
%   T = compare_outputs('D:/data/SeeCAT_baseline/ds000030', ...
%                       'D:/data/SeeCAT_fixed/ds000030', 'diff.csv')
%
% Columns: file, maxAbsDiff, corr (over voxels non-zero in either), nVolA,
% nVolB. Files present on one side only are listed with NaN.

a = listNii(dirA);
b = listNii(dirB);
all = unique([a; b]);
n = numel(all);
maxAbsDiff = nan(n, 1); r = nan(n, 1); nA = nan(n, 1); nB = nan(n, 1);
for i = 1:n
    fa = fullfile(dirA, all{i});
    fb = fullfile(dirB, all{i});
    if exist(fa, 'file'), nA(i) = numel(spm_vol(fa)); end
    if exist(fb, 'file'), nB(i) = numel(spm_vol(fb)); end
    if isnan(nA(i)) || isnan(nB(i)) || nA(i) ~= nB(i)
        continue
    end
    % raw arrays: realigned 4D files carry a different affine per volume
    va = double(nifti(fa).dat(:,:,:,:));
    vb = double(nifti(fb).dat(:,:,:,:));
    if ~isequal(size(va), size(vb))
        continue
    end
    d = abs(va(:) - vb(:));
    d(isnan(va(:)) & isnan(vb(:))) = 0;
    maxAbsDiff(i) = max(d);
    m = (va(:) ~= 0 | vb(:) ~= 0) & isfinite(va(:)) & isfinite(vb(:));
    if nnz(m) > 2
        r(i) = corr(va(m), vb(m));
    end
end
T = table(all, maxAbsDiff, r, nA, nB, 'VariableNames', {'file', 'maxAbsDiff', 'corr', 'nVolA', 'nVolB'});
if nargin > 2
    writetable(T, outCsv);
end
end

function f = listNii(root)
l = dir(fullfile(root, '**', '*.nii'));
f = cellfun(@(d, n) erase(fullfile(d, n), [char(root) filesep]), {l.folder}, {l.name}, 'UniformOutput', false)';
f = strrep(f, '\', '/');
f = erase(f, [strrep(char(root), '\', '/') '/']);
end
