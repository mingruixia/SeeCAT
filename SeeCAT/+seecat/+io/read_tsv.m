function T = read_tsv(file)
% READ_TSV  Read a BIDS-style TSV file into a table ("n/a" becomes missing).
%   T = seecat.io.read_tsv('sub-01_task-rest_desc-confounds_timeseries.tsv')
%
% Column names are kept exactly as in the header. A column whose values
% are all numbers or n/a is numeric, with NaN for n/a.

if ~exist(file, 'file')
    error('SeeCAT:io', 'File not found: %s', file);
end
opts = detectImportOptions(file, 'FileType', 'text', 'Delimiter', '\t');
opts.VariableNamingRule = 'preserve';
opts = setvaropts(opts, opts.VariableNames, 'TreatAsMissing', 'n/a');
opts.DataLines = [2 Inf];
T = readtable(file, opts);
end
