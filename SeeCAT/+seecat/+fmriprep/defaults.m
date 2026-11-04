function [cfg, spec] = defaults()
% DEFAULTS  Default configuration for denoising fMRIPrep outputs.
%   [cfg, spec] = seecat.fmriprep.defaults()
%
% Use seecat.config('fmriprep'). Input is an fMRIPrep derivatives folder:
% for each BOLD run, *_space-<space>_desc-preproc_bold.nii.gz, its
% desc-brain_mask and the run's confounds table (desc-confounds_timeseries
% or, from older fMRIPrep, desc-confounds_regressors). SeeCAT then flags
% frames, denoises and smooths exactly as in the prep pipeline
% (seecat.util.denoise_defaults; Doc/design/batch-api.md, 5.2).

[cfg, spec] = seecat.util.common_defaults();
cfg = catstruct(struct('pipeline', 'fmriprep', 'fmriprep_dir', ''), cfg);
cfg.space = 'MNI152NLin2009cAsym';   % fMRIPrep output space to use
cfg.res = '';                        % res label, needed only when there are several
cfg.dummy_scans = 'auto';            % 'auto' = fMRIPrep's leading non-steady-state volumes
[cfg, dspec] = seecat.util.denoise_defaults(cfg);
[cfg, qspec] = seecat.util.qc_defaults(cfg, false); % exclusion rules (no IQMs: no raw data)

v = seecat.util.validators;
spec = [
    {
    'pipeline',      @(x) isequal(x, 'fmriprep'),                  '''fmriprep'''
    'fmriprep_dir',  @(x) v.text(x) && exist(x, 'dir') == 7,      'an existing fMRIPrep output folder'
    'space',         @(x) v.text(x) && ~isempty(regexp(x, '^[a-zA-Z0-9]+$', 'once')), 'an fMRIPrep space label, e.g. MNI152NLin2009cAsym'
    'res',           @(x) v.text(x) && (isempty(x) || ~isempty(regexp(x, '^[a-zA-Z0-9]+$', 'once'))), 'empty or a res label'
    'dummy_scans',   @(x) v.auto(x) || v.count(x),                 '''auto'' or a non-negative integer'
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
