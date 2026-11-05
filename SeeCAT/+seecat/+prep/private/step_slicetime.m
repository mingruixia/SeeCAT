function ctx = step_slicetime(ctx, opt, log)
% SPM slice timing with slice acquisition times (works for multiband).
% Times are seconds from the start of the TR, from SliceTiming in the
% sidecar ('auto') or given in opt.slice_times; the reference is the middle
% of the TR or opt.ref_time seconds. Skipped, with a log line, when 'auto'
% finds no SliceTiming.
%
% BIDS SliceTiming lists the slices along SliceEncodingDirection (k when
% absent). SPM corrects along the third voxel axis: k is used as it is, k-
% reversed (its first entry is the last slice of the third axis). i and j
% (slices along the first or second voxel axis) are not supported: an
% error, rather than times applied to the wrong slices. Times given in
% opt.slice_times are in voxel order along the third axis.

st = opt.slice_times;
if ischar(st)
    st = ctx.slice_timing;
    if isempty(st)
        log('slicetime: no SliceTiming in the sidecar; skipped');
        return
    end
    sd = 'k';
    if isfield(ctx, 'slice_direction') && ~isempty(ctx.slice_direction)
        sd = ctx.slice_direction;
    end
    st = seecat.bids.slice_times(st, sd);
    if strcmp(sd, 'k-')
        log('slicetime: SliceEncodingDirection k-, slice times reversed to voxel order');
    end
end
V = spm_vol(ctx.files.bold);
nz = V(1).dim(3);
if numel(st) ~= nz
    error('SeeCAT:prep', 'SliceTiming has %d entries but the image has %d slices.', numel(st), nz);
end
if any(st < 0) || any(st >= ctx.tr)
    error('SeeCAT:prep', 'Slice times must lie in [0, TR) seconds (TR = %g s).', ctx.tr);
end
ref = opt.ref_time;
if ischar(ref)                                 % 'middle'
    ref = ctx.tr / 2;
end
job.spm.temporal.st.scans = {frame_list(ctx.files.bold)};
job.spm.temporal.st.nslices = nz;
job.spm.temporal.st.tr = ctx.tr;
job.spm.temporal.st.ta = 0;                    % ignored when times are given
job.spm.temporal.st.so = st(:)' * 1000;        % ms
job.spm.temporal.st.refslice = ref * 1000;
job.spm.temporal.st.prefix = 'a';
seecat.util.spm_run(job);
ctx.files.bold = prefixed(ctx.files.bold, 'a');
log('slicetime: %d slices, reference %.3f s', nz, ref);
end

function f = prefixed(f, p)
[d, n, e] = fileparts(f);
f = fullfile(d, [p n e]);
end
