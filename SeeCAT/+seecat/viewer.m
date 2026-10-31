function app = viewer(varargin)
% VIEWER  Open the SeeCAT slice viewer.
%   seecat.viewer
%   seecat.viewer('group/PCC/PCC_contrast-pos_stat-t_statmap.nii.gz')
%   seecat.viewer(file1, file2, ...)
%   app = seecat.viewer(...)          % app.model is the seecat.view.Model
%
% The underlay follows the space of the first map (ch2 for IXI549Space, MNI
% 2009c for MNI152NLin2009cAsym; design gui.md, G5). Statistic maps from the
% stat pipeline (or 1.0 maps with a CAT header) can be thresholded by p
% with voxel/cluster FWE or FDR, using the same code as the stat pipeline.

m = seecat.view.Model();
for i = 1:nargin
    m.addLayer(varargin{i});
end
a = seecat.view.window(m);
if nargout
    app = a;
end
end
