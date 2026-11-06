function [h, files] = input_fingerprint(unit, cfg)
% INPUT_FINGERPRINT  Hash of what a unit reads, to tell whether to redo it.
%   [h, files] = seecat.util.input_fingerprint(unit, cfg)
%
% Covers the unit as planned (its input files, the maps it selected, the
% participants' values joined to them, sidecar metadata, ...) and every
% existing file named anywhere in the unit or in the config CFG: seed and
% ROI images, analysis masks, atlases, image covariates, the participants
% table. A file up to 64 MB is identified by its contents (MD5), a larger
% one (BOLD series) by its size and modification time. A unit whose inputs
% were replaced, edited, added or left out by QC gets another fingerprint,
% so seecat.run redoes it instead of skipping it.
%
% FILES lists those files (canonical paths): seecat.run protects them, so
% no unit can write over or delete one of its own inputs.

if nargin < 2
    cfg = struct();
end
files = {};
collect(unit);
collect(cfg);
files = unique(files);
stats = cell(numel(files), 1);
for i = 1:numel(files)
    d = dir(files{i});
    if d.bytes <= 64 * 2^20
        stats{i} = sprintf('%s|%s', files{i}, seecat.util.file_md5(files{i}));
    else
        stats{i} = sprintf('%s|%d|%.6f', files{i}, d.bytes, d.datenum);
    end
end
h = seecat.util.hash(struct('unit', jsonencode(unit), 'files', {stats}, 'version', seecat.version()));

    function collect(v)
        if ischar(v) && isrow(v) && numel(v) < 1024
            % paths only (a bare word such as 'gm' could name a function on the MATLAB path)
            if any(v == '/' | v == '\') && exist(v, 'file') == 2 && ~isfolder(v)
                files{end+1} = seecat.util.canonical_path(v);
            end
        elseif isstring(v)
            for k = 1:numel(v)
                collect(char(v(k)));
            end
        elseif iscell(v)
            for k = 1:numel(v)
                collect(v{k});
            end
        elseif isstruct(v)
            for k = 1:numel(v)
                for f = fieldnames(v)'
                    collect(v(k).(f{1}));
                end
            end
        elseif istable(v)
            for c = v.Properties.VariableNames
                collect(v.(c{1}));
            end
        end
    end
end
