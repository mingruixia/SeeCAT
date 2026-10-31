function ctx = step_normalise(ctx, opt, ~)
% Apply the deformation: BOLD (4th-degree B-spline, the only resampling of
% the data) and the GM/WM/CSF maps (trilinear) to the output grid.

vox = opt.voxel_size;
if isscalar(vox)
    vox = [vox vox vox];
end
w = struct('bb', opt.bounding_box, 'vox', vox, 'interp', 4, 'prefix', 'w');
c = {ctx.files.c1; ctx.files.c2; ctx.files.c3};
job{1}.spm.spatial.normalise.write.subj.def = {ctx.files.deform};
job{1}.spm.spatial.normalise.write.subj.resample = frame_list(ctx.files.bold);
job{1}.spm.spatial.normalise.write.woptions = w;
w.interp = 1;
job{2}.spm.spatial.normalise.write.subj.def = {ctx.files.deform};
job{2}.spm.spatial.normalise.write.subj.resample = strcat(c, ',1');
job{2}.spm.spatial.normalise.write.woptions = w;
seecat.util.spm_run(job);
ctx.files.wbold = prefixed(ctx.files.bold);
for k = 1:3
    ctx.files.(sprintf('wc%d', k)) = prefixed(c{k});
end
end

function f = prefixed(f)
[d, n, e] = fileparts(f);
f = fullfile(d, ['w' n e]);
end
