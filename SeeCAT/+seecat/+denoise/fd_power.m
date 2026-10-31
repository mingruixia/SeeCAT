function fd = fd_power(rp)
% FD_POWER  Framewise displacement (Power et al. 2012).
%   fd = seecat.denoise.fd_power(rp)
%
% RP is T x 6: translations in mm, then rotations in radians (SPM rp_*.txt
% and fMRIPrep trans_*/rot_* use the same units). Rotations are converted
% to mm on a 50 mm sphere. fd(1) is NaN, as in fMRIPrep.

d = abs(diff(rp, 1, 1));
fd = [NaN; sum(d(:, 1:3), 2) + 50 * sum(d(:, 4:6), 2)];
end
