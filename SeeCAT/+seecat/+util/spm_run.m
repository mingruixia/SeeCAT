function out = spm_run(matlabbatch)
% SPM_RUN  Run an SPM batch built in code.
%   out = seecat.util.spm_run(matlabbatch)
%
% SPM is initialised once per MATLAB process (each parallel worker is its
% own process): fMRI defaults, command-line mode (no figures) and the batch
% configuration. Errors from SPM are rethrown as SeeCAT:spm with the
% module name.

persistent ready
if isempty(ready)
    spm('defaults', 'fmri');
    spm_get_defaults('cmdline', true);
    spm_jobman('initcfg');
    ready = true;
end
if ~iscell(matlabbatch)
    matlabbatch = {matlabbatch};
end
try
    out = spm_jobman('run', matlabbatch);
catch err
    modules = cellfun(@moduleName, matlabbatch, 'UniformOutput', false);
    error('SeeCAT:spm', 'SPM %s failed: %s', strjoin(modules, ' + '), err.message);
end
end

function n = moduleName(job)
n = '';
s = job;
while isstruct(s) && isscalar(fieldnames(s))
    f = fieldnames(s);
    n = [n '.' f{1}]; %#ok<AGROW>
    s = s.(f{1});
end
n = n(2:end);
end
