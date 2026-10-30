function v = check_spm()
% CHECK_SPM  Error unless a supported SPM is on the path; return its version.
%   v = seecat.util.check_spm()     % e.g. 'SPM25 25.01.02'
%
% Supported: SPM12 r7771 or later, and SPM25 or later.

if ~exist('spm', 'file')
    error('SeeCAT:spm', 'SPM is not on the MATLAB path. Add SPM12 (r7771+) or SPM25 with addpath.');
end
[name, rel] = spm('Ver');
num = sscanf(name, 'SPM%d');
ok = false;
if isequal(num, 12)
    r = str2double(rel);
    ok = ~isnan(r) && r >= 7771;
elseif ~isempty(num) && num >= 25
    ok = true;
end
v = [name ' ' rel];
if ~ok
    error('SeeCAT:spm', 'Unsupported SPM version %s. SeeCAT needs SPM12 r7771+ or SPM25.', v);
end
end
