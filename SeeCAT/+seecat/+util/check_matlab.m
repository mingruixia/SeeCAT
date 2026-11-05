function check_matlab()
% CHECK_MATLAB  Note (once per session) when MATLAB is older than R2025a.
%   seecat.util.check_matlab()
%
% SeeCAT is developed and tested on R2025a. Older releases are not
% tested; SeeCAT still runs on them, and says so once.

persistent noted
if ~isempty(noted)
    return
end
noted = true;
older = false;
try
    older = isMATLABReleaseOlderThan('R2025a');
catch                                             % before R2020b
    try
        older = verLessThan('matlab', '25.1'); %#ok<VERLESSMATLAB>
    catch
    end
end
if older
    warning('SeeCAT:matlab', ['SeeCAT is developed and tested on MATLAB R2025a; this is R%s, ' ...
        'which has not been tested. If something fails, please try R2025a or later.'], ...
        version('-release'));
end
end
