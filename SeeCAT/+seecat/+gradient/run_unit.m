function result = run_unit(unit, cfg, log)
% RUN_UNIT  Gradients of every run, aligned, and the group reference.
%   result = seecat.gradient.run_unit(unit, cfg, log)
%
% 1. Node series of each run (mean of the run's brain-mask voxels in each
%    node; censored frames left out), kept in the work folder.
% 2. Per run: Pearson r between nodes, seecat.gradient.embed. With
%    align = 'group', Fisher z of r is also summed over runs.
% 3. Alignment (seecat.gradient.align): 'group' rotates each run to the
%    gradients of the group-mean matrix (tanh of the mean z) in one step;
%    'procrustes' aligns the runs to each other (generalized Procrustes);
%    'none' keeps each run's own gradients (their order and sign may differ
%    between runs).
% Writes per run *_desc-grad<k><tag>_connectivity.nii.gz (k = 1..n_maps) with
% a JSON sidecar (eigenvalues, variance explained), and in
% group/gradients<tag>/ the reference maps and a table of every run's
% eigenvalues. Steps 2 and 3 run on the parallel pool when there is one.

N = unit.nodes;
runs = unit.runs;
nr = numel(runs);
if ~exist(unit.work_dir, 'dir')
    mkdir(unit.work_dir);
end
log('%d run(s), %d nodes (%s); %s', nr, N.n, N.tag, memoryNote(N.n, cfg));
checkMemory(N.n, cfg);

% 1. node series
present = false(N.n, nr);
frames = zeros(nr, 2);
files = cell(nr, 1);
for r = 1:nr
    S = seecat.conn.load_series(runs(r), 'brain');
    [Yn, present(:, r)] = nodeSeries(S, N);
    frames(r, :) = [S.n_kept, S.n_frames];
    files{r} = fullfile(unit.work_dir, sprintf('nodes_%03d.mat', r));
    save(files{r}, 'Yn');
end
common = all(present, 2);
log('node series done; %d of %d nodes have data in every run', nnz(common), N.n);
if nnz(common) < cfg.n_components + 2
    error('SeeCAT:gradient', 'Only %d nodes have data in every run.', nnz(common));
end

% 2. gradients per run (and the group sum of z)
eo = struct('n_components', cfg.n_components, 'sparsity', cfg.sparsity, 'kernel', cfg.kernel, 'alpha', cfg.alpha);
G = cell(nr, 1);
L = zeros(nr, cfg.n_components);
group = strcmp(cfg.align, 'group');
Zsum = 0;
workers = poolWorkers(cfg);
t = tic;
parfor (r = 1:nr, workers)
    Yn = load(files{r}, 'Yn').Yn;
    R = corrNodes(Yn);
    [g, l] = seecat.gradient.embed(R, eo);
    G{r} = g;
    L(r, :) = l;
    if group
        z = R(common, common);
        z = atanh(min(max(z, -0.999999), 0.999999));
        Zsum = Zsum + z;
    end
end
log('gradients of %d run(s) in %.0f s (%d worker(s))', nr, toc(t), workers);

% 3. alignment
ref = [];
switch cfg.align
    case 'group'
        Rm = tanh(Zsum / nr);
        clear Zsum
        Gr = seecat.gradient.embed(Rm, eo);
        clear Rm
        ref = nan(N.n, cfg.n_components);
        ref(common, :) = Gr;
        A = cell(nr, 1);
        for r = 1:nr
            A{r} = alignTo(G{r}, ref);
        end
    case 'procrustes'
        [A, ref] = seecat.gradient.align(G);
    otherwise
        A = G;
end

% outputs
opt = struct('output_dir', cfg.output_dir, 'work_dir', unit.work_dir, 'manifest', unit.manifest);
base = struct('Nodes', cfg.nodes, 'NodeTag', N.tag, 'Kernel', cfg.kernel, 'Sparsity', cfg.sparsity, ...
    'Alpha', cfg.alpha, 'Components', cfg.n_components, 'Alignment', cfg.align, ...
    'Software', ['SeeCAT ' seecat.version()]);
if strcmp(cfg.nodes, 'voxels')
    base.NodeSizeMM = cfg.node_size;
    base.Mask = cfg.mask;
else
    base.Atlas = cfg.atlas;
