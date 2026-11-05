function result = run_unit(unit, cfg, log)
% RUN_UNIT  Harmonise the selected maps across sites and write them.
%   result = seecat.harmonize.run_unit(unit, cfg, log)
%
% Voxels: cfg.mask and non-zero in every map; voxels outside are set to 0
% in the outputs. Kept effects (MOD): cfg.covariates (numbers as they are,
% text as dummy columns) and cfg.nonlinear (natural cubic splines with
% cfg.spline_df degrees of freedom; ComBat-GAM, Pomponio et al. 2020).
% Methods:
%   combat           parametric empirical Bayes (Johnson 2007; Fortin 2017)
%   combat_nonparam  non-parametric empirical Bayes
%   combat_noeb      location and scale per voxel, no empirical Bayes
%   combat_mean      location only (site means), parametric EB
%   combat_gam       combat with the nonlinear covariates
%   covbat           combat, then covariance harmonisation (Chen 2022)
%   lm               linear regression: site means removed, no EB, no scaling
% A site effect check (share of voxels with a site effect at p < 0.05,
% F test adjusted for the kept effects) is written before and after.

maps = unit.maps;
for d = unit.dropped(:)'
    log('dropped %s', d{1});
end
[Y, V] = seecat.io.read_nii(maps.path, 'Class', 'single');
hdr = V(1);
hdr.n = [1 1];
n = height(maps);
mask = analysisMask(cfg.mask, hdr) & all(Y ~= 0 & isfinite(Y), 4);
Y = reshape(Y, [], n)';
Y = double(Y(:, mask(:)));
site = cellstr(string(maps.(cfg.site)));
[sites, ~, sid] = unique(site);
log('%d maps, %d voxels, %d sites (%s)', n, nnz(mask), numel(sites), ...
    strjoin(cellfun(@(s, c) sprintf('%s: %d', s, c), sites(:), num2cell(accumarray(sid, 1)), 'UniformOutput', false), ', '));
[mod, names] = keptEffects(maps, cfg);
if ~isempty(names)
    log('kept effects: %s', strjoin(names, ', '));
end

before = siteEffect(Y, sid, mod);
note = '';
small = min(accumarray(sid, 1));
if small < 20 && ~any(strcmp(cfg.method, {'combat_mean', 'lm'}))
    note = sprintf(['The smallest site has %d maps. With small sites, ComBat''s per-site variance ' ...
        'adjustment can make later tests of the kept covariates too liberal (Nygaard et al. 2016, ' ...
        'Biostatistics 17:29-39); consider combat_mean or lm, or adding site as a covariate in ' ...
        'Statistics and checking the result without harmonisation.'], small);
    log('WARNING: %s', note);
end
opt = struct('ref', []);
if ~isempty(cfg.ref_site)
    opt.ref = cfg.ref_site;
end
info = struct();
switch cfg.method
    case {'combat', 'combat_gam'}
        H = seecat.harmonize.combat(Y, site, mod, opt);
    case 'combat_nonparam'
        opt.parametric = false;
        H = seecat.harmonize.combat(Y, site, mod, opt);
    case 'combat_noeb'
        opt.eb = false;
        H = seecat.harmonize.combat(Y, site, mod, opt);
    case 'combat_mean'
        opt.mean_only = true;
        H = seecat.harmonize.combat(Y, site, mod, opt);
    case 'covbat'
        opt.pct_var = cfg.covbat_var;
        [H, info] = seecat.harmonize.covbat(Y, site, mod, opt);
        log('covbat: %d components, %.0f%% of the residual variance', info.components, 100 * info.variance_explained);
    case 'lm'
        opt.eb = false;
        opt.mean_only = true;
        H = seecat.harmonize.combat(Y, site, mod, opt);
end
after = siteEffect(H, sid, mod);
log('voxels with a site effect (p < 0.05): %.1f%% before, %.1f%% after', 100 * before, 100 * after);

