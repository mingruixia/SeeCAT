function [D, maps] = degree(Y, xyz, opt)
% DEGREE  Voxel-wise degree (and strength) of the correlation network.
%   [D, maps] = seecat.conn.degree(Y, xyz, opt)
%
% Y is T x V (good frames only, one column per voxel of the mask), XYZ is
% 3 x V voxel coordinates in mm. OPT fields (defaults in brackets):
%   threshold        r threshold; values >= it count [0.2]
%   sign             cellstr of 'positive', 'absolute', 'negative' [{'positive'}]
%   weight           cellstr of 'binary' (degree), 'weighted' (strength)
%                    [{'binary', 'weighted'}]
%   exclude_local_mm connections shorter than this are ignored; 0 = off [0]
%   distance_edges   bin edges in mm, e.g. [0 75 Inf]; a connection of
%                    length d is in bin k when edges(k) < d <= edges(k+1)
%                    [[0 Inf]]
%   block            voxels per block of the correlation matrix [1000]
% D is V x K, one column per map; MAPS(k) has sign, weight, lo, hi.
%
% Same definition as SeeCAT 1.0's VoxDeg: r from z-scored series, sign
% applied (absolute: |r|; negative: -r, then < 0 set to 0), r < threshold
% set to 0, binary counts what is left, weighted sums it. The voxel itself
% is excluded by distance (d = 0 is in no bin). Voxels without variance
% have no connections. Correlations are computed a block of rows at a
% time, so memory is block x V.

opt = defaults(opt);
[T, V] = size(Y);
Z = double(Y) - mean(Y, 1);
sd = std(Z, 0, 1);
dead = ~(sd > 0) | any(~isfinite(Z), 1);
Z = Z ./ sd;
Z(:, dead) = 0;
Z = Z / sqrt(T - 1);                          % so that Z' * Z = r

maps = struct('sign', {}, 'weight', {}, 'lo', {}, 'hi', {});
for s = opt.sign
    for w = opt.weight
        for b = 1:numel(opt.distance_edges) - 1
            maps(end+1) = struct('sign', s{1}, 'weight', w{1}, ...
                'lo', opt.distance_edges(b), 'hi', opt.distance_edges(b + 1)); %#ok<AGROW>
        end
    end
end
D = zeros(V, numel(maps));
needDist = opt.exclude_local_mm > 0 || ~isequal(opt.distance_edges, [0 Inf]);
xyz = double(xyz);
for j0 = 1:opt.block:V
    j = j0:min(j0 + opt.block - 1, V);
    R = Z(:, j)' * Z;                          % numel(j) x V
    if needDist
        dist = sqrt(max(sum(xyz(:, j) .^ 2, 1)' + sum(xyz .^ 2, 1) - 2 * xyz(:, j)' * xyz, 0));
        local = dist < opt.exclude_local_mm;
    else
        R(sub2ind(size(R), 1:numel(j), j)) = 0;   % self (d = 0, in no bin)
    end
    for s = unique({maps.sign}, 'stable')
        switch s{1}
            case 'positive'
                S = R;
            case 'absolute'
                S = abs(R);
            case 'negative'
                S = -R;
        end
        S(S < opt.threshold) = 0;
        if needDist
            S(local) = 0;
        end
        for k = find(strcmp({maps.sign}, s{1}))
            m = maps(k);
            if needDist
                in = dist > m.lo & dist <= m.hi;
            else
                in = true;
            end
            if strcmp(m.weight, 'binary')
                D(j, k) = sum((S > 0) & in, 2);
            else
                D(j, k) = sum(S .* in, 2);
            end
        end
    end
end
D(dead, :) = 0;
end

function opt = defaults(opt)
d = struct('threshold', 0.2, 'sign', {{'positive'}}, 'weight', {{'binary', 'weighted'}}, ...
    'exclude_local_mm', 0, 'distance_edges', [0 Inf], 'block', 1000);
for f = fieldnames(d)'
    if ~isfield(opt, f{1}) || isempty(opt.(f{1}))
        opt.(f{1}) = d.(f{1});
    end
end
opt.sign = cellstr(opt.sign);
opt.weight = cellstr(opt.weight);
opt.distance_edges = opt.distance_edges(:)';
end
