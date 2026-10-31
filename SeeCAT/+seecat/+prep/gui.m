function F = gui()
% GUI  Form description of the preprocessing pipeline (seecat.gui.form).
f = @seecat.gui.field;
F = f('bids_dir', 'BIDS folder', 'folder', 'Input', 'help', 'Raw BIDS dataset');
F(end+1) = f('dummy_scans', 'Dummy scans', 'text', 'Input', 'advanced', true, ...
    'help', '''auto'' detects non-steady-state volumes, or a number');
F(end+1) = f('slice_timing.enable', 'Slice timing', 'flag', 'Preprocessing');
F(end+1) = f('slice_timing.slice_times', 'Slice times (s)', 'text', 'Preprocessing', 'advanced', true, ...
    'help', '''auto'' = SliceTiming from the sidecar, or seconds per slice');
F(end+1) = f('slice_timing.ref_time', 'Reference time', 'text', 'Preprocessing', 'advanced', true, ...
    'help', '''middle'' of the TR, or seconds');
F(end+1) = f('realign.enable', 'Realign', 'flag', 'Preprocessing', 'advanced', true);
F(end+1) = f('realign.register_to_mean', 'Register to mean', 'flag', 'Preprocessing', 'advanced', true);
F(end+1) = f('normalise.enable', 'Normalise', 'flag', 'Preprocessing', 'advanced', true);
F(end+1) = f('normalise.method', 'Normalisation', 'choice', 'Preprocessing', 'choices', {'auto', 'segment', 'epi'}, ...
    'help', 'auto: T1w segmentation when a T1w exists, else the mean EPI');
F(end+1) = f('normalise.voxel_size', 'Voxel size (mm)', 'number', 'Preprocessing');
F(end+1) = f('normalise.bounding_box', 'Bounding box', 'text', 'Preprocessing', 'advanced', true);
F(end+1) = f('masks.wm_threshold', 'WM probability', 'number', 'Nuisance masks', 'advanced', true);
F(end+1) = f('masks.csf_threshold', 'CSF probability', 'number', 'Nuisance masks', 'advanced', true);
F(end+1) = f('masks.erode_mm', 'Erosion (mm)', 'number', 'Nuisance masks', 'advanced', true);
F = [F, seecat.gui.denoise(), seecat.gui.common(true)];
end
