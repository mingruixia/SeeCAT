function [cfg, spec] = denoise_defaults(cfg)
% DENOISE_DEFAULTS  Denoise, censor and smooth options shared by pipelines.
%   [cfg, spec] = seecat.util.denoise_defaults(cfg)
%
% Adds cfg.denoise, cfg.censor and cfg.smooth (Doc/design/batch-api.md,
% 5.2) and returns their validation rows for seecat.check_config. Used by
% the prep and fmriprep pipelines, so both denoise the same way.

if nargin < 1
    cfg = struct();
end
cfg.denoise.enable        = true;
cfg.denoise.regressors    = {'friston24', 'wm', 'csf'};
cfg.denoise.acompcor_n    = 5;             % components per tissue when 'acompcor' is used
cfg.denoise.detrend_order = 1;
cfg.denoise.band          = [0.01 0.1];    % Hz; [] = no filter

cfg.censor.mode         = 'censor';        % 'censor', 'interp_keep' or 'none'
cfg.censor.fd_threshold = 0.5;             % mm, Power FD
cfg.censor.before       = 1;
cfg.censor.after        = 2;
cfg.censor.interp       = 'spectral';      % 'spectral' or 'spline' (design 5.2, D8)
cfg.censor.min_minutes  = 5;

cfg.smooth.enable = true;
cfg.smooth.fwhm   = 6;                     % mm, scalar or [x y z]

v = seecat.util.validators;
regressors = {'friston24', 'wm', 'csf', 'gs', 'acompcor'};
spec = {
    'denoise.enable',        v.flag,                            'true or false'
    'denoise.regressors',    @(x) iscellstr(x), ['a cell array of names: ' strjoin(regressors, ', ') ' or confounds column names'] %#ok<ISCLSTR>
    'denoise.acompcor_n',    @(x) v.count(x) && x > 0,          'a positive integer'
    'denoise.detrend_order', @(x) v.count(x) && x <= 3,         'an integer from 0 to 3'
    'denoise.band',          @(x) isempty(x) || (isnumeric(x) && numel(x) == 2 && x(1) >= 0 && (x(2) == 0 || x(2) > x(1))), '[] or [low high] in Hz (high 0 = no low-pass)'
    'censor.mode',           v.oneof({'censor', 'interp_keep', 'none'}), '''censor'', ''interp_keep'' or ''none'''
    'censor.fd_threshold',   v.positive,                        'a positive number (mm)'
    'censor.before',         v.count,                           'a non-negative integer'
    'censor.after',          v.count,                           'a non-negative integer'
    'censor.interp',         v.oneof({'spectral', 'spline'}),   '''spectral'' or ''spline'''
    'censor.min_minutes',    v.nonneg,                          'a non-negative number (minutes)'
    'smooth.enable',         v.flag,                            'true or false'
    'smooth.fwhm',           @(x) isnumeric(x) && any(numel(x) == [1 3]) && all(x >= 0), 'a scalar or 1x3 vector (mm)'
    };
end
