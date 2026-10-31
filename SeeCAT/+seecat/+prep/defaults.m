function [cfg, spec] = defaults()
% DEFAULTS  Default configuration of the preprocessing pipeline.
%   [cfg, spec] = seecat.prep.defaults()
%
% Use seecat.config('prep') rather than calling this directly. The design
% behind each option is in Doc/design/batch-api.md, section 5.

[cfg, spec] = seecat.util.common_defaults();
cfg = catstruct(struct('pipeline', 'prep', 'bids_dir', ''), cfg);

cfg.dummy_scans = 'auto';         % 'auto' = from the BOLD sidecar, else 0

cfg.slice_timing.enable      = true;
cfg.slice_timing.slice_times = 'auto';     % 'auto' = SliceTiming from the sidecar; or seconds per slice
cfg.slice_timing.ref_time    = 'middle';   % 'middle' of the TR, or seconds

cfg.realign.enable           = true;
cfg.realign.register_to_mean = true;

cfg.normalise.enable       = true;
cfg.normalise.method       = 'auto';       % 'auto' = 'segment' with a T1w, else 'epi'
cfg.normalise.voxel_size   = 3;
cfg.normalise.bounding_box = [-90 -126 -72; 90 90 108];

cfg.masks.wm_threshold  = 0.99;
cfg.masks.csf_threshold = 0.99;
cfg.masks.erode         = 1;               % voxels

cfg.denoise.enable        = true;
cfg.denoise.regressors    = {'friston24', 'wm', 'csf'};
cfg.denoise.acompcor_n    = 5;             % components per tissue when 'acompcor' is used
cfg.denoise.detrend_order = 1;
cfg.denoise.band          = [0.01 0.1];    % Hz; [] = no filter

cfg.censor.mode         = 'censor';        % 'censor', 'interp_keep' or 'none'
cfg.censor.fd_threshold = 0.5;             % mm, Power FD
cfg.censor.before       = 1;
cfg.censor.after        = 2;
cfg.censor.interp       = 'spectral';      % 'spectral' or 'spline' (design 5.2)
cfg.censor.min_minutes  = 5;

cfg.smooth.enable = true;
cfg.smooth.fwhm   = 6;                     % mm, scalar or [x y z]

v = seecat.util.validators;
regressors = {'friston24', 'wm', 'csf', 'gs', 'acompcor'};
spec = [
    {
    'pipeline',                    @(x) isequal(x, 'prep'),           '''prep'''
    'bids_dir',                    @(x) v.text(x) && exist(x, 'dir') == 7, 'an existing BIDS dataset folder'
    'dummy_scans',                 @(x) v.auto(x) || v.count(x),      '''auto'' or a non-negative integer'
    'slice_timing.enable',         v.flag,                            'true or false'
    'slice_timing.slice_times',    @(x) v.auto(x) || (isnumeric(x) && isvector(x) && all(x >= 0)), '''auto'' or slice times in seconds'
    'slice_timing.ref_time',       @(x) isequal(x, 'middle') || v.nonneg(x), '''middle'' or a time in seconds'
    'realign.enable',              v.flag,                            'true or false'
    'realign.register_to_mean',    v.flag,                            'true or false'
    'normalise.enable',            v.flag,                            'true or false'
    'normalise.method',            v.oneof({'auto', 'segment', 'epi'}), '''auto'', ''segment'' or ''epi'''
    'normalise.voxel_size',        @(x) isnumeric(x) && any(numel(x) == [1 3]) && all(x > 0), 'a positive scalar or 1x3 vector (mm)'
    'normalise.bounding_box',      @(x) isnumeric(x) && isequal(size(x), [2 3]) && all(x(1, :) < x(2, :)), 'a 2x3 matrix [min; max] in mm'
    'masks.wm_threshold',          @(x) v.positive(x) && x < 1,       'a probability in (0, 1)'
    'masks.csf_threshold',         @(x) v.positive(x) && x < 1,       'a probability in (0, 1)'
    'masks.erode',                 v.count,                           'a non-negative integer'
    'denoise.enable',              v.flag,                            'true or false'
    'denoise.regressors',          @(x) iscellstr(x), ['a cell array of names: ' strjoin(regressors, ', ') ' or confounds column names'] %#ok<ISCLSTR>
    'denoise.acompcor_n',          @(x) v.count(x) && x > 0,          'a positive integer'
    'denoise.detrend_order',       @(x) v.count(x) && x <= 3,         'an integer from 0 to 3'
    'denoise.band',                @(x) isempty(x) || (isnumeric(x) && numel(x) == 2 && x(1) >= 0 && (x(2) == 0 || x(2) > x(1))), '[] or [low high] in Hz (high 0 = no low-pass)'
    'censor.mode',                 v.oneof({'censor', 'interp_keep', 'none'}), '''censor'', ''interp_keep'' or ''none'''
    'censor.fd_threshold',         v.positive,                        'a positive number (mm)'
    'censor.before',               v.count,                           'a non-negative integer'
    'censor.after',                v.count,                           'a non-negative integer'
    'censor.interp',               v.oneof({'spectral', 'spline'}), '''spectral'' or ''spline'''
    'censor.min_minutes',          v.nonneg,                          'a non-negative number (minutes)'
    'smooth.enable',               v.flag,                            'true or false'
    'smooth.fwhm',                 @(x) isnumeric(x) && any(numel(x) == [1 3]) && all(x >= 0), 'a scalar or 1x3 vector (mm)'
    }
    spec];
end

function s = catstruct(a, b)
s = a;
for f = fieldnames(b)'
    s.(f{1}) = b.(f{1});
end
end
