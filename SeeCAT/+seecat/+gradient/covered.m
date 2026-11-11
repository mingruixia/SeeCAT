function ok = covered(runs, N, mode)
% COVERED  Which runs have a voxel of the node mask or atlas.
%   ok = seecat.gradient.covered(runs, N, mode)
%
% RUNS are the planned runs (seecat.bids.derivative_units), N the nodes
% (seecat.gradient.nodes) and MODE the mask mode (seecat.conn.mask_mode).
% The mask or atlas image (N.mask_file) is resampled to the grid of each
% run's brain mask. OK(r) is true when it has a voxel there: within the
% brain mask ('run', 'group'), or anywhere on the grid ('given'). A run in
% another space, or one that does not reach the mask, has none; without
% this check it would stop the analysis (seecat.conn.load_series) or empty
% the group mask. Only the brain masks are read, not the BOLD series.
ok = false(size(runs));
keys = {};
masks = {};                                        % the mask on each grid met so far
for r = 1:numel(runs)
    [B, V] = seecat.io.read_nii(runs(r).mask);
    V = V(1);
    key = sprintf('%d,', V.dim(1:3), round(V.mat(:) * 1e4));
    k = find(strcmp(keys, key), 1);
    if isempty(k)
        m = seecat.io.read_nii(N.mask_file, 'Ref', V, 'Interp', 0) > 0;
        keys{end + 1} = key; %#ok<AGROW>
        masks{end + 1} = m(:, :, :, 1); %#ok<AGROW>
        k = numel(keys);
    end
    if strcmp(mode, 'given')
        ok(r) = any(masks{k}(:));
    else
        B = B(:, :, :, 1) > 0;
        ok(r) = any(masks{k}(:) & B(:));
    end
end
end
