function t = task_list(v)
% TASK_LIST  The task selection as a row cell of labels.
%   seecat.bids.task_list('')               % {}  (every task)
%   seecat.bids.task_list('rest')           % {'rest'}
%   seecat.bids.task_list('rest, nback')    % {'rest', 'nback'}
%   seecat.bids.task_list({'rest', 'nback'})
if isempty(v)
    t = {};
    return
elseif ischar(v) || isstring(v)
    t = strtrim(strsplit(char(v), ','));
else
    t = cellfun(@(x) strtrim(char(x)), cellstr(v), 'UniformOutput', false);
end
t = reshape(unique(t(~cellfun(@isempty, t)), 'stable'), 1, []);
end
