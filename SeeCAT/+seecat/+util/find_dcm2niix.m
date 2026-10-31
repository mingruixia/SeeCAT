function [exe, ver] = find_dcm2niix(given)
% FIND_DCM2NIIX  Locate dcm2niix and return its path and version.
%   [exe, ver] = seecat.util.find_dcm2niix()
%   [exe, ver] = seecat.util.find_dcm2niix('C:/tools/dcm2niix.exe')
%
% Looks, in order, at: the given path; the SEECAT_DCM2NIIX environment
% variable; the copy bundled with SeeCAT (external/dcm2niix/<win|mac|lnx>/);
% the system PATH. VER is e.g. 'v1.0.20260724'. Versions older than
% v1.0.20220720 are refused.

minVersion = 'v1.0.20220720';
if ispc
    name = 'dcm2niix.exe';
    plat = 'win';
elseif ismac
    name = 'dcm2niix';
    plat = 'mac';
else
    name = 'dcm2niix';
    plat = 'lnx';
end
here = fileparts(fileparts(fileparts(mfilename('fullpath'))));     % SeeCAT/
candidates = {};
if nargin > 0 && ~isempty(given)
    candidates{end+1} = char(given);
end
if ~isempty(getenv('SEECAT_DCM2NIIX'))
    candidates{end+1} = getenv('SEECAT_DCM2NIIX');
end
candidates{end+1} = fullfile(fileparts(here), 'external', 'dcm2niix', plat, name);
candidates{end+1} = name;                                         % on the PATH

exe = '';
for i = 1:numel(candidates)
    c = candidates{i};
    if exist(c, 'dir')
        c = fullfile(c, name);
    end
    [st, out] = system(sprintf('"%s" -v', c));
    tok = regexp(out, 'v\d+\.\d+\.\d{8}', 'match', 'once');
    if ~isempty(tok) && (st == 0 || contains(out, 'dcm2niiX'))
        exe = c;
        ver = tok;
        break
    end
end
if isempty(exe)
    error('SeeCAT:dcm2niix', ['dcm2niix not found. Tried: %s. Install it from ' ...
        'https://github.com/rordenlab/dcm2niix/releases, or set SEECAT_DCM2NIIX.'], strjoin(candidates, '; '));
end
if versionNumber(ver) < versionNumber(minVersion)
    error('SeeCAT:dcm2niix', 'dcm2niix %s at %s is too old; SeeCAT needs %s or later.', ver, exe, minVersion);
end
end

function n = versionNumber(v)
n = str2double(regexp(v, '\d{8}$', 'match', 'once'));
end
