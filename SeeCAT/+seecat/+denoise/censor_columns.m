function [T, qc, meta] = censor_columns(T, fd, c, tr)
% CENSOR_COLUMNS  Add frame flags to a confounds table, with QC numbers.
%   [T, qc, meta] = seecat.denoise.censor_columns(T, fd, cfg.censor, tr)
%
% FD is framewise displacement (mm; NaN allowed, e.g. the first frame).
% With censor.mode other than 'none', frames with FD > fd_threshold and
% their neighbours (seecat.denoise.flag_frames) get one motion_outlier_XX
% column each. The 'censor' column is 1 for frames later analyses drop:
% the flagged frames in mode 'censor', none otherwise. Existing
% motion_outlier*, non_steady_state_outlier* and censor columns (e.g. from
% fMRIPrep, which flags by FD and DVARS) are replaced, so SeeCAT's rule
% applies to every input.
%
% QC: n_frames, mean_fd, max_fd, n_flagged, minutes_kept, low_data
% (minutes_kept < censor.min_minutes). META describes the columns for the
% confounds JSON sidecar.

vars = T.Properties.VariableNames;
old = ~cellfun(@isempty, regexp(vars, '^(motion_outlier|non_steady_state_outlier)_?\d+$|^censor$', 'once'));
T(:, old) = [];
nT = height(T);
fd = fd(:);
bad = false(nT, 1);
if ~strcmp(c.mode, 'none')
    bad = seecat.denoise.flag_frames(fd, c.fd_threshold, c.before, c.after);
end
idx = find(bad);
for k = 1:numel(idx)
    col = zeros(nT, 1);
    col(idx(k)) = 1;
    T.(sprintf('motion_outlier_%02d', k - 1)) = col;
end
drop = bad & strcmp(c.mode, 'censor');
T.censor = double(drop);

minutes = nnz(~drop) * tr / 60;
qc = struct('n_frames', nT, 'mean_fd', mean(fd, 'omitnan'), 'max_fd', max(fd), ...
    'n_flagged', nnz(bad), 'minutes_kept', minutes, 'low_data', minutes < c.min_minutes);

meta.framewise_displacement = struct('Description', 'Framewise displacement (Power et al. 2012), rotations on a 50 mm sphere', 'Units', 'mm');
meta.motion_outlier = struct('Description', sprintf(['One column per flagged frame: FD > %g mm, ' ...
    'plus %d frame(s) before and %d after'], c.fd_threshold, c.before, c.after));
meta.censor = struct('Description', ['1 = frame excluded from later analyses (censor.mode ''censor''). ' ...
    'In the denoised series these frames hold interpolated values.'], 'CensorMode', c.mode);
end
