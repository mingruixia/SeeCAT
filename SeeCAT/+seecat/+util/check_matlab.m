function check_matlab()
% CHECK_MATLAB  Error unless MATLAB is R2025a or later.
%   seecat.util.check_matlab()
%
% SeeCAT is developed and tested on R2025a only.

if isMATLABReleaseOlderThan('R2025a')
    error('SeeCAT:matlab', 'SeeCAT needs MATLAB R2025a or later; this is R%s.', version('-release'));
end
end
