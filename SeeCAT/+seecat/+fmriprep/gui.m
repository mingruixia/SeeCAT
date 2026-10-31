function F = gui()
% GUI  Form description of the fMRIPrep denoising pipeline.
f = @seecat.gui.field;
F = f('fmriprep_dir', 'fMRIPrep folder', 'folder', 'Input', 'help', 'derivatives/fmriprep');
F(end+1) = f('space', 'Space', 'text', 'Input', 'help', 'fMRIPrep output space');
F(end+1) = f('res', 'Resolution label', 'text', 'Input', 'advanced', true, 'help', 'Only when several exist');
F(end+1) = f('dummy_scans', 'Dummy scans', 'text', 'Input', 'advanced', true, ...
    'help', '''auto'' = fMRIPrep''s non-steady-state volumes, or a number');
F = [F, seecat.gui.denoise(), seecat.gui.common(true)];
end
