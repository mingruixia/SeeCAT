function result = run_unit(unit, cfg, log)
% RUN_UNIT  Fit a group model and write maps, thresholded results and tables.
%   result = seecat.stat.run_unit(unit, cfg, log)
%
% Steps: read the maps (one grid), analysis mask (cfg.mask and non-zero in
% every map, S4), design (seecat.stat.design), non-sphericity when asked
% (seecat.stat.reml, S6), fit (seecat.stat.glm), smoothness
% (seecat.stat.smoothness), inference per contrast and method
% (seecat.stat.inference). Outputs: Doc/design/stat.md, section 8.

maps = unit.maps;
for d = unit.dropped(:)'
    log('dropped %s', d{1});
end
[Y, V] = seecat.io.read_nii(maps.path, 'Class', 'single');
hdr = V(1);
hdr.n = [1 1];
n = height(maps);
mask = analysisMask(cfg.mask, hdr);
nMask = nnz(mask);
mask = mask & all(Y ~= 0 & isfinite(Y), 4);
nData = nnz(mask);
Y = reshape(Y, [], n)';

% image covariates: one image per map, centred voxel-wise
q = numel(cfg.image_covariates);
Cs = cell(q, 1);
for k = 1:q
    Cs{k} = reshape(seecat.io.read_nii(unit.image_files{k}, 'Ref', hdr, 'Interp', 1), [], n)';
    mask(:) = mask(:) & all(Cs{k} ~= 0 & isfinite(Cs{k}), 1)';
end
imgNote = '';
if q > 0
    imgNote = sprintf(', %d after the image covariates', nnz(mask));
end
Ximg = zeros(n, nnz(mask), q);
for k = 1:q
    C = double(Cs{k}(:, mask(:)));
    Ximg(:, :, k) = C - mean(C, 1);
end
Y = double(Y(:, mask(:)));
log('%d maps, %d voxels in the analysis mask', n, nnz(mask));
if ~any(mask(:))
    error('SeeCAT:stat', ['The analysis mask is empty: %s gives %d voxels on the maps'' grid ' ...
        '(%s), %d of them non-zero in every map%s. Check the mask (same space as the maps) ' ...
        'and the maps.'], maskName(cfg.mask), nMask, mat2str(hdr.dim(1:3)), nData, imgNote);
end

if strcmp(cfg.design, 'custom')
    num = varfun(@isnumeric, maps, 'OutputFormat', 'uniform');
    cfg.design_columns = setdiff(maps.Properties.VariableNames(num), {'path', 'sub', 'level'}, 'stable');
end
if strcmp(cfg.variance, 'auto')
    cfg.variance = 'equal';
    if strcmp(cfg.design, 'anova1_rm')
        cfg.variance = 'unequal';
    end
end
cfg.n_image_covariates = q;
D = seecat.stat.design(cfg, maps);
stems = arrayfun(@(c) contrastStem(c.name), D.con, 'UniformOutput', false);
[u, ~, k] = unique(lower(stems));             % lower: Windows file names ignore case
dup = u(accumarray(k(:), 1) > 1);
if ~isempty(dup)
    error('SeeCAT:stat', ['Contrast names %s give the same file names (only letters and digits ' ...
        'are kept, case is ignored); rename them.'], strjoin(arrayfun(@(c) ['"' c.name '"'], ...
        D.con(ismember(lower(stems), dup)), 'UniformOutput', false), ', '));
end
for f = fieldnames(D.vif)'
    if D.vif.(f{1}) > 5
        log('WARNING: column %s has VIF %.1f (collinear with other columns)', f{1}, D.vif.(f{1}));
    end
end

