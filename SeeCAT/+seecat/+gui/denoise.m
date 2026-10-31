function F = denoise()
% DENOISE  Form entries of the denoise, censor and smooth options
% (seecat.util.denoise_defaults), shared by prep and fmriprep.
f = @seecat.gui.field;
F = f('denoise.enable', 'Denoise', 'flag', 'Denoising');
F(end+1) = f('denoise.regressors', 'Regressors', 'multi', 'Denoising', ...
    'choices', {'friston24', 'wm', 'csf', 'gs', 'acompcor'}, 'help', 'Confound columns may also be named in the config file');
F(end+1) = f('denoise.acompcor_n', 'aCompCor components', 'number', 'Denoising', 'advanced', true);
F(end+1) = f('denoise.detrend_order', 'Detrend order', 'number', 'Denoising', 'advanced', true);
F(end+1) = f('denoise.band', 'Band-pass (Hz)', 'range', 'Denoising', 'help', 'Empty = no filter');
F(end+1) = f('censor.mode', 'High-motion frames', 'choice', 'Censoring', 'choices', {'censor', 'interp_keep', 'none'});
F(end+1) = f('censor.fd_threshold', 'FD threshold (mm)', 'number', 'Censoring');
F(end+1) = f('censor.before', 'Frames before', 'number', 'Censoring', 'advanced', true);
F(end+1) = f('censor.after', 'Frames after', 'number', 'Censoring', 'advanced', true);
F(end+1) = f('censor.interp', 'Interpolation', 'choice', 'Censoring', 'choices', {'spectral', 'spline'}, 'advanced', true);
F(end+1) = f('censor.min_minutes', 'Minimum minutes', 'number', 'Censoring', 'advanced', true);
F(end+1) = f('smooth.enable', 'Smooth', 'flag', 'Smoothing');
F(end+1) = f('smooth.fwhm', 'FWHM (mm)', 'number', 'Smoothing');
end