end
for r = 1:nr
    src = ['bids:seecat:' strrep(runs(r).bold(numel(cfg.input_dir) + 2:end), '\', '/')];
    meta = base;
    meta.Lambdas = L(r, :);
    meta.VarianceExplained = L(r, :) / sum(L(r, :));
    meta.FramesUsed = frames(r, 1);
    meta.FramesTotal = frames(r, 2);
    meta.Sources = {src};
    for k = 1:cfg.n_maps
        meta.Component = k;
        f = fullfile(unit.work_dir, sprintf('run%03d_grad%d.nii', r, k));
        writeMap(A{r}(:, k), N, f);
        rel = seecat.bids.deriv_name(runs(r).bold, 'desc', sprintf('grad%d%s', k, N.tag), ...
            'suffix', 'connectivity', 'ext', '.nii.gz');
        seecat.util.publish_output(f, rel, meta, opt);
    end
    if strcmp(N.kind, 'atlas')                    % parcel values as a table too
        T = array2table([double(N.labels), A{r}(:, 1:cfg.n_maps)], 'VariableNames', ...
            [{'label'}, arrayfun(@(k) sprintf('grad%d', k), 1:cfg.n_maps, 'UniformOutput', false)]);
        tf = fullfile(unit.work_dir, sprintf('run%03d.tsv', r));
        seecat.io.write_tsv(T, tf);
        rel = seecat.bids.deriv_name(runs(r).bold, 'desc', ['grad' N.tag], 'suffix', 'connectivity', 'ext', '.tsv');
        seecat.util.publish_output(tf, rel, [], opt);
    end
end
gdir = fullfile('group', ['gradients' N.tag]);
if ~isempty(ref)
    for k = 1:cfg.n_maps
        f = fullfile(unit.work_dir, sprintf('reference_grad%d.nii', k));
        writeMap(ref(:, k), N, f);
        m = base;
        m.Component = k;
        m.Description = sprintf('reference gradient %d (%s alignment)', k, cfg.align);
        seecat.util.publish_output(f, fullfile(gdir, sprintf('gradients%s_desc-grad%d_reference.nii.gz', N.tag, k)), m, opt);
    end
end
ids = arrayfun(@(u) u.id, runs, 'UniformOutput', false);
T = [table(ids(:), 'VariableNames', {'run'}), array2table(L, 'VariableNames', ...
    arrayfun(@(k) sprintf('lambda%d', k), 1:cfg.n_components, 'UniformOutput', false))];
T.var_explained_1 = L(:, 1) ./ sum(L, 2);
if ~isempty(ref)                                  % similarity of each run's first gradient to the reference
    T.r_grad1_reference = cellfun(@(a) corrOk(a(:, 1), ref(:, 1)), A(:));
end
tf = fullfile(unit.work_dir, 'lambdas.tsv');
seecat.io.write_tsv(T, tf);
seecat.util.publish_output(tf, fullfile(gdir, sprintf('gradients%s_lambdas.tsv', N.tag)), [], opt);
result = struct('n_runs', nr, 'n_nodes', N.n, 'n_common_nodes', nnz(common), ...
    'var_explained_1', mean(T.var_explained_1));
end

function [Yn, present] = nodeSeries(S, N)
% Mean series of the brain-mask voxels in each node (columns), kept frames
Y = double(S.Y);
if strcmp(N.kind, 'voxels')
    p = N.mat \ [S.xyz; ones(1, size(S.xyz, 2))];
    p = round(p(1:3, :));
    in = all(p >= 1 & p <= N.dim(:), 1);
    lin = zeros(1, size(p, 2));
    lin(in) = sub2ind(N.dim, p(1, in), p(2, in), p(3, in));
    [~, node] = ismember(lin, N.index);
else
    lab = zeros(1, size(S.xyz, 2));
    p = N.mat \ [S.xyz; ones(1, size(S.xyz, 2))];
    p = round(p(1:3, :));
    in = all(p >= 1 & p <= N.dim(:), 1);
    lab(in) = N.vol(sub2ind(N.dim, p(1, in), p(2, in), p(3, in)));
    [~, node] = ismember(lab, N.labels);
end
use = node > 0 & all(isfinite(Y), 1) & std(Y, 0, 1) > 0;
M = sparse(find(use), node(use), 1, size(Y, 2), N.n);
cnt = full(sum(M, 1));
present = cnt(:) > 0;
Yn = (Y * M) ./ max(cnt, 1);
Yn(:, ~present) = 0;
Yn = single(Yn);
end

function R = corrNodes(Yn)
Z = double(Yn) - mean(Yn, 1);
s = sqrt(sum(Z .^ 2, 1));
ok = s > 0;
Z(:, ok) = Z(:, ok) ./ s(ok);
Z(:, ~ok) = 0;
if size(Z, 2) > 8000
    Z = single(Z);
end
R = Z' * Z;
end

function a = alignTo(g, ref)
ok = all(isfinite(g), 2) & all(isfinite(ref), 2);
[u, ~, v] = svd((ref(ok, :)' * g(ok, :))');
a = g * (u * v');
end

function c = corrOk(a, b)
ok = isfinite(a) & isfinite(b);
c = corrcoef(a(ok), b(ok));
c = c(1, 2);
end

function writeMap(g, N, f)
vol = zeros(N.dim, 'single');
g(~isfinite(g)) = 0;
if strcmp(N.kind, 'voxels')
    vol(N.index) = g;
else
    [~, k] = ismember(N.vol, N.labels);
    vol(k > 0) = g(k(k > 0));
end
seecat.io.write_nii(vol, struct('dim', N.dim, 'mat', N.mat), f);
end

function w = poolWorkers(cfg)
w = 0;
if ~isequal(cfg.n_workers, 0) && license('test', 'Distrib_Computing_Toolbox')
    pool = gcp('nocreate');
    if ~isempty(pool)
        w = pool.NumWorkers;
        if isnumeric(cfg.n_workers)
            w = min(w, cfg.n_workers);
        end
    end
end
end

function gb = matrixGB(n)
b = 8;
if n > 8000, b = 4; end
gb = n ^ 2 * b / 2 ^ 30;
end

function s = memoryNote(n, cfg)
k = 3 + strcmp(cfg.align, 'group');
s = sprintf('about %.1f GB of memory per run being computed', k * matrixGB(n));
end

function checkMemory(n, cfg)
% Refuse a run that cannot fit, before hours of work (Windows only)
need = (3 + strcmp(cfg.align, 'group')) * matrixGB(n) * max(1, poolWorkers(cfg));
try
    [~, sys] = memory;
    avail = sys.PhysicalMemory.Available / 2 ^ 30;
catch
    return
end
if need > avail
    error('SeeCAT:gradient', ['%d nodes need about %.1f GB of memory, %.1f GB are free. Use larger ' ...
        'nodes (node_size), a smaller mask, an atlas, or fewer parallel workers.'], n, need, avail);
end
end
