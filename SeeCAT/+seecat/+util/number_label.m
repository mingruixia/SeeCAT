function s = number_label(v)
% NUMBER_LABEL  A number (or 3-vector) as a BIDS label.
%   3 -> '3', [2 2 2] -> '2', 2.5 -> '2p5', [2 2 3] -> '2x2x3'
if ~isscalar(v) && all(v == v(1))
    v = v(1);
end
if isscalar(v)
    s = strrep(sprintf('%g', v), '.', 'p');
else
    s = strjoin(arrayfun(@seecat.util.number_label, v, 'UniformOutput', false), 'x');
end
end