if q                                         % image covariates: same design rank at every voxel
    rk = rank(D.X) + q;
    keep = true(1, size(Y, 2));
    for j = 1:size(Y, 2)
        keep(j) = rank([D.X, reshape(Ximg(:, j, :), n, q)]) == rk;
    end
    if ~all(keep)
        log(['WARNING: %d voxel(s) left out: an image covariate is constant or collinear with ' ...
            'the design there'], nnz(~keep));
        idx = find(mask);
        mask(idx(~keep)) = false;
        Y = Y(:, keep);
        Ximg = Ximg(:, keep, :);
    end
    if ~any(keep)
        error('SeeCAT:stat', 'The image covariate is constant or collinear with the design in every voxel.');
    end
end
opt = struct();
nonsph = struct('estimated', false);
if D.reml
    [Vc, info] = seecat.stat.reml(Y, D.X, D.I, D.var, D.dep, D.i0);
    nonsph = struct('estimated', isempty(info.fallback), 'components', info.components, ...
        'voxels', info.voxels, 'hyperparameters', info.h, 'note', info.fallback);
    if isempty(info.fallback)
        opt.V = Vc;
    end
    log('non-sphericity: %d components, %d voxels %s', info.components, info.voxels, info.fallback);
end
if q
    opt.Ximg = Ximg;
end
names = [D.names, arrayfun(@(k) sprintf('imagecov%d', k), 1:q, 'UniformOutput', false)];
G = seecat.stat.glm(Y, D.X, D.con, opt);
S = seecat.stat.smoothness(G, mask, hdr);
log('df %.2f; FWHM %s mm; resels %.1f', G.erdf, mat2str(round(S.FWHMmm, 2)), S.R(4));
if cfg.cdt_p > 0.001 && ismember('cluster_fwe', cfg.inference)
    log('WARNING: cluster-forming threshold p = %g; above 0.001 RFT cluster inference is liberal (Eklund et al. 2016)', cfg.cdt_p);
end

% ---- outputs ----------------------------------------------------------------
out = fullfile('group', cfg.name);
pub = struct('output_dir', cfg.output_dir, 'work_dir', unit.work_dir, 'manifest', unit.manifest);
if ~exist(unit.work_dir, 'dir')
    mkdir(unit.work_dir);
