function [cfg, spec] = pipeline_defaults(pipeline)
% PIPELINE_DEFAULTS  Defaults and validation spec of a named pipeline.
%   [cfg, spec] = seecat.util.pipeline_defaults('prep')

known = {'prep'};
if ~(ischar(pipeline) && any(strcmp(pipeline, known)))
    error('SeeCAT:config', 'Unknown pipeline "%s". Available: %s.', ...
        char(string(pipeline)), strjoin(known, ', '));
end
[cfg, spec] = feval(['seecat.' pipeline '.defaults']);
end
