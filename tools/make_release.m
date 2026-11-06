function zipFile = make_release(varargin)
% MAKE_RELEASE  Build the SeeCAT release zip from the committed files.
%   make_release()                          % build/SeeCAT-<version>.zip
%   make_release('out', 'D:/build', 'cache', 'D:/data/SeeCAT_tools/dcm2niix/v1.0.20260724')
%
% Run from any folder with SeeCAT/ on the path. The zip holds the files
% committed at HEAD (git archive), without tools/ and the 1.0 baseline
% scripts, plus dcm2niix for Windows, macOS and Linux in
% external/dcm2niix/<win|mac|lnx>/. Each dcm2niix zip is taken from CACHE
% when it is there, otherwise downloaded from the dcm2niix GitHub release,
% and is refused unless its size and SHA-256 match the values below.
% SHA256SUMS.txt is written next to the zip.
%
% Options:
%   'out'        output folder (default: <repo>/build)
%   'cache'      folder with dcm2niix_<win|mac|lnx>.zip (default: <out>/cache)
%   'version'    version written into the release (default: seecat.version())
%   'platforms'  dcm2niix platforms to bundle (default: {'win','mac','lnx'})
%   'dirty'      true to allow uncommitted changes (they are NOT included)

repo = fileparts(fileparts(mfilename('fullpath')));
p = inputParser;
p.addParameter('out', fullfile(repo, 'build'));
p.addParameter('cache', '');
p.addParameter('version', seecat.version());
p.addParameter('platforms', {'win', 'mac', 'lnx'});
p.addParameter('dirty', false);
p.parse(varargin{:});
o = p.Results;
if isempty(o.cache)
    o.cache = fullfile(o.out, 'cache');
end
ver = char(o.version);

% dcm2niix v1.0.20260724, checked against the GitHub release assets
tag = 'v1.0.20260724';
dcm = struct( ...
    'plat', {'win', 'mac', 'lnx'}, ...
    'size', {1196271, 930002, 947680}, ...
    'sha256', {'8310549ef7340b1b169c26f4721aeac69423fd73643fbbd22eec47b36cc70ada', ...
               'd393006dd1edfba4013bc4b8eccc875b23d611ecbc53fda5a5542f629591008f', ...
               '2916a7bc64511eb20fb976a994799183cc1bfdd03395bf5d8edef54a58dee06f'});

[commit, dirty] = gitState(repo);
if dirty && ~o.dirty
    error('release:dirty', 'Uncommitted changes in %s. Commit them, or pass ''dirty'', true.', repo);
end

name = ['SeeCAT-' ver];
stage = fullfile(o.out, name);
if exist(stage, 'dir')
    rmdir(stage, 's');
end
mkdir(stage);
for d = {o.out, o.cache}
    if ~exist(d{1}, 'dir'), mkdir(d{1}); end
end

% committed files only
tarFile = fullfile(o.out, [name '.tar']);
git(repo, sprintf('archive --format=tar -o "%s" HEAD', tarFile));
untar(tarFile, stage);
delete(tarFile);
for drop = {'tools', 'tests', '.gitignore', '.gitattributes', 'Doc/description.docx', 'Doc/manual/src', 'pax_global_header'}
    f = fullfile(stage, drop{1});
    if exist(f, 'dir')
        rmdir(f, 's');
    elseif exist(f, 'file')
        delete(f);
    end
end

% the PDF manuals: built by Doc/manual/src/build.py --pdf, not kept in git
for f = {'SeeCAT_Manual_EN.pdf', 'SeeCAT_Manual_ZH.pdf'}
    src = fullfile(repo, 'Doc', 'manual', f{1});
    if ~exist(src, 'file')
        error('release:manual', 'Missing %s: run python Doc/manual/src/build.py --pdf first.', src);
    end
    copyfile(src, fullfile(stage, 'Doc', 'manual', f{1}));
end

% version stamp
vf = fullfile(stage, 'SeeCAT', '+seecat', 'version.m');
txt = fileread(vf);
txt = regexprep(txt, 'v = ''[^'']*'';', sprintf('v = ''%s'';', ver), 'once');
writeText(vf, txt);
writeText(fullfile(stage, 'BUILD.txt'), sprintf('SeeCAT %s\ncommit %s\nbuilt %s\ndcm2niix %s (%s)\n', ...
    ver, commit, datestr(now, 'yyyy-mm-dd HH:MM'), tag, strjoin(o.platforms, ', ')));

% dcm2niix
for k = 1:numel(o.platforms)
    a = dcm(strcmp({dcm.plat}, o.platforms{k}));
    if isempty(a)
        error('release:platform', 'Unknown platform %s.', o.platforms{k});
    end
    z = fullfile(o.cache, ['dcm2niix_' a.plat '.zip']);
    if ~exist(z, 'file')
        url = sprintf('https://github.com/rordenlab/dcm2niix/releases/download/%s/dcm2niix_%s.zip', tag, a.plat);
        fprintf('Downloading %s\n', url);
        websave(z, url);
    end
    info = dir(z);
    h = sha256(z);
    if info.bytes ~= a.size || ~strcmp(h, a.sha256)
        error('release:hash', '%s does not match the %s release (%d bytes, SHA-256 %s).', z, tag, info.bytes, h);
    end
    dest = fullfile(stage, 'external', 'dcm2niix', a.plat);
    unzip(z, dest);
    fprintf('dcm2niix %s: %s\n', a.plat, strjoin(sort({dirFiles(dest).name}), ', '));
end

zipFile = fullfile(o.out, [name '.zip']);
if exist(zipFile, 'file')
    delete(zipFile);
end
old = cd(o.out);                                 % zip stores paths relative to here
restore = onCleanup(@() cd(old));
zip(zipFile, name);
clear restore
writeText(fullfile(o.out, 'SHA256SUMS.txt'), sprintf('%s  %s\n', sha256(zipFile), [name '.zip']));
info = dir(zipFile);
fprintf('%s (%.1f MB) from %s\n', zipFile, info.bytes / 2^20, commit);
end

function [commit, dirty] = gitState(repo)
commit = strtrim(git(repo, 'rev-parse --short HEAD'));
dirty = ~isempty(strtrim(git(repo, 'status --porcelain --untracked-files=no')));
end

function out = git(repo, args)
[st, out] = system(sprintf('git -C "%s" %s', repo, args));
if st ~= 0
    error('release:git', 'git %s failed:\n%s', args, out);
end
end

function h = sha256(file)
fid = fopen(file, 'r');
bytes = fread(fid, Inf, '*uint8');
fclose(fid);
md = java.security.MessageDigest.getInstance('SHA-256');
md.update(bytes);
d = typecast(md.digest(), 'uint8');
h = lower(reshape(dec2hex(d, 2).', 1, []));
end

function f = dirFiles(d)
f = dir(d);
f = f(~[f.isdir]);
end

function writeText(file, txt)
fid = fopen(file, 'w');
fwrite(fid, txt, 'char');
fclose(fid);
end
