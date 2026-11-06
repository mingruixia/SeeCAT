function [c, key] = canonical_path(f)
% CANONICAL_PATH  Absolute path without '.', '..', links or a trailing separator.
%   [c, key] = seecat.util.canonical_path(f)
%
% A relative F is taken from MATLAB's current folder (Java alone would use
% the folder MATLAB started in). KEY compares paths: forward slashes, and
% lower case on Windows and macOS, whose file systems ignore case.

f = char(f);
if ~(startsWith(f, {'/', '\'}) || ~isempty(regexp(f, '^[A-Za-z]:', 'once')))
    f = fullfile(pwd, f);
end
c = char(java.io.File(f).getCanonicalPath());
if numel(c) > 3
    c = regexprep(c, '[\\/]+$', '');
end
key = strrep(c, '\', '/');
if ispc || ismac
    key = lower(key);
end
end
