function [cfg, spec] = pipeline_defaults(pipeline)
% PIPELINE_DEFAULTS  Defaults and validation spec of a named pipeline.
%   [cfg, spec] = seecat.util.pipeline_defaults('prep')
%
% A pipeline is a package seecat.<name> with defaults, plan and run_unit
% functions (see Doc/design/batch-api.md, section 7).

known = {'prep', 'fmriprep', 'fc', 'degree', 'gradient', 'harmonize', 'stat'};
if ~(ischar(pipeline) && ~isempty(regexp(pipeline, '^[a-z][a-z0-9_]*$', 'once')) ...
        && ~isempty(which(['seecat.' pipeline '.defaults'])))
    error('SeeCAT:config', 'Unknown pipeline "%s". Available: %s.', ...
        char(string(pipeline)), strjoin(known, ', '));
end
[cfg, spec] = feval(['seecat.' pipeline '.defaults']);
end
