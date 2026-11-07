function [cfg, spec] = defaults()
% DEFAULTS  Default configuration of voxel-wise degree centrality.
%   [cfg, spec] = seecat.degree.defaults()
%
% Use seecat.config('degree'). Input is a SeeCAT derivatives folder. Per
% run, the correlation network of the analysis-mask voxels (frames kept
% after censoring) gives each voxel's degree (binary) and strength
% (weighted), as in SeeCAT 1.0's VoxDeg (seecat.conn.degree). Maps are
% written raw and z-scored within the mask, then smoothed (decision D2:
% degree from unsmoothed data, smoothing of the map).

[cfg, spec] = seecat.util.common_defaults();
cfg = catstruct(struct('pipeline', 'degree', 'input_dir', ''), cfg);
cfg.input = 'denoised';               % desc of the input series
cfg.space = '';
cfg.res = '';                % res label, needed only when there are several
cfg.mask = 'gm';                      % 'gm' (TPM GM > 0.2), 'brain' (subject), or a file
cfg.group_mask = false;               % also keep only voxels in the brain mask of every run
cfg.threshold = 0.2;                  % r
cfg.sign = {'positive'};              % any of 'positive', 'absolute', 'negative'
cfg.weight = {'binary', 'weighted'};  % degree and/or strength
cfg.exclude_local_mm = 0;             % ignore connections shorter than this; 0 = off
cfg.distance_edges = [0 Inf];         % mm; e.g. [0 75 Inf] for short and long range
cfg.zscore = true;                    % also write maps z-scored within the mask
cfg.smooth_fwhm = 6;                  % mm, smoothing of the maps; 0 = none

cfg.qc_exclusions = true;         % leave out runs excluded in reports/qc_exclusions.tsv
v = seecat.util.validators;
spec = [
    {
    'pipeline',         @(x) isequal(x, 'degree'),                   '''degree'''
    'input_dir',        @(x) v.text(x) && exist(x, 'dir') == 7,      'an existing SeeCAT derivatives folder'
    'input',            @(x) v.text(x) && ~isempty(regexp(x, '^[a-zA-Z0-9]+$', 'once')), 'a desc label, e.g. denoised'
    'space',            v.text,                                       'empty or a space label'
    'res',              v.text,                                       'empty or a res label'
    'mask',             @(x) v.text(x) && (any(strcmp(x, {'gm', 'brain'})) || exist(x, 'file') == 2), '''gm'', ''brain'' or a mask file'
    'group_mask',       v.flag,                                       'true or false'
    'threshold',        @(x) isnumeric(x) && isscalar(x) && x >= 0 && x < 1, 'a correlation threshold in [0, 1)'
    'sign',             @(x) iscellstr(x) && ~isempty(x) && all(ismember(x, {'positive', 'absolute', 'negative'})), 'a non-empty subset of positive, absolute, negative' %#ok<ISCLSTR>
    'weight',           @(x) iscellstr(x) && ~isempty(x) && all(ismember(x, {'binary', 'weighted'})), 'a non-empty subset of binary, weighted' %#ok<ISCLSTR>
    'exclude_local_mm', v.nonneg,                                     'a non-negative number (mm)'
    'distance_edges',   @(x) isnumeric(x) && numel(x) >= 2 && x(1) >= 0 && all(diff(x) > 0), 'increasing bin edges in mm, from >= 0'
    'zscore',           v.flag,                                       'true or false'
    'smooth_fwhm',      @(x) isnumeric(x) && any(numel(x) == [1 3]) && all(x >= 0), 'a scalar or 1x3 vector (mm)'
    'qc_exclusions', v.flag, 'true or false'
    }
    spec];
end

function s = catstruct(a, b)
s = a;
for f = fieldnames(b)'
    s.(f{1}) = b.(f{1});
end
end