end
put = @(vol, file, meta, varargin) publishVol(vol, hdr, file, meta, out, pub, varargin{:});
src = cellfun(@(p) strrep(p, '\', '/'), maps.path, 'UniformOutput', false);
base = struct('DesignColumns', {names}, 'FWHMmm', S.FWHMmm, 'FWHMvoxels', S.FWHM, ...
    'Resels', S.R, 'SearchVoxels', S.nVox, 'NonSphericity', nonsph, 'VIF', D.vif, ...
    'Software', ['SeeCAT ' seecat.version()], 'Sources', {src});

dsg = array2table([D.X, zeros(n, q)], 'VariableNames', matlab.lang.makeValidName(names));
dsg = [maps(:, {'path', 'sub', 'level'}), dsg];
tsv = fullfile(unit.work_dir, 'design.tsv');
seecat.io.write_tsv(dsg, tsv);
seecat.util.publish_output(tsv, fullfile(out, [cfg.name '_design.tsv']), [], pub);
put(uint8(mask), [cfg.name '_desc-mask_mask'], struct('Description', 'analysis mask'), 'uint8');

perm = [];
if ismember('tfce_fwe', cfg.inference)
    perm = permutations(Y, D.X, G.con, mask, opt, cfg, maps, q, log);
end

dLh = (4 * reallog(2)) ^ 1.5 / prod(S.FWHM);   % reallog: 'log' is the logger here
report.contrasts = {};
nClusters = 0;
for k = 1:numel(G.con)
    c = G.con(k);
    cn = contrastStem(c.name);
    stem = sprintf('%s_contrast-%s', cfg.name, cn);
    STAT = upper(c.type);
    if STAT == 'T'
        descr = sprintf('CAT{T_[%.1f]}{dLh_%f}{FWHMx_%fFWHMy_%fFWHMz_%fmm}', c.df(2), dLh, S.FWHMmm);
    else
        descr = sprintf('CAT{F_[%.1f,%.1f]}{dLh_%f}{FWHMx_%fFWHMy_%fFWHMz_%fmm}', c.df(1), c.df(2), dLh, S.FWHMmm);
    end
    meta = base;
    meta.Contrast = struct('Name', c.name, 'Type', STAT, 'Weights', c.weights);
    meta.DegreesOfFreedom = c.df;
    meta.Statistic = STAT;
    put(onMask(c.stat, mask), [stem '_stat-' lower(STAT) '_statmap'], meta, 'float32', descr);
    m = meta;
    m.Statistic = 'Z (same p)';
    put(onMask(c.z, mask), [stem '_stat-z_statmap'], m);
    m.Statistic = '-log10(p), upper tail';
    put(onMask(-log10(c.p), mask), [stem '_stat-p_statmap'], m);
    if STAT == 'T'
        m.Statistic = 'contrast estimate (effect)';
        put(onMask(c.effect, mask), [stem '_stat-effect_statmap'], m);
    end
    alpha = cfg.alpha;
    if STAT == 'T' && cfg.two_tailed
        alpha = alpha / 2;
    end
    entry = struct('name', c.name, 'type', STAT, 'df', c.df, 'methods', {{}});
    for method = cfg.inference
        io = struct('method', method{1}, 'alpha', alpha, 'cdt_p', cfg.cdt_p);
        if strcmp(method{1}, 'tfce_fwe')
            io.perm = perm(k);
        end
        I = seecat.stat.inference(c, mask, hdr, S, io);
        tag = struct('cluster_fwe', 'clusterFWE', 'voxel_fwe', 'voxelFWE', 'voxel_fdr', 'voxelFDR', ...
            'tfce_fwe', 'tfceFWE').(method{1});
        mm = meta;
        mm.Inference = struct('Method', method{1}, 'Alpha', alpha, 'TwoTailedSplit', STAT == 'T' && cfg.two_tailed, ...
            'ClusterFormingP', cfg.cdt_p * strcmp(method{1}, 'cluster_fwe'), 'HeightThreshold', I.height, ...
            'ExtentThresholdVoxels', I.extent, 'Connectivity', 18);
        if strcmp(method{1}, 'tfce_fwe')
            mm.Inference.TFCE = struct('E', cfg.tfce.E, 'H', cfg.tfce.H, 'Connectivity', 26, ...
                'Permutations', perm(k).n_perm, 'Scheme', perm(k).scheme, 'Method', 'Freedman-Lane');
            m = mm;
            m.Statistic = 'TFCE of the positive statistic';
            put(onMask(perm(k).tfce, mask), sprintf('%s_desc-tfce_stat-tfce_statmap', stem), m);
            m.Statistic = '-log10(p), TFCE FWE (permutations)';
            put(onMask(-log10(perm(k).p_fwe), mask), sprintf('%s_desc-tfceFWE_stat-p_statmap', stem), m);
        end
        s = zeros(size(mask));
        s(mask) = c.stat;
        s(I.label == 0) = 0;
        put(s, sprintf('%s_desc-%s_stat-%s_statmap', stem, tag, lower(STAT)), mm, 'float32', descr);
        put(uint16(I.label), sprintf('%s_desc-%s_dseg', stem, tag), mm, 'int16');
        tab = fullfile(unit.work_dir, sprintf('%s_%s_clusters.tsv', cn, tag));
        seecat.io.write_tsv(I.table, tab);
        seecat.util.publish_output(tab, fullfile(out, sprintf('%s_desc-%s_clusters.tsv', stem, tag)), [], pub);
        nSurv = max(I.label(:));
        nClusters = nClusters + nSurv;
        entry.methods{end+1} = struct('method', method{1}, 'alpha', alpha, 'height', I.height, ...
            'extent', I.extent, 'surviving_clusters', nSurv, 'surviving_voxels', nnz(I.keep));
        log('%s, %s: height %.3f, %d cluster(s) / %d voxel(s) survive', c.name, method{1}, I.height, nSurv, nnz(I.keep));
    end
    report.contrasts{end+1} = entry;
end
report.n_maps = n;
report.dropped = unit.dropped;
report.design = cfg.design;
report.covariate_coding = D.coding;
report.df = G.erdf;
report.FWHMmm = S.FWHMmm;
report.resels = S.R;
report.non_sphericity = nonsph;
rj = fullfile(unit.work_dir, 'report.json');
seecat.util.write_json(rj, report);
seecat.util.publish_output(rj, fullfile(out, [cfg.name '_report.json']), [], pub);
result = struct('n_maps', n, 'n_dropped', numel(unit.dropped), 'n_voxels', nnz(mask), ...
    'df', G.erdf, 'fwhm_mm', mean(S.FWHMmm), 'surviving_clusters', nClusters);
end

function P = permutations(Y, X, con, mask, opt, cfg, maps, q, log)
% TFCE FWE for every contrast, sharing one set of permutations
if q
    error('SeeCAT:stat', 'tfce_fwe does not support image covariates; use another correction.');
end
switch cfg.design
    case 'one_sample'
        scheme = 'flip';
    case {'paired', 'anova1_rm'}
        scheme = 'within';
    otherwise
        scheme = 'perm';
end
workers = 0;
if ~isequal(cfg.n_workers, 0) && license('test', 'Distrib_Computing_Toolbox')
    pool = gcp('nocreate');
    if ~isempty(pool)
        workers = pool.NumWorkers;
        if isnumeric(cfg.n_workers)
            workers = min(workers, cfg.n_workers);
        end
    end
end
po = struct('scheme', scheme, 'blocks', {maps.sub}, 'n_perm', cfg.tfce.n_perm, 'E', cfg.tfce.E, ...
    'H', cfg.tfce.H, 'workers', workers, 'seed', 0);
if isfield(opt, 'V')
    po.V = opt.V;
end
t = tic;
P = seecat.stat.permutation(Y, X, con, mask, po);
log('TFCE: %d permutations (%s), %d contrast(s), %d worker(s), %.0f s', P(1).n_perm, scheme, ...
    numel(con), workers, toc(t));
end

function m = analysisMask(spec, hdr)
switch spec
    case 'brain'
        m = true(hdr.dim);
    case 'gm'
        vox = mean(sqrt(sum(hdr.mat(1:3, 1:3) .^ 2)));
        res = 3;
        if abs(vox - 2) < abs(vox - 3)
            res = 2;
        end
        here = fileparts(fileparts(fileparts(mfilename('fullpath'))));
        m = seecat.io.read_nii(fullfile(here, 'templates', sprintf('tpl-IXI549Space_res-%d_label-GM_mask.nii', res)), ...
            'Ref', hdr, 'Interp', 0) > 0;
    otherwise
        m = seecat.io.read_nii(spec, 'Ref', hdr, 'Interp', 0) > 0;
end
end

function s = maskName(spec)
switch spec
    case 'gm'
        s = 'the grey-matter mask (gm)';
    case 'brain'
        s = 'the whole image (brain)';
    otherwise
        s = spec;
end
end

function v = onMask(x, mask)
v = zeros(size(mask), 'single');
v(mask) = x;
end

function publishVol(vol, hdr, name, meta, out, pub, dtype, descr)
if nargin < 7
    dtype = 'float32';
end
if nargin < 8
    descr = '';
end
f = fullfile(pub.work_dir, [name '.nii']);
seecat.io.write_nii(vol, hdr, f, 'DataType', dtype, 'Descrip', descr);
seecat.util.publish_output(f, fullfile(out, [name '.nii.gz']), meta, pub);
end

function cn = contrastStem(name)
% The contrast label in file names: letters and digits only
cn = regexprep(matlab.lang.makeValidName(name), '[^a-zA-Z0-9]', '');
end