% outputs
pub = struct('output_dir', cfg.output_dir, 'work_dir', unit.work_dir, 'manifest', unit.manifest);
if ~exist(unit.work_dir, 'dir')
    mkdir(unit.work_dir);
end
meta0 = struct('Harmonization', cfg.method, 'SiteColumn', cfg.site, 'Sites', {sites}, ...
    'KeptEffects', {names}, 'ReferenceSite', cfg.ref_site, 'Mask', cfg.mask, ...
    'Software', ['SeeCAT ' seecat.version()]);
for i = 1:n
    vol = zeros(hdr.dim, 'single');
    vol(mask) = H(i, :);
    f = fullfile(unit.work_dir, sprintf('map%04d.nii', i));
    seecat.io.write_nii(vol, hdr, f);
    [ent, ~, ~] = seecat.bids.parse_name(maps.path{i});
    desc = cfg.label;
    if isfield(ent, 'desc')
        desc = [ent.desc cfg.label];
    end
    rel = seecat.bids.deriv_name(maps.path{i}, 'desc', desc);
    meta = meta0;
    meta.Site = site{i};
    meta.Sources = {strrep(maps.path{i}, '\', '/')};
    seecat.util.publish_output(f, rel, meta, pub);
end
out = fullfile('group', unit.id);
T = maps(:, intersect({'path', 'sub', cfg.site}, maps.Properties.VariableNames, 'stable'));
tsv = fullfile(unit.work_dir, 'maps.tsv');
seecat.io.write_tsv(T, tsv);
seecat.util.publish_output(tsv, fullfile(out, [unit.id '_maps.tsv']), [], pub);
report = meta0;
report.n_maps = n;
report.n_voxels = nnz(mask);
report.dropped = unit.dropped;
report.site_effect_before = before;
report.site_effect_after = after;
report.covbat = info;
report.note = note;
rj = fullfile(unit.work_dir, 'report.json');
seecat.util.write_json(rj, report);
seecat.util.publish_output(rj, fullfile(out, [unit.id '_report.json']), [], pub);
result = struct('n_maps', n, 'n_sites', numel(sites), 'n_voxels', nnz(mask), ...
    'site_effect_before', before, 'site_effect_after', after);
end

function [M, names] = keptEffects(maps, cfg)
M = zeros(height(maps), 0);
names = {};
for c = cfg.covariates(:)'
    v = maps.(c{1});
    if isnumeric(v) || islogical(v)
        M = [M, double(v)]; %#ok<AGROW>
        names{end+1} = c{1}; %#ok<AGROW>
    else
        v = string(v);
        lv = unique(v);
        for j = 2:numel(lv)
            M = [M, double(v == lv(j))]; %#ok<AGROW>
            names{end+1} = sprintf('%s_%s', c{1}, lv(j)); %#ok<AGROW>
        end
    end
end
for c = cfg.nonlinear(:)'
    B = seecat.harmonize.spline_basis(double(maps.(c{1})), cfg.spline_df);
    M = [M, B]; %#ok<AGROW>
    names = [names, arrayfun(@(j) sprintf('%s_ns%d', c{1}, j), 1:size(B, 2), 'UniformOutput', false)]; %#ok<AGROW>
end
end

function share = siteEffect(Y, sid, mod)
% Share of voxels where the sites differ (F test, adjusted for MOD)
n = size(Y, 1);
X0 = [ones(n, 1), mod];
X1 = [double(sid == 1:max(sid)), mod];
r0 = Y - X0 * (X0 \ Y);
r1 = Y - X1 * (X1 \ Y);
df1 = rank(X1) - rank(X0);
df2 = n - rank(X1);
F = ((sum(r0 .^ 2) - sum(r1 .^ 2)) / df1) ./ (sum(r1 .^ 2) / df2);
p = 1 - spm_Fcdf(F, [df1 df2]);
share = mean(p < 0.05);
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
