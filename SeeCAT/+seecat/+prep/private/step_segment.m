function ctx = step_segment(ctx, opt, log)
% SPM unified segmentation with the SPM tissue probability maps. Source is
% the coregistered T1w ('segment') or the mean EPI ('epi'). Writes native
% GM/WM/CSF (c1-c3), the bias-corrected image (m) and the forward
% deformation to IXI549Space (y_).

if strcmp(opt.source, 'segment')
    src = ctx.files.t1w;
else
    src = ctx.files.mean;
end
tpm = fullfile(spm('dir'), 'tpm', 'TPM.nii');
ngaus = [1 1 2 3 4 2];
for k = 1:6
    tissue(k) = struct('tpm', {{sprintf('%s,%d', tpm, k)}}, 'ngaus', ngaus(k), ...
        'native', [k <= 3, 0], 'warped', [0 0]); %#ok<AGROW>
end
p.channel = struct('vols', {{[src ',1']}}, 'biasreg', 0.001, 'biasfwhm', 60, 'write', [0 1]);
p.tissue = tissue;
p.warp = struct('mrf', 1, 'cleanup', 1, 'reg', [0 0.001 0.5 0.05 0.2], 'affreg', 'mni', ...
    'fwhm', 0, 'samp', 3, 'write', [0 1], 'vox', NaN, 'bb', NaN(2, 3));
job.spm.spatial.preproc = p;
seecat.util.spm_run(job);

[d, n] = fileparts(src);
for k = 1:3
    ctx.files.(sprintf('c%d', k)) = fullfile(d, sprintf('c%d%s.nii', k, n));
end
ctx.files.biascorr = fullfile(d, ['m' n '.nii']);
ctx.files.deform = fullfile(d, ['y_' n '.nii']);
log('segment: %s', opt.source);
end
