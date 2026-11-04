function m = iqm_morph(m, op, n)
% IQM_MORPH  Binary erosion, dilation or opening with scipy's default 3D
% structure (generate_binary_structure(3, 2): the 18 neighbours and centre).
%   m = seecat.qc.iqm_morph(m, 'erode' | 'dilate' | 'open' | 'close', n)
% N repeats the operation (default 1). Voxels outside the volume count as 0
% for erosion (scipy's border_value), so masks touching the edge shrink.
if nargin < 3, n = 1; end
K = ones(3, 3, 3);
K([1 3], [1 3], [1 3]) = 0;                         % no corners: 18-connectivity
s = sum(K(:));
switch op
    case 'erode'
        for i = 1:n, m = convn(double(m), K, 'same') >= s - 0.5; end
    case 'dilate'
        for i = 1:n, m = convn(double(m), K, 'same') > 0.5; end
    case 'open'
        m = seecat.qc.iqm_morph(seecat.qc.iqm_morph(m, 'erode', n), 'dilate', n);
    case 'close'
        m = seecat.qc.iqm_morph(seecat.qc.iqm_morph(m, 'dilate', n), 'erode', n);
end
m = logical(m);
end
