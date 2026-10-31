% COMPARE_RESOLUTION  Same subjects preprocessed at 2 mm and 3 mm output.
% Script; expects D:/data/SeeCAT_e2e/<dataset>_<res>mm/{seecat,work} with
% keep_work. Reports grid, WM/CSF mask sizes, brain-mask Dice with SPM
% mask_ICV, FD, PCC seed correlations, CSF/WM signal agreement between
% grids, and the spatial r of the 2 mm PCC map (on the 3 mm grid) with the
% 3 mm map.
addpath('D:/verysync/dropbox/Works/Claude_Project/SeeCAT/SeeCAT');
addpath('D:/verysync/dropbox/SciTools/MatlabToolbox/spm');
units = {'ds000030', 'sub-11061', 'sub-11061_task-rest'; 'ds000030', 'sub-50048', 'sub-50048_task-rest';
         'ds002785', 'sub-0001', 'sub-0001_task-restingstate_acq-mb3'; 'ds002785', 'sub-0002', 'sub-0002_task-restingstate_acq-mb3'};
for u = 1:size(units, 1)
  [ds, sub, stem] = units{u, :};
  fprintf('== %s %s\n', ds, sub);
  for res = [2 3]
    root = sprintf('D:/data/SeeCAT_e2e/%s_%dmm/seecat', ds, res);
    wk = sprintf('D:/data/SeeCAT_e2e/%s_%dmm/work/prep/%s', ds, res, stem);
    nw = nnz(seecat.io.read_nii(fullfile(wk, 'mask_wm.nii'))); nc = nnz(seecat.io.read_nii(fullfile(wk, 'mask_csf.nii')));
    d = fullfile(root, sub, 'func');
    p = sprintf('%s_space-IXI549Space_res-%d_', stem, res);
    mf = fullfile(d, [p 'desc-brain_mask.nii.gz']);
    if ~exist(mf, 'file'), fprintf('  res-%d: MISSING %s\n', res, mf); continue, end
    [m, V] = seecat.io.read_nii(mf);
    icv = seecat.io.read_nii(fullfile(spm('dir'), 'tpm', 'mask_ICV.nii'), 'Ref', V(1), 'Interp', 1) > 0.5;
    A = seecat.io.read_tsv(fullfile(d, [stem '_desc-confounds_timeseries.tsv']));
    keep = A.censor == 0;
    [Y, V] = seecat.io.read_nii(fullfile(d, [p 'desc-denoisedSm6_bold.nii.gz']), 'Class', 'single');
    Y2 = reshape(Y, [], size(Y, 4))';
    ts = @(mm) mean(double(Y2(:, sphere(V(1), mm, 6))), 2);
    pcc = ts([0 -53 26]);
    r = @(x) corr(pcc(keep), x(keep));
    mapz = atanh(corr(pcc(keep), double(Y2(keep, m(:) > 0))));
    M = zeros(V(1).dim); M(m(:) > 0) = mapz;
    maps{res} = M; mapV{res} = V(1); FD{res} = A.framewise_displacement; CSF{res} = A.csf; WM{res} = A.white_matter;
    fprintf('  res-%d dim %s vox %.1f | WM %d CSF %d vox | mask %d vox, Dice ICV %.3f | mean FD %.4f | r(PCC,mPFC) %.2f V1 %.2f M1 %.2f\n', res, ...
      mat2str(V(1).dim), abs(V(1).mat(1,1)), nw, nc, nnz(m), 2*nnz(m & icv)/(nnz(m)+nnz(icv)), mean(A.framewise_displacement, 'omitnan'), ...
      r(ts([0 52 -6])), r(ts([0 -90 0])), r(ts([-38 -22 56])));
  end
  % 2 mm seed map on the 3 mm grid vs the 3 mm map
  tmp = [tempname '.nii'];
  seecat.io.write_nii(maps{2}, mapV{2}, tmp);
  m2on3 = seecat.io.read_nii(tmp, 'Ref', mapV{3}, 'Interp', 1); delete(tmp);
  both = maps{3} ~= 0 & m2on3 ~= 0;
  fprintf('  FD identical %d | r(CSF 2 vs 3 mm) %.3f  r(WM) %.3f | seed-map spatial r %.3f\n', isequaln(FD{2}, FD{3}), corr(CSF{2}, CSF{3}), corr(WM{2}, WM{3}), corr(m2on3(both), maps{3}(both)));
end
function in = sphere(V, mm, r)
[i, j, k] = ndgrid(1:V.dim(1), 1:V.dim(2), 1:V.dim(3));
xyz = V.mat * [i(:) j(:) k(:) ones(numel(i), 1)]';
in = sum((xyz(1:3, :) - mm(:)).^2, 1) <= r^2;
end
