function I = inference(c, mask, hdr, S, opt)
% INFERENCE  Thresholds, surviving voxels and cluster table for one contrast.
%   I = seecat.stat.inference(c, mask, hdr, S, opt)
%
% C is one element of G.con (seecat.stat.glm), MASK the 3D analysis mask,
% HDR its header, S the smoothness (seecat.stat.smoothness). OPT fields:
%   method  'cluster_fwe', 'voxel_fwe', 'voxel_fdr' or 'tfce_fwe'
%   alpha   familywise / FDR level (already split for two tails by the caller)
%   cdt_p   cluster-forming threshold, uncorrected p (cluster_fwe)
%   perm    tfce_fwe: this contrast's element of seecat.stat.permutation
% Random field theory and FDR use SPM's functions on SPM's definitions, so
% the numbers equal SPM's results table for the same model (decision S1):
% spm_u / spm_uc (heights), spm_P (cluster and peak p, stationary fields),
% 18-connectivity (spm_bwlabel), local maxima from spm_max.
%
% I fields: method, height (statistic threshold), extent (minimum cluster
% size in voxels, cluster_fwe), keep (logical over mask voxels), label
% (3D cluster index of surviving clusters), table (every cluster above the
% height threshold, as SPM lists them: one row per reported maximum, with
% 'survives' true for clusters that pass the method).

STAT = upper(c.type);
df = c.df;
if STAT == 'T'
    df = [1 df(2)];
