function finish(cfg, summary, log)
% FINISH  Group QC page after every unit ran (called by seecat.run).
%   seecat.prep.finish(cfg, summary, log)
seecat.qc.group_report(cfg.output_dir, 'prep', summary);
log('QC: %s', fullfile(cfg.output_dir, 'reports', 'prep_qc.html'));
end
