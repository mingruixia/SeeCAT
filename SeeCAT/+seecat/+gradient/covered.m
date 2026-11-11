function ok = covered(runs, N, mode)
% COVERED  Which runs have a voxel of the node mask or atlas.
%   ok = seecat.gradient.covered(runs, N, mode)
%
% RUNS are the planned runs (seecat.bids.derivative_units), N the nodes
% (seecat.gradient.nodes) and MODE the mask mode (seecat.conn.mask_mode).
% The mask or atlas image (N.mask_file) and the run's brain mask are
% resampled to the grid of the run's BOLD series, as seecat.conn.load_series
% does for the analysis: the grid the brain mask is stored on does not
% matter. OK(r) is true when the mask has a voxel there: within the brain
% mask ('run', 'group'), or anywhere on the grid ('given'). A run in another
% space, or one that does not reach the mask, has none; without this check
% it would stop the analysis (load_series) or empty the group mask. Of the
% BOLD series only the header is read (seecat.io.nii_grid).
ok = false(size(runs));
keys = {};
masks = {};                                        % the mask on each BOLD grid met so far
for r = 1:numel(runs)
    V = seecat.io.nii_grid(runs(r).bold);
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
        B = logical(seecat.io.read_nii(runs(r).mask, 'Ref', V));
        B = B(:, :, :, 1);
        ok(r) = any(masks{k}(:) & B(:));
    end
end
end
