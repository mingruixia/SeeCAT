function ctx = step_coreg(ctx, ~, ~)
% Coregister the T1w to the mean EPI (normalised mutual information). Only
% the header of a copy of the T1w changes.

[d, n] = fileparts(ctx.files.t1w);
t1 = fullfile(d, ['c' n '.nii']);
copyfile(ctx.files.t1w, t1, 'f');
job.spm.spatial.coreg.estimate.ref = {[ctx.files.mean ',1']};
job.spm.spatial.coreg.estimate.source = {[t1 ',1']};
job.spm.spatial.coreg.estimate.other = {''};
job.spm.spatial.coreg.estimate.eoptions = struct('cost_fun', 'nmi', 'sep', [4 2], ...
    'tol', [0.02 0.02 0.02 0.001 0.001 0.001 0.01 0.01 0.01 0.001 0.001 0.001], 'fwhm', [7 7]);
seecat.util.spm_run(job);
ctx.files.t1w = t1;
end
