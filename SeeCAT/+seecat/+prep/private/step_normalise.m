function ctx = step_normalise(ctx, opt, ~)
% Apply the deformation: BOLD (4th-degree B-spline, the only resampling of
% the data), the GM/WM/CSF maps and the native WM/CSF masks (trilinear)
% to the output grid.
%
% The BOLD run is split into 3D volumes (each keeps its realigned affine),
% normalised by SPM, and written back as one 4D file. SPM writes a 4D
% output volume by volume, and each write gets slower as the file grows: a
% 480-volume run took over 10 minutes that way.

vox = opt.voxel_size;
if isscalar(vox)
    vox = [vox vox vox];
end
w = struct('bb', opt.bounding_box, 'vox', vox, 'interp', 4, 'prefix', 'w');
c = {ctx.files.c1; ctx.files.c2; ctx.files.c3; ctx.files.native_wm; ctx.files.native_csf};
frames = splitVolumes(ctx.files.bold, fullfile(ctx.work_dir, 'frames'));
job{1}.spm.spatial.normalise.write.subj.def = {ctx.files.deform};
job{1}.spm.spatial.normalise.write.subj.resample = strcat(frames, ',1');
job{1}.spm.spatial.normalise.write.woptions = w;
w.interp = 1;
job{2}.spm.spatial.normalise.write.subj.def = {ctx.files.deform};
job{2}.spm.spatial.normalise.write.subj.resample = strcat(c, ',1');
job{2}.spm.spatial.normalise.write.woptions = w;
seecat.util.spm_run(job);

wframes = cellfun(@prefixed, frames, 'UniformOutput', false);
[Y, V] = seecat.io.read_nii(wframes, 'Class', 'single');
Y(isnan(Y)) = 0;                               % outside the field of view
ctx.files.wbold = prefixed(ctx.files.bold);
seecat.io.write_nii(Y, V(1), ctx.files.wbold);
rmdir(fullfile(ctx.work_dir, 'frames'), 's');
for k = 1:3
    ctx.files.(sprintf('wc%d', k)) = prefixed(c{k});
end
ctx.files.wnative_wm = prefixed(c{4});
ctx.files.wnative_csf = prefixed(c{5});
end

function files = splitVolumes(f, d)
if exist(d, 'dir')
    rmdir(d, 's');
end
mkdir(d);
V = spm_vol(f);
files = cell(numel(V), 1);
for k = 1:numel(V)
    Y = spm_read_vols(V(k));
    o = V(k);
    o.fname = fullfile(d, sprintf('f%05d.nii', k));
    o.n = [1 1];
    o.dt = [spm_type('float32') spm_platform('bigend')];
    o.pinfo = [1; 0; 0];
    o.private = [];
    spm_write_vol(o, Y);
    files{k} = o.fname;
end
end

function f = prefixed(f)
[d, n, e] = fileparts(f);
f = fullfile(d, ['w' n e]);
end
