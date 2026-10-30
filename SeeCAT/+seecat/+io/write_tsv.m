function write_tsv(T, file)
% WRITE_TSV  Write a table as BIDS-style TSV (tab-separated, "n/a" for missing).
%   seecat.io.write_tsv(T, 'summary.tsv')
%
% Numeric NaN, empty char and missing strings are written as n/a.

d = fileparts(file);
if ~isempty(d) && ~exist(d, 'dir')
    mkdir(d);
end
names = T.Properties.VariableNames;
cols = cell(1, numel(names));
for j = 1:numel(names)
    cols{j} = cellText(T.(names{j}));
end
fid = fopen(file, 'w', 'n', 'UTF-8');
if fid < 0
    error('SeeCAT:io', 'Cannot write %s', file);
end
c = onCleanup(@() fclose(fid));
fprintf(fid, '%s\n', strjoin(names, '\t'));
for i = 1:height(T)
    row = cellfun(@(col) col{i}, cols, 'UniformOutput', false);
    fprintf(fid, '%s\n', strjoin(row, '\t'));
end
end

function c = cellText(x)
n = size(x, 1);
c = cell(n, 1);
for i = 1:n
    if iscell(x)
        v = x{i};
    else
        v = x(i, :);
    end
    if isstring(v)
        if ismissing(v)
            v = '';
        else
            v = char(v);
        end
    end
    if islogical(v)
        v = double(v);
    end
    if isnumeric(v)
        if isempty(v) || all(isnan(v))
            v = '';
        else
            v = strjoin(arrayfun(@(a) sprintf('%.6g', a), v, 'UniformOutput', false), ',');
        end
    end
    v = regexprep(char(v), '[\t\r\n]+', ' ');
    if isempty(v)
        v = 'n/a';
    end
    c{i} = v;
end
end
