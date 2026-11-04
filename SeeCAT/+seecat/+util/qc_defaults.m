function [cfg, spec] = qc_defaults(cfg, withIqm)
% QC_DEFAULTS  Quality-control options of the prep and fmriprep pipelines.
%   [cfg, spec] = seecat.util.qc_defaults(cfg, true)
%
% cfg.qc.iqm (prep only): compute MRIQC image quality metrics. The other
% fields are the rules seecat.qc.group_report applies to every run; a run
% that breaks one is suggested for exclusion in reports/qc_exclusions.tsv
% (the QC reports page lets you confirm or change each decision; Seed FC,
% Degree, Gradients, Harmonize and Statistics then leave excluded runs out).
% Too little data after censoring (censor.min_minutes) also excludes.
% IQM outliers (robust z beyond qc.iqm_z within a site, or within the
% dataset) are only warnings.
if withIqm
    cfg.qc.iqm = true;
end
cfg.qc.max_translation = 3;      % mm, largest absolute translation of the run
cfg.qc.max_rotation = 3;         % degrees, largest absolute rotation
cfg.qc.max_mean_fd = 0.5;        % mm, mean framewise displacement (Power)
cfg.qc.min_coverage = 0.9;       % share of the template brain inside the scan's field of view
cfg.qc.iqm_z = 3;                % robust z of an IQM that earns a warning

v = seecat.util.validators;
spec = {
    'qc.max_translation', v.positive, 'a positive number (mm)'
    'qc.max_rotation',    v.positive, 'a positive number (degrees)'
    'qc.max_mean_fd',     v.positive, 'a positive number (mm)'
    'qc.min_coverage',    @(x) isnumeric(x) && isscalar(x) && x >= 0 && x <= 1, 'a share in [0, 1]'
    'qc.iqm_z',           v.positive, 'a positive number'
    };
if withIqm
    spec = [{'qc.iqm', v.flag, 'true or false'}; spec];
end
end
