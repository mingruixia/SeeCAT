function v = parse(s, widget, old)
% PARSE  Text of a form field as a config value of the right type.
%   v = seecat.gui.parse('0.01 0.1', 'range', [0.01 0.1])
%   v = seecat.gui.parse('auto', 'text', 'auto')
%   v = seecat.gui.parse('[-90 -126 -72; 90 90 108]', 'text', zeros(2, 3))
%
% OLD (the option's current value) gives the type: numbers and matrices
% (rows split by ';'; Inf allowed), lists (comma separated), selector
% structs ('key=value, ...'), or text. A text option whose old value is a
% keyword ('auto', 'middle') becomes a number when the text is a number,
% since such options take either. Nothing is evaluated as MATLAB code.

s = strtrim(char(s));
switch widget
    case 'labels'
        v = splitList(s);
        return
    case 'maps'
        v = struct();
        for p = splitList(s)
            kv = strsplit(p{1}, '=');
            if numel(kv) == 2
                v.(strtrim(kv{1})) = strtrim(kv{2});
            end
        end
        return
end
if iscell(old)
    v = splitList(s);
elseif isnumeric(old) || islogical(old)
    v = numbers(s);
    if isempty(v) && ~isempty(s)
        error('SeeCAT:gui', 'Expected numbers, got "%s".', s);
    end
    if islogical(old) && ~isempty(v)
        v = logical(v);
    end
else
    n = numbers(s);
    if ~isempty(s) && ~isempty(n) && isempty(regexp(s, '[a-zA-Z_/\\:]', 'once'))
        v = n;                                    % e.g. dummy_scans '3'
    else
        v = s;
    end
end
end

function c = splitList(s)
c = strtrim(strsplit(s, ','));
c = c(~cellfun(@isempty, c));
if isempty(c)
    c = {};
end
end

function v = numbers(s)
s = regexprep(s, '[\[\]]', '');
rows = strsplit(s, ';');
v = [];
for r = rows
    tok = regexp(r{1}, '[-+]?(Inf|inf|\d+\.?\d*(e[-+]?\d+)?|\.\d+(e[-+]?\d+)?)', 'match');
    x = str2double(tok);
    if isempty(x), continue, end
    if isempty(v)
        v = x;
    elseif numel(x) == size(v, 2)
        v = [v; x]; %#ok<AGROW>
    else
        error('SeeCAT:gui', 'Rows of different length in "%s".', s);
    end
end
end
