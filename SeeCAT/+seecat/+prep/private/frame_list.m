function c = frame_list(f)
% FRAME_LIST  SPM-style 'file,k' list of every volume in a 3D/4D .nii.
n = numel(spm_vol(f));
c = arrayfun(@(k) sprintf('%s,%d', f, k), (1:n)', 'UniformOutput', false);
end
