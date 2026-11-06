function h = code_fingerprint()
% CODE_FINGERPRINT  Hash of SeeCAT's computing code and bundled templates.
%   h = seecat.util.code_fingerprint()
%
% The contents of every .m file of the +seecat package except the window
% code (+gui, +view), and the name, size and date of every file in
% templates/. seecat.run stores it with each finished unit and redoes the
% unit when it changes, so results of an older SeeCAT (even with the same
% version string, e.g. 2.0.0-dev) are not reused. Computed once per MATLAB
% session and folder.

persistent cache
root = fileparts(fileparts(mfilename('fullpath')));        % +seecat
if isstruct(cache) && strcmp(cache.root, root)
    h = cache.h;
    return
end
m = dir(fullfile(root, '**', '*.m'));
rel = strrep(fullfile({m.folder}, {m.name}), [root filesep], '');
keep = ~startsWith(rel, {['+gui' filesep], ['+view' filesep]});
m = m(keep);
rel = sort(rel(keep));
parts = cell(numel(rel), 1);
for i = 1:numel(rel)
    parts{i} = [strrep(rel{i}, '\', '/') '|' seecat.util.file_md5(fullfile(root, rel{i}))];
end
t = dir(fullfile(fileparts(root), 'templates', '**', '*'));
t = t(~[t.isdir]);
tpl = arrayfun(@(d) sprintf('%s|%d|%.6f', d.name, d.bytes, d.datenum), t, 'UniformOutput', false);
h = seecat.util.hash(struct('code', {parts}, 'templates', {sort(tpl)}, 'n', numel(m)));
cache = struct('root', root, 'h', h);
end
