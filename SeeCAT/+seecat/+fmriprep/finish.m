function finish(cfg, summary, log)
% FINISH  Group QC page after every unit ran (called by seecat.run).
%   seecat.fmriprep.finish(cfg, summary, log)
seecat.qc.group_report(cfg.output_dir, 'fmriprep', summary, cfg.qc);
log('QC: %s', fullfile(cfg.output_dir, 'reports', 'fmriprep_qc.html'));
end