end
idx = find(mask);
stat = c.stat(:);
I.method = opt.method;
I.extent = 1;
switch opt.method
    case 'voxel_fwe'
        u = spm_uc(opt.alpha, df, STAT, S.R, 1, S.nVox);
        keep = stat >= u;
    case 'voxel_fdr'
        p = sort(c.p(:));
        m = numel(p);
        k = find(p <= (1:m)' / m * opt.alpha, 1, 'last');   % Benjamini-Hochberg
        if isempty(k)
            u = Inf;
            keep = false(size(stat));
        else
            u = statFromP(p(k), df, STAT);
            keep = c.p(:) <= p(k);
        end
    case 'cluster_fwe'
        u = spm_u(opt.cdt_p, df, STAT);
        keep = stat >= u;
        % smallest extent with cluster FWE p < alpha
        k = 1;
        while spm_P(1, k * S.V2R, u, df, STAT, S.R, 1, S.nVox) >= opt.alpha && k < S.nVox
            k = k + 1;
        end
        I.extent = k;
    case 'tfce_fwe'
        keep = opt.perm.p_fwe(:) < opt.alpha & stat > 0;
        u = min([stat(keep); Inf]);              % the lowest surviving statistic
    otherwise
        error('SeeCAT:stat', 'Unknown inference method "%s".', opt.method);
end
I.height = u;

vol = zeros(size(mask));
vol(idx(keep)) = 1;
[lab, nc] = spm_bwlabel(vol, 18);
sizes = accumarray(lab(lab > 0), 1, [nc 1]);
if strcmp(opt.method, 'cluster_fwe')
    Pk = arrayfun(@(k) spm_P(1, k * S.V2R, u, df, STAT, S.R, 1, S.nVox), sizes);
    survive = find(Pk < opt.alpha);
else
    survive = (1:nc)';
end
newLab = zeros(nc, 1);
newLab(survive) = 1:numel(survive);
label = zeros(size(mask));
label(lab > 0) = newLab(lab(lab > 0));
I.label = label;
I.keep = label(idx) > 0;
if strcmp(opt.method, 'tfce_fwe')
    I.table = tfceTable(c, stat, opt.perm.p_fwe(:), mask, hdr, label);
    return
end
I.table = clusterTable(c, stat, mask, hdr, lab, S, u, df, STAT);
I.table.survives = ismember(I.table.cluster, survive);
I.table.cluster = newLab(I.table.cluster) .* I.table.survives;
end

function u = statFromP(p, df, STAT)
if STAT == 'T'
    u = spm_invTcdf(1 - p, df(2));
else
    u = spm_invFcdf(1 - p, df);
end
end

function T = clusterTable(c, stat, mask, hdr, label, S, u, df, STAT)
% SPM's table: per cluster, size, cluster p (FWE, uncorrected), then up to
% 3 local maxima more than 8 mm apart: statistic, Z, peak p (FWE, uncorrected), mm
names = {'cluster', 'voxels', 'p_cluster_fwe', 'p_cluster_unc', 'peak_stat', 'peak_z', ...
    'p_peak_fwe', 'p_peak_unc', 'x', 'y', 'z'};
T = cell2table(cell(0, numel(names)), 'VariableNames', names);
nc = max(label(:));
if nc == 0
    return
end
vol = zeros(size(mask));
vol(mask) = stat;
in = find(label > 0);
[i, j, k] = ind2sub(size(mask), in);
[~, Z, XYZ] = spm_max(vol(in)', [i j k]');
mm = hdr.mat(1:3, :) * [XYZ; ones(1, size(XYZ, 2))];
clusterOf = label(sub2ind(size(mask), XYZ(1, :), XYZ(2, :), XYZ(3, :)));
rows = {};
order = sortClusters(label, vol, nc);
for cl = order
    nVox = nnz(label == cl);
    K = nVox * S.V2R;
    [Pk, Pn] = spm_P(1, K, u, df, STAT, S.R, 1, S.nVox);
    m = find(clusterOf == cl);
    [~, o] = sort(Z(m), 'descend');
    m = m(o);
    chosen = [];
    for q = m
        if isempty(chosen) || all(sqrt(sum((mm(:, chosen) - mm(:, q)) .^ 2, 1)) > 8)
            chosen(end+1) = q; %#ok<AGROW>
        end
        if numel(chosen) == 3
            break
        end
    end
    for q = chosen
        U = Z(q);
        pu = spm_P(1, 0, U, df, STAT, 1, 1, S.nVox);
        pf = spm_P(1, 0, U, df, STAT, S.R, 1, S.nVox);
        zq = -spm_invNcdf(max(pu, realmin));
        cv = {NaN, NaN, NaN};                  % cluster columns only on its first row
        if q == chosen(1)
            cv = {nVox, Pk, Pn};
        end
        rows(end+1, :) = [{cl}, cv, {U, zq, pf, pu, mm(1, q), mm(2, q), mm(3, q)}]; %#ok<AGROW>
    end
end
T = cell2table(rows, 'VariableNames', names);
end

function order = sortClusters(label, vol, nc)
% By peak statistic, highest first (as SPM lists them)
peak = zeros(nc, 1);
for cl = 1:nc
    peak(cl) = max(vol(label == cl));
end
[~, order] = sort(peak, 'descend');
order = order(:)';
end

function T = tfceTable(c, stat, pfwe, mask, hdr, label)
% Surviving clusters (18-connectivity) with up to 3 local maxima more than
% 8 mm apart: statistic, Z, TFCE FWE p of the voxel, mm
names = {'cluster', 'voxels', 'peak_stat', 'peak_z', 'p_peak_tfce_fwe', 'x', 'y', 'z'};
T = cell2table(cell(0, numel(names)), 'VariableNames', names);
T.survives = false(0, 1);
nc = max(label(:));
if nc == 0
    return
end
vol = zeros(size(mask));
vol(mask) = stat;
pv = ones(size(mask));
pv(mask) = pfwe;
zv = zeros(size(mask));
zv(mask) = c.z;
in = find(label > 0);
[i, j, k] = ind2sub(size(mask), in);
[~, ~, XYZ] = spm_max(vol(in)', [i j k]');
lin = sub2ind(size(mask), XYZ(1, :), XYZ(2, :), XYZ(3, :));
mm = hdr.mat(1:3, :) * [XYZ; ones(1, size(XYZ, 2))];
clusterOf = label(lin);
rows = {};
for cl = sortClusters(label, vol, nc)
    m = find(clusterOf == cl);
    [~, o] = sort(vol(lin(m)), 'descend');
    m = m(o);
    chosen = [];
    for q = m
        if isempty(chosen) || all(sqrt(sum((mm(:, chosen) - mm(:, q)) .^ 2, 1)) > 8)
            chosen(end+1) = q; %#ok<AGROW>
        end
        if numel(chosen) == 3
            break
        end
    end
    for q = chosen
        nv = NaN;
        if q == chosen(1)
            nv = nnz(label == cl);
        end
        rows(end+1, :) = {cl, nv, vol(lin(q)), zv(lin(q)), pv(lin(q)), mm(1, q), mm(2, q), mm(3, q)}; %#ok<AGROW>
    end
end
T = cell2table(rows, 'VariableNames', names);
T.survives = true(height(T), 1);
end
