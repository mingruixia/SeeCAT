function ctx = step_realign(ctx, opt, log)
% SPM realign: estimate on a copy (its headers get the corrections) and
% write only the mean image. The BOLD data are resampled once, later, by
% normalise. With realign disabled, the mean is computed here and the
% motion parameters are zero.
%
% spm_realign is called directly with an output argument, so it writes
% nothing; the affines are then stored in one write. Through the batch,
% SPM updates a 4D file's header once per volume, which for a 440 MB,
% 480-volume run took over 20 minutes.

src = ctx.files.bold;
[d, n] = fileparts(src);
mc = fullfile(d, ['mc_' n '.nii']);
work_copy(src, mc);
rp = fullfile(d, ['rp_mc_' n '.txt']);
if opt.enable
    seecat.util.spm_run([]);
    flags = struct('quality', 0.9, 'sep', 4, 'fwhm', 5, 'rtm', double(opt.register_to_mean), ...
        'interp', 2, 'wrap', [0 0 0], 'PW', '', 'graphics', false);
    P = spm_realign(spm_vol(mc), flags);
    mats = cat(3, P.mat);
    Q = zeros(numel(P), 6);
    for k = 1:numel(P)
        q = spm_imatrix(P(k).mat / P(1).mat);
        Q(k, :) = q(1:6);
    end
    save(rp, 'Q', '-ascii');
    N = nifti(mc);
    N.mat = mats(:, :, 1);
    N.extras = struct('mat', mats);
    create(N);
    spm_reslice(P, struct('which', [0 1], 'mean', true, 'interp', 4, 'wrap', [0 0 0], ...
        'mask', 1, 'prefix', 'r'));
    log('realign: max translation %.2f mm, max rotation %.2f deg', ...
        max(abs(Q(:, 1:3)), [], 'all'), max(abs(Q(:, 4:6)), [], 'all') * 180 / pi);
else
    [Y, V] = seecat.io.read_nii(mc, 'Class', 'single');
    seecat.io.write_nii(mean(Y, 4), V(1), fullfile(d, ['meanmc_' n '.nii']));
    writematrix(zeros(numel(V), 6), rp, 'Delimiter', ' ', 'FileType', 'text');
    log('realign: disabled; motion parameters set to zero');
end
ctx.files.bold = mc;
ctx.files.mean = fullfile(d, ['meanmc_' n '.nii']);
ctx.files.rp = rp;
end
