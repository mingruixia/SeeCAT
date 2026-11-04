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

% WM/CSF masks are built in native space (step_tissue_masks). On 15 subjects
% (ds000030, ds002785) WM p > 0.99 eroded 2 mm keeps 46-104 cm^3 (min-median);
% CSF p > 0.99 eroded 2 mm can be empty, p > 0.95 keeps 2.7-8.4 cm^3.
% VBM maps: GM/WM normalised by the T1w segmentation (SPM, 1.5 mm, IXI549Space),
% modulated (tissue amount) or not, and smoothed; T1w runs only
cfg.vbm.enable    = false;
cfg.vbm.modulated = true;
cfg.vbm.fwhm      = 8;                     % mm; 0 = no smoothed copy

cfg.masks.wm_threshold  = 0.99;
cfg.masks.csf_threshold = 0.95;
cfg.masks.erode_mm      = 2;               % ball radius (mm), native space

[cfg, dspec] = seecat.util.denoise_defaults(cfg);   % denoise, censor, smooth
[cfg, qspec] = seecat.util.qc_defaults(cfg, true);  % IQMs and exclusion rules

v = seecat.util.validators;
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
    'vbm.enable',                  v.flag,                            'true or false'
    'vbm.modulated',               v.flag,                            'true or false'
    'vbm.fwhm',                    @(x) isnumeric(x) && any(numel(x) == [1 3]) && all(x >= 0), 'a scalar or 1x3 vector (mm)'
    'masks.wm_threshold',          @(x) v.positive(x) && x < 1,       'a probability in (0, 1)'
    'masks.csf_threshold',         @(x) v.positive(x) && x < 1,       'a probability in (0, 1)'
    'masks.erode_mm',              v.nonneg,                          'a non-negative number (mm)'
    }
    dspec
    qspec
    spec];
end

function s = catstruct(a, b)
s = a;
for f = fieldnames(b)'
    s.(f{1}) = b.(f{1});
end
end
