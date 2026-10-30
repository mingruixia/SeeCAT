function [ent, suffix, ext] = parse_name(name)
% PARSE_NAME  Split a BIDS file name into entities, suffix and extension.
%   [ent, suffix, ext] = seecat.bids.parse_name('sub-01_task-rest_run-1_bold.nii.gz')
%   % ent.sub = '01', ent.task = 'rest', ent.run = '1'; suffix 'bold'; ext '.nii.gz'
%
% A path is accepted; only its file name is used. ENT is [] when NAME is
% not a valid BIDS name.

[~, n, e] = fileparts(char(name));
name = [n e];
ent = [];
suffix = '';
ext = '';
dot = find(name == '.', 1);
if isempty(dot)
    return
end
parts = strsplit(name(1:dot-1), '_');
if isempty(regexp(parts{end}, '^[a-zA-Z0-9]+$', 'once'))
    return
end
e = struct();
for i = 1:numel(parts) - 1
    kv = regexp(parts{i}, '^([a-zA-Z0-9]+)-([a-zA-Z0-9]+)$', 'tokens', 'once');
    if isempty(kv)
        return
    end
    e.(kv{1}) = kv{2};
end
ent = e;
suffix = parts{end};
ext = name(dot:end);
end
