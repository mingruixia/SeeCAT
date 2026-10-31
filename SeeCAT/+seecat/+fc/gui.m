function F = gui()
% GUI  Form description of seed-based FC.
f = @seecat.gui.field;
F = f('input_dir', 'Derivatives folder', 'folder', 'Input', 'help', 'Output of prep or fmriprep');
F(end+1) = f('input', 'Input series', 'text', 'Input', 'help', 'desc label: denoised, or e.g. denoisedSm6');
F(end+1) = f('space', 'Space', 'text', 'Input', 'advanced', true);
F(end+1) = f('seeds', 'Seeds', 'seeds', 'Seeds', 'help', 'Name + centre (mm) + radius (mm), or name + mask file');
F = [F, seecat.gui.common(true)];
end
