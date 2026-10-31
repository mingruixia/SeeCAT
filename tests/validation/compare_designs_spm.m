function compare_designs_spm(out)
% COMPARE_DESIGNS_SPM  The stat pipeline against SPM for one_sample, paired,
% anova1 and regression, on ds000030 zFC maps (9 subjects).
%   compare_designs_spm('C:/tmp/designcheck')
%
% For each design, seecat.run writes the maps; SPM fits the same model on the
% same images with SeeCAT's analysis mask as explicit mask. Compared: the
% statistic map, df, FWHM, resels and every row of SPM's results table at
% the cluster-forming threshold (p < 0.001).

if exist(out, 'dir'), rmdir(out, 's'); end
mkdir(out);
in = 'D:/data/SeeCAT_e2e/ds000030/seecat';
P = seecat.io.read_tsv('D:/data/SeeCAT_testdata/ds000030/participants.tsv');
P.agegroup = repmat({'mid'}, height(P), 1);       % three groups for anova1
P.agegroup(P.age < 40) = {'young'};
P.agegroup(P.age >= 45) = {'old'};
ptsv = fullfile(out, 'participants.tsv');
seecat.io.write_tsv(P, ptsv);

% one_sample
cfg = base(in, out, ptsv, 'onesample');
cfg.maps = struct('desc', 'PCC', 'stat', 'z', 'suffix', 'connectivity');
runSeecat(cfg);
f = maps(out, 'onesample');
j = jobBase(out, 'onesample');
j.spm.stats.factorial_design.des.t1.scans = f;
compare('one_sample', out, 'onesample', 'pos', 'T', j, struct('tcon', struct('name', 'pos', 'weights', 1, 'sessrep', 'none')));

% paired: PCC vs mPFC within subject
cfg = base(in, out, ptsv, 'paired');
cfg.maps = struct('stat', 'z', 'suffix', 'connectivity');
cfg.design = 'paired';
cfg.factor = 'desc';
cfg.levels = {'PCC', 'mPFC'};
runSeecat(cfg);
f = maps(out, 'paired');
j = jobBase(out, 'paired');
for s = 1:numel(f) / 2
    j.spm.stats.factorial_design.des.pt.pair(s).scans = f(2 * s - 1:2 * s);
end
j.spm.stats.factorial_design.des.pt.gmsca = 0;
j.spm.stats.factorial_design.des.pt.ancova = 0;
compare('paired', out, 'paired', 'PCCgtmPFC', 'T', j, ...
    struct('tcon', struct('name', 'd', 'weights', [1 -1], 'sessrep', 'none')));

% anova1: three age groups
cfg = base(in, out, ptsv, 'anovaone');
cfg.maps = struct('desc', 'PCC', 'stat', 'z', 'suffix', 'connectivity');
cfg.design = 'anova1';
cfg.factor = 'agegroup';
cfg.levels = {'young', 'mid', 'old'};
runSeecat(cfg);
[f, D] = maps(out, 'anovaone');
j = jobBase(out, 'anovaone');
for g = 1:3
    j.spm.stats.factorial_design.des.anova.icell(g).scans = f(D{:, g + 3} == 1);
end
j.spm.stats.factorial_design.des.anova.dept = 0;
j.spm.stats.factorial_design.des.anova.variance = 0;
j.spm.stats.factorial_design.des.anova.gmsca = 0;
j.spm.stats.factorial_design.des.anova.ancova = 0;
compare('anova1', out, 'anovaone', 'equalgroups', 'F', j, ...
    struct('fcon', struct('name', 'g', 'weights', [1 -1 0; 0 1 -1], 'sessrep', 'none')));

% regression: age, with gender as covariate
cfg = base(in, out, ptsv, 'regress');
cfg.maps = struct('desc', 'PCC', 'stat', 'z', 'suffix', 'connectivity');
cfg.design = 'regression';
cfg.regressors = {'age'};
cfg.covariates = {'gender'};
runSeecat(cfg);
[f, D] = maps(out, 'regress');
j = jobBase(out, 'regress');
j.spm.stats.factorial_design.des.mreg.scans = f;
j.spm.stats.factorial_design.des.mreg.mcov = struct('c', D.age, 'cname', 'age', 'iCC', 1);
j.spm.stats.factorial_design.des.mreg.incint = 1;
j.spm.stats.factorial_design.cov = struct('c', D.gender_M, 'cname', 'sex', 'iCFI', 1, 'iCC', 1);
compare('regression', out, 'regress', 'agepos', 'T', j, ...
    struct('tcon', struct('name', 'age', 'weights', [0 0 1], 'sessrep', 'none')));   % SPM columns: mean, sex, age
end

function cfg = base(in, out, ptsv, name)
cfg = seecat.config('stat');
cfg.input_dir = in;
cfg.output_dir = fullfile(out, 'seecat');
cfg.participants = ptsv;
cfg.name = name;
end

