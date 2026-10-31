function ctx = step_realign(ctx, opt, log)
% SPM realign: estimate on a copy (its headers get the corrections) and
% write only the mean image. The BOLD data are resampled once, later, by
% normalise. With realign disabled, the mean is computed here and the
% motion parameters are zero.

src = ctx.files.bold;
[d, n] = fileparts(src);
mc = fullfile(d, ['mc_' n '.nii']);
copyfile(src, mc, 'f');
if opt.enable
    e = struct('quality', 0.9, 'sep', 4, 'fwhm', 5, 'rtm', double(opt.register_to_mean), ...
        'interp', 2, 'wrap', [0 0 0], 'weight', '');
    r = struct('which', [0 1], 'interp', 4, 'wrap', [0 0 0], 'mask', 1, 'prefix', 'r');
    job.spm.spatial.realign.estwrite.data = {frame_list(mc)};
    job.spm.spatial.realign.estwrite.eoptions = e;
    job.spm.spatial.realign.estwrite.roptions = r;
    seecat.util.spm_run(job);
    rp = fullfile(d, ['rp_mc_' n '.txt']);
else
    [Y, V] = seecat.io.read_nii(mc, 'Class', 'single');
    seecat.io.write_nii(mean(Y, 4), V(1), fullfile(d, ['meanmc_' n '.nii']));
    rp = fullfile(d, ['rp_mc_' n '.txt']);
    writematrix(zeros(numel(V), 6), rp, 'Delimiter', ' ', 'FileType', 'text');
    log('realign: disabled; motion parameters set to zero');
end
ctx.files.bold = mc;
ctx.files.mean = fullfile(d, ['meanmc_' n '.nii']);
ctx.files.rp = rp;
end
