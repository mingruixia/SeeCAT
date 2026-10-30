function log_msg(file, fmt, varargin)
% LOG_MSG  Print a time-stamped line and append it to a log file.
%   seecat.util.log_msg('run.log', 'Realign done (%.1f s)', t)
%   seecat.util.log_msg('', ...)        % console only
%
% The file is opened and closed on every call, so parallel workers can
% each write their own file safely.

line = sprintf(['%s  ' fmt], char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), varargin{:});
fprintf('%s\n', line);
if isempty(file)
    return
end
d = fileparts(file);
if ~isempty(d) && ~exist(d, 'dir')
    mkdir(d);
end
fid = fopen(file, 'a', 'n', 'UTF-8');
if fid < 0
    return
end
fprintf(fid, '%s\n', line);
fclose(fid);
end
