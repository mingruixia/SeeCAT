function ctx = step_confounds(ctx, opt, log)
% Confounds table with fMRIPrep column names (Doc/design/batch-api.md 5.3):
%   global_signal, csf, white_matter   mean signal in the brain/CSF/WM masks
%   c_comp_cor_XX, w_comp_cor_XX       aCompCor, CSF and WM separately
%   trans_*, rot_* (+ derivatives, squares)   Friston 24
%   framewise_displacement             Power FD
%   motion_outlier_XX                  one column per flagged frame
%   censor                             1 = drop this frame in later analyses
%                                      (censor.mode 'censor' only)
% Also sets ctx.qc for the run summary.

c = opt.censor;
rp = load(ctx.files.rp, '-ascii');
nT = size(rp, 1);
fd = seecat.denoise.fd_power(rp);
bad = false(nT, 1);
if ~strcmp(c.mode, 'none')
    bad = seecat.denoise.flag_frames(fd, c.fd_threshold, c.before, c.after);
end

[Y, ~] = seecat.io.read_nii(ctx.files.wbold, 'Class', 'single');
Y = reshape(Y, [], nT)';
M = cellfun(@(f) logical(seecat.io.read_nii(f)), ...
    {ctx.files.mask_brain, ctx.files.mask_wm, ctx.files.mask_csf}, 'UniformOutput', false);
M = cellfun(@(m) m(:)', M, 'UniformOutput', false);

T = table();
T.global_signal = double(mean(Y(:, M{1}), 2));
T.csf = double(mean(Y(:, M{3}), 2));
T.white_matter = double(mean(Y(:, M{2}), 2));
T = addComponents(T, 'c_comp_cor', seecat.denoise.compcor(Y(:, M{3}), opt.acompcor_n, opt.detrend_order, ~bad));
T = addComponents(T, 'w_comp_cor', seecat.denoise.compcor(Y(:, M{2}), opt.acompcor_n, opt.detrend_order, ~bad));
T = [T, seecat.denoise.motion_regressors(rp)];
T.framewise_displacement = fd;
idx = find(bad);
for k = 1:numel(idx)
    col = zeros(nT, 1);
    col(idx(k)) = 1;
    T.(sprintf('motion_outlier_%02d', k - 1)) = col;
end
drop = bad & strcmp(c.mode, 'censor');
T.censor = double(drop);
f = fullfile(ctx.work_dir, 'confounds.tsv');
seecat.io.write_tsv(T, f);
ctx.files.confounds = f;

minutes = nnz(~drop) * ctx.tr / 60;
ctx.qc = struct('dummy_scans', ctx.dummy_scans, 'n_frames', nT, ...
    'mean_fd', mean(fd, 'omitnan'), 'max_fd', max(fd), 'n_flagged', nnz(bad), ...
    'minutes_kept', minutes, 'low_data', minutes < c.min_minutes);
log('confounds: mean FD %.3f mm, %d of %d frames flagged, %.1f min kept', ...
    ctx.qc.mean_fd, nnz(bad), nT, minutes);
if ctx.qc.low_data
    log('confounds: WARNING less than %g min of good data', c.min_minutes);
end
end

function T = addComponents(T, prefix, C)
for k = 1:size(C, 2)
    T.(sprintf('%s_%02d', prefix, k - 1)) = C(:, k);
end
end
