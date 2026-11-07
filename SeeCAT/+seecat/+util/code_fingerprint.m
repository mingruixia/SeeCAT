function h = code_fingerprint()
% CODE_FINGERPRINT  Hash of SeeCAT's computing code and bundled templates.
%   h = seecat.util.code_fingerprint()
%
% The contents of every .m file of the +seecat package except the window
% code (+gui, +view), and the name, size and date of every file in
% templates/. seecat.run stores it with each finished unit and redoes the
% unit when it changes, so results of an older SeeCAT (even with the same
% version string, e.g. 2.0.0-dev) are not reused.
%
% Each call lists the files (names, sizes, dates): the contents are read
% again only when that list changed, so an edit to the code in a running
% MATLAB session (or an update unpacked over the installation) is found
% at the next seecat.run, without restarting MATLAB.

persistent cache
root = fileparts(fileparts(mfilename('fullpath')));        % +seecat
m = dir(fullfile(root, '**', '*.m'));
rel = strrep(fullfile({m.folder}, {m.name}), [root filesep], '');
keep = ~startsWith(rel, {['+gui' filesep], ['+view' filesep]});
m = m(keep);
rel = rel(keep);
[rel, ord] = sort(rel);
m = m(ord);
t = dir(fullfile(fileparts(root), 'templates', '**', '*'));
t = t(~[t.isdir]);
tpl = sort(arrayfun(@(d) sprintf('%s|%d|%.6f', d.name, d.bytes, d.datenum), t, 'UniformOutput', false));
stamp = [strcat(rel(:), '|', arrayfun(@(d) sprintf('%d|%.8f', d.bytes, d.datenum), m(:), 'UniformOutput', false)); tpl(:)];
if isstruct(cache) && strcmp(cache.root, root) && isequal(cache.stamp, stamp)
    h = cache.h;
    return
end
parts = cell(numel(rel), 1);
for i = 1:numel(rel)
    parts{i} = [strrep(rel{i}, '\', '/') '|' seecat.util.file_md5(fullfile(root, rel{i}))];
end
h = seecat.util.hash(struct('code', {parts}, 'templates', {tpl}, 'n', numel(m)));
cache = struct('root', root, 'stamp', {stamp}, 'h', h);
end
