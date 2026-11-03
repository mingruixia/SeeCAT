function app = SeeCAT()
% SEECAT  Open the SeeCAT main window.
%   SeeCAT
%
% Needs MATLAB R2025a or later and SPM12 (r7771+) or SPM25 on the path. Batch use without the
% window: cfg = seecat.config('prep'); ...; seecat.run(cfg). The viewer:
% seecat.viewer. See Doc/design for the design and README.md for setup.
seecat.util.check_matlab();
seecat.util.check_spm();
a = seecat.gui.launcher();
if nargout
    app = a;
end
end
