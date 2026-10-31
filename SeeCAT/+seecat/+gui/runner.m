function R = runner(cfg)
% RUNNER  Run a pipeline in a separate MATLAB process (design gui.md, G3).
%   R = seecat.gui.runner(cfg);
%   txt = R.read();        % output written since the last read
%   tf = R.running();
%   R.stop();
%
% The config is saved as JSON and `matlab -batch` runs seecat.run on it,
% with this session's SeeCAT and SPM on the path. The child opens its own
% parallel pool, so cfg.n_workers works as in batch use, and the window that
% started it stays responsive. Its output goes to a log file that read()
% returns piece by piece. stop() ends the process (finished units keep their
% done markers; an interrupted unit resumes from its last step next time).

here = fileparts(fileparts(fileparts(mfilename('fullpath'))));       % SeeCAT/
spmDir = fileparts(which('spm'));
if isempty(spmDir)
    error('SeeCAT:gui', 'SPM is not on the MATLAB path.');
end
d = tempname;
mkdir(d);
cfgFile = fullfile(d, 'config.json');
seecat.save_config(cfg, cfgFile);
logFile = fullfile(d, 'run.log');
cmd = sprintf('addpath(''%s''); addpath(''%s''); seecat.run(''%s'');', ...
    esc(here), esc(spmDir), esc(cfgFile));
exe = fullfile(matlabroot, 'bin', 'matlab');
if ispc
    exe = [exe '.exe'];
end
pb = java.lang.ProcessBuilder({exe, '-batch', cmd});
pb.redirectErrorStream(true);
pb.redirectOutput(java.io.File(logFile));
proc = pb.start();
pos = 0;
R.config = cfgFile;
R.log = logFile;
R.read = @readNew;
R.running = @() proc.isAlive();
R.stop = @() proc.destroyForcibly();
R.exitCode = @exitCode;

    function txt = readNew()
        txt = '';
        if ~exist(logFile, 'file'), return, end
        fid = fopen(logFile, 'r', 'n', 'UTF-8');
        if fid < 0, return, end
        fseek(fid, pos, 'bof');
        txt = fread(fid, Inf, '*char')';
        pos = ftell(fid);
        fclose(fid);
    end

    function c = exitCode()
        c = [];
        if ~proc.isAlive()
            c = proc.exitValue();
        end
    end
end

function s = esc(p)
s = strrep(strrep(p, '\', '/'), '''', '''''');
end
