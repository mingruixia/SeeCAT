function T = motion_regressors(rp)
% MOTION_REGRESSORS  The 24 Friston motion regressors with fMRIPrep names.
%   T = seecat.denoise.motion_regressors(rp)
%
% RP is T x 6 (trans_x/y/z in mm, rot_x/y/z in radians). T is a table with
% trans_x, trans_x_derivative1, trans_x_power2, trans_x_derivative1_power2,
% ... for all six parameters. The first row of a derivative is NaN (n/a),
% as in fMRIPrep; seecat.denoise.select_regressors sets it to 0.

names = {'trans_x', 'trans_y', 'trans_z', 'rot_x', 'rot_y', 'rot_z'};
T = table();
for j = 1:6
    x = rp(:, j);
    d = [NaN; diff(x)];
    n = names{j};
    T.(n) = x;
    T.([n '_derivative1']) = d;
    T.([n '_power2']) = x .^ 2;
    T.([n '_derivative1_power2']) = d .^ 2;
end
end
