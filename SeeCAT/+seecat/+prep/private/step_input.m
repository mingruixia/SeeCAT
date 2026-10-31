function ctx = step_input(ctx, opt, log)
% Copy the BOLD run (and T1w) into the work folder; drop dummy scans.
%
% dummy_scans 'auto' looks for non-steady-state volumes at the start of the
% run: leading frames whose mean in-brain intensity is a robust outlier
% (z > 3.5 against the median and MAD of the run, first 20 frames only).
% NumberOfVolumesDiscardedByScanner/ByUser in the sidecar describe volumes
% that are already gone, so they are not used.

bold = fullfile(ctx.work_dir, 'bold.nii');
work_copy(ctx.files.bold_src, bold);
V = spm_vol(bold);
nAll = numel(V);
n = opt.dummy_scans;
if ischar(n)                                   % 'auto'
    n = detectDummies(bold);
    log('input: %d non-steady-state volume(s) detected', n);
end
if n >= nAll - 10
    error('SeeCAT:prep', 'dummy_scans = %d leaves too few of the %d volumes.', n, nAll);
end
if n > 0
    [Y, V] = seecat.io.read_nii(bold, 'Volumes', n + 1:nAll, 'Class', 'single');
    trimmed = fullfile(ctx.work_dir, 'bold_trimmed.nii');
    seecat.io.write_nii(Y, V(1), trimmed);
    delete(bold);
    bold = trimmed;
end
ctx.files.bold = bold;
ctx.dummy_scans = n;
ctx.n_frames = nAll - n;
log('input: %d volume(s) kept', ctx.n_frames);
ctx.files.t1w = '';
if opt.use_t1w
    ctx.files.t1w = work_copy(ctx.files.t1w_src, fullfile(ctx.work_dir, 'anat.nii'));
end
end

function n = detectDummies(f)
Y = seecat.io.read_nii(f, 'Class', 'single');
Y = reshape(Y, [], size(Y, 4));
m = mean(Y, 2);
inBrain = m > mean(m);
g = double(mean(Y(inBrain, :), 1))';
z = (g - median(g)) / (1.4826 * mad(g, 1) + eps);
n = 0;
while n < min(20, numel(g)) && z(n + 1) > 3.5
    n = n + 1;
end
end
