function e = iqm_efc(img, frame)
% IQM_EFC  Entropy focus criterion (Atkinson et al. 1997), as MRIQC's efc.
%   e = seecat.qc.iqm_efc(img, frame)    % FRAME: voxels left out ([] = none)
x = double(img(:));
if nargin > 1 && ~isempty(frame)
    x = x(~frame(:));
end
n = numel(x);
emax = n * (1 / sqrt(n)) * log(1 / sqrt(n));
b = sqrt(sum(x .^ 2));
e = round((1 / emax) * sum((x / b) .* log((x + 1e-16) / b)), 4);
end
