function s = format(v, widget)
% FORMAT  A config value as the text shown in a form field (inverse of parse).
%   s = seecat.gui.format([0.01 0.1], 'range')   % '0.01 0.1'
if nargin < 2
    widget = 'text';
end
if isstruct(v)                                   % maps selector: key=value, ...
    k = fieldnames(v);
    s = strjoin(cellfun(@(x) sprintf('%s=%s', x, char(string(v.(x)))), k, 'UniformOutput', false), ', ');
elseif iscell(v)
    s = strjoin(cellfun(@(x) char(string(x)), v, 'UniformOutput', false), ', ');
elseif ischar(v) || isstring(v)
    s = char(v);
elseif isempty(v)
    s = '';
elseif isnumeric(v) || islogical(v)
    if isscalar(v)
        s = sprintf('%g', v);
    elseif isvector(v) && any(strcmp(widget, {'range', 'number'}))
        s = strjoin(arrayfun(@(x) sprintf('%g', x), v, 'UniformOutput', false), ' ');
    else
        s = mat2str(v);
    end
else
    s = char(string(v));
end
end