function runSeecat(cfg)
[~, S] = evalc('seecat.run(cfg)');
if ~strcmp(S.status{1}, 'ok')
    error('%s failed: %s', cfg.name, S.message{1});
end
end

function [f, D] = maps(out, name)
% Unpacked copies of the maps, in design.tsv order, and the design table
g = fullfile(out, 'seecat', 'group', name);
D = seecat.io.read_tsv(fullfile(g, [name '_design.tsv']));
f = cell(height(D), 1);
for i = 1:height(D)
    u = gunzip(D.path{i}, fullfile(out, 'unz', name, sprintf('%02d', i)));
    f{i} = [u{1} ',1'];
end
end

function j = jobBase(out, name)
d = fullfile(out, 'spm', name);
mkdir(d);
m = gunzip(fullfile(out, 'seecat', 'group', name, [name '_desc-mask_mask.nii.gz']), fullfile(out, 'unz', name, 'mask'));
j.spm.stats.factorial_design.dir = {d};
j.spm.stats.factorial_design.masking.tm.tm_none = 1;
j.spm.stats.factorial_design.masking.im = 0;
j.spm.stats.factorial_design.masking.em = {[m{1} ',1']};
j.spm.stats.factorial_design.globalc.g_omit = 1;
j.spm.stats.factorial_design.globalm.gmsca.gmsca_no = 1;
j.spm.stats.factorial_design.globalm.glonorm = 1;
end

function compare(label, out, name, conName, STAT, j, consess)
d = j.spm.stats.factorial_design.dir{1};
k.spm.stats.fmri_est.spmmat = {fullfile(d, 'SPM.mat')};
k.spm.stats.fmri_est.method.Classical = 1;
c.spm.stats.con.spmmat = {fullfile(d, 'SPM.mat')};
c.spm.stats.con.consess = {consess};
evalc('seecat.util.spm_run({j, k, c})');
load(fullfile(d, 'SPM.mat'), 'SPM');
g = fullfile(out, 'seecat', 'group', name);
stem = sprintf('%s_contrast-%s', name, conName);
s = seecat.io.read_nii(fullfile(g, [stem '_stat-' lower(STAT) '_statmap.nii.gz']));
r = seecat.io.read_nii(fullfile(d, sprintf('spm%s_0001.nii', STAT)));
m = seecat.io.read_nii(fullfile(g, [name '_desc-mask_mask.nii.gz'])) > 0;
js = jsondecode(fileread(fullfile(g, [stem '_stat-' lower(STAT) '_statmap.json'])));
% the 1.0-compatible df: SPM's design-level erdf and the contrast's eidf
dfs = [SPM.xCon(1).eidf, SPM.xX.erdf];
fprintf('\n== %s: X %dx%d (SeeCAT design %d columns)\n', label, size(SPM.xX.X), numel(js.DesignColumns));
fprintf('  voxels SeeCAT %d, SPM %d | %s max rel|diff| %.2e (max %.2f)\n', nnz(m), SPM.xVol.S, STAT, ...
    max(abs(s(m) - r(m)) ./ max(1, abs(r(m)))), max(abs(r(m))));
fprintf('  df SeeCAT %s, SPM %s\n', mat2str(js.DegreesOfFreedom(:)', 6), mat2str(dfs, 6));
fprintf('  FWHM rel|diff| %.2e, resels rel|diff| %.2e\n', max(abs(js.FWHMvoxels(:)' - SPM.xVol.FWHM) ./ SPM.xVol.FWHM), ...
    max(abs(js.Resels(:)' - SPM.xVol.R) ./ max(1, abs(SPM.xVol.R))));
x = struct('swd', d, 'Ic', 1, 'u', 0.001, 'Im', [], 'thresDesc', 'none', 'title', '', 'k', 0, 'Mc', 0);
[~, ~, x] = evalc('spm_getSPM(x)');
[~, TabDat] = evalc('spm_list(''Table'', x)');
T = seecat.io.read_tsv(fullfile(g, [stem '_desc-clusterFWE_clusters.tsv']));
nr = size(TabDat.dat, 1);
fprintf('  table rows SeeCAT %d, SPM %d', height(T), nr);
if nr ~= height(T)
    fprintf('  <-- DIFFERENT\n');
    return
end
dd = zeros(nr, 5);
for i = 1:nr
    t = TabDat.dat(i, :);
    dd(i, :) = [abs(t{9} - T.peak_stat(i)) / max(1, abs(t{9})), abs(t{10} - T.peak_z(i)), ...
        abs(t{7} - T.p_peak_fwe(i)), max(abs(t{12}' - [T.x(i) T.y(i) T.z(i)])), nd(t{5}, T.voxels(i))];
end
fprintf(' | max diff: stat %.1e, Z %.1e, p peak FWE %.1e, xyz %.1e, cluster k %.1e\n', max(dd, [], 1));
end

function x = nd(a, b)
if isempty(a), a = NaN; end
if isnan(a) && isnan(b)
    x = 0;
else
    x = abs(a - b);
end
end
