function F = gui()
% GUI  Form description of voxel-wise degree centrality.
f = @seecat.gui.field;
F = f('input_dir', 'Derivatives folder', 'folder', 'Input', 'help', 'Output of prep or fmriprep');
F(end+1) = f('input', 'Input series', 'text', 'Input');
F(end+1) = f('space', 'Space', 'text', 'Input', 'advanced', true);
F(end+1) = f('mask', 'Mask', 'text', 'Network', 'help', '''gm'', ''brain'' or a mask file');
F(end+1) = f('threshold', 'r threshold', 'number', 'Network');
F(end+1) = f('sign', 'Correlations', 'multi', 'Network', 'choices', {'positive', 'absolute', 'negative'});
F(end+1) = f('weight', 'Measures', 'multi', 'Network', 'choices', {'binary', 'weighted'}, ...
    'help', 'binary = degree, weighted = strength');
F(end+1) = f('exclude_local_mm', 'Exclude within (mm)', 'number', 'Network', 'advanced', true);
F(end+1) = f('distance_edges', 'Distance bins (mm)', 'text', 'Network', 'advanced', true, 'help', 'e.g. [0 75 Inf]');
F(end+1) = f('zscore', 'Also z-scored maps', 'flag', 'Output maps');
F(end+1) = f('smooth_fwhm', 'Smooth maps, FWHM (mm)', 'number', 'Output maps');
F = [F, seecat.gui.common(true)];
end
