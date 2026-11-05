function tests = test_stat
% Tests for seecat.stat (group statistics) on synthetic data. Comparisons
% with SPM on real data: tests/validation/compare_stat_spm.m and
% compare_reml_spm.m.
%   results = runtests('tests/unit/test_stat.m')
tests = functiontests(localfunctions);
end

function setupOnce(~)
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..', '..', 'SeeCAT'));
spmDir = getenv('SEECAT_SPM');
if isempty(spmDir)
    spmDir = 'D:/verysync/dropbox/SciTools/MatlabToolbox/spm';
end
addpath(spmDir);
end

function testGlmTAndFAgainstFormulas(tc)
rng(1);
n = 20;
X = [ones(n, 1), randn(n, 2)];
Y = X * [1; 0.5; -0.3] * ones(1, 50) + randn(n, 50);
con = struct('name', {'b1', 'b12'}, 'type', {'t', 'F'}, 'weights', {[0 1 0], [0 1 0; 0 0 1]});
G = seecat.stat.glm(Y, X, con);
b = X \ Y;
r = Y - X * b;
s2 = sum(r .^ 2) / (n - 3);
iXX = inv(X' * X);
t = b(2, :) ./ sqrt(s2 * iXX(2, 2));
tc.verifyEqual(G.con(1).stat, t, 'AbsTol', 1e-10);
tc.verifyEqual(G.erdf, n - 3, 'AbsTol', 1e-10);
r0 = Y - X(:, 1) * (X(:, 1) \ Y);
Fref = ((sum(r0 .^ 2) - sum(r .^ 2)) / 2) ./ s2;
tc.verifyEqual(G.con(2).stat, Fref, 'RelTol', 1e-10);
tc.verifyEqual(G.con(2).df, [2 n - 3], 'AbsTol', 1e-10);
% p and z agree with the distributions
tc.verifyEqual(G.con(1).p, 1 - spm_Tcdf(t, n - 3), 'AbsTol', 1e-12);
tc.verifyEqual(G.con(1).z, -spm_invNcdf(G.con(1).p), 'AbsTol', 1e-8);
tc.verifyError(@() seecat.stat.glm(Y, [X X(:, 2)], struct('name', 'x', 'type', 't', 'weights', [0 1 0 0])), 'SeeCAT:stat');
end

function testImageCovariatesEqualVoxelwiseFits(tc)
rng(2);
n = 15;
nv = 40;
X = [ones(n, 1), double((1:n)' > 7)];
C = randn(n, nv);
Y = X * [2; 1] + 0.8 * C + randn(n, nv);
con = struct('name', 'grp', 'type', 't', 'weights', [0 1 0]);
G = seecat.stat.glm(Y, X, con, struct('Ximg', reshape(C, n, nv, 1)));
for v = [1 17 40]
    Gv = seecat.stat.glm(Y(:, v), [X C(:, v)], con);
    tc.verifyEqual(G.con(1).stat(v), Gv.con(1).stat, 'AbsTol', 1e-10);
    tc.verifyEqual(G.beta(:, v), Gv.beta, 'AbsTol', 1e-10);
end
end

function testDesignCodingAndContrasts(tc)
maps = table({'a'; 'b'; 'c'; 'd'; 'e'; 'f'}, {'1'; '2'; '3'; '4'; '5'; '6'}, repmat({''}, 6, 1), ...
    {'P'; 'C'; 'P'; 'C'; 'P'; 'C'}, [20; 30; 40; 50; 60; 70], {'F'; 'M'; 'M'; 'F'; 'M'; 'M'}, ...
    'VariableNames', {'path', 'sub', 'level', 'group', 'age', 'sex'});
cfg = baseCfg();
cfg.design = 'two_sample';
cfg.factor = 'group';
cfg.levels = {'C', 'P'};
cfg.covariates = {'age', 'sex'};
D = seecat.stat.design(cfg, maps);
tc.verifyEqual(D.names, {'group_C', 'group_P', 'age', 'sex_M'});
tc.verifyEqual(mean(D.X(:, 3:4)), [0 0], 'AbsTol', 1e-12);       % centred
tc.verifyEqual({D.con.name}, {'CgtP', 'PgtC'});
tc.verifyEqual(D.con(1).weights, [1 -1 0 0]);
tc.verifyFalse(D.reml);
cfg.design = 'paired';
cfg.factor = 'ses';
tc.verifyError(@() seecat.stat.design(cfg, maps), 'SeeCAT:stat');   % covariates with subject effects
end

function testSmoothnessEqualsSpm(tc)
rng(3);
dim = [20 22 18];
n = 12;
Y = zeros([dim n]);
for i = 1:n
    v = randn(dim);
    spm_smooth(v, v, [3 3 3]);
    Y(:, :, :, i) = v;
end
mask = false(dim);
mask(3:18, 3:20, 3:16) = true;
Ym = reshape(Y, [], n)';
X = [ones(n, 1), (1:n)' - mean(1:n)];
G = seecat.stat.glm(Ym(:, mask(:)), X, struct('name', 'x', 'type', 't', 'weights', [0 1]));
hdr = struct('mat', [-2 0 0 20; 0 2 0 -20; 0 0 2 -20; 0 0 0 1], 'dim', dim);
S = seecat.stat.smoothness(G, mask, hdr);
% SPM on the same standardised residual images
d = tempname;
mkdir(d);
old = cd(d);
c = onCleanup(@() leaveAndRemove(old, d));     % one cleanup: back out of d, then delete it
VR = struct('fname', {}, 'dim', {}, 'dt', {}, 'mat', {}, 'pinfo', {});
for i = 1:n
    vol = nan(dim);
    vol(mask) = G.res(i, :) ./ sqrt(G.ResSS / G.trRV);
    o = struct('fname', fullfile(d, sprintf('r%02d.nii', i)), 'dim', dim, ...
        'dt', [spm_type('float64') 0], 'mat', hdr.mat, 'pinfo', [1; 0; 0]);
    spm_write_vol(o, vol);
    VR(i) = o;
end
spm_write_vol(struct('fname', fullfile(d, 'mask.nii'), 'dim', dim, 'dt', [spm_type('uint8') 0], ...
    'mat', hdr.mat, 'pinfo', [1; 0; 0]), double(mask));
[FWHM, ~, R] = spm_est_smoothness(char({VR.fname}), fullfile(d, 'mask.nii'), [n G.trRV]);
tc.verifyEqual(S.FWHM, FWHM, 'RelTol', 1e-10);
tc.verifyEqual(S.R, R(:)', 'RelTol', 1e-10);
end

function testFdrIsBenjaminiHochberg(tc)
rng(4);
nv = 500;
p = [rand(1, 450), rand(1, 50) * 1e-4];
c = struct('type', 't', 'df', [1 30], 'stat', spm_invTcdf(1 - p, 30), 'p', p);
mask = false(10, 10, 5);
mask(:) = true;
S = struct('R', [1 10 30 50], 'nVox', nv, 'V2R', 0.1);
I = seecat.stat.inference(c, mask, struct('mat', eye(4), 'dim', [10 10 5]), S, ...
    struct('method', 'voxel_fdr', 'alpha', 0.05, 'cdt_p', 0.001));
ps = sort(p);
k = find(ps <= (1:nv) / nv * 0.05, 1, 'last');
tc.verifyEqual(nnz(I.keep), nnz(p <= ps(k)));
tc.verifyGreaterThanOrEqual(nnz(I.keep), 45);
end

function testPipelineFindsPlantedEffect(tc)
rng(5);
root = tempname;
c = onCleanup(@() rmdir(root, 's'));
mkdir(root);
dim = [20 20 20];
M = [-3 0 0 30; 0 3 0 -30; 0 0 3 -30; 0 0 0 1];
n = 16;
grp = [zeros(n / 2, 1); ones(n / 2, 1)];
blob = zeros(dim);
blob(8:12, 8:12, 8:12) = 1;
spm_smooth(blob, blob, [2 2 2]);
paths = cell(n, 1);
for i = 1:n
    v = randn(dim);
    spm_smooth(v, v, [2 2 2]);
    v = v + 3 * grp(i) * blob / max(blob(:)) + 10;
    if i == 3
        v(1:2, :, :) = 0;                        % missing in one map: out of the mask
    end
    paths{i} = fullfile(root, sprintf('sub-%02d_map.nii', i));
    seecat.io.write_nii(v, struct('mat', M, 'dim', dim), paths{i});
end
T = table(paths, 1 - grp, grp, 'VariableNames', {'path', 'A', 'B'});
seecat.io.write_tsv(T, fullfile(root, 'design.tsv'));
cfg = seecat.config('stat');
cfg.name = 'planted';
cfg.design = 'custom';
cfg.design_tsv = fullfile(root, 'design.tsv');
cfg.output_dir = fullfile(root, 'out');
cfg.mask = 'brain';
cfg.contrasts = struct('name', 'BgtA', 'type', 't', 'weights', [-1 1]);
cfg.inference = {'cluster_fwe', 'tfce_fwe'};
cfg.tfce.n_perm = 200;
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.status, {'ok'});
tc.verifyEqual(S.n_voxels, prod(dim) - 2 * 20 * 20);
tc.verifyGreaterThanOrEqual(S.surviving_clusters, 1);
g = fullfile(root, 'out', 'group', 'planted');
Tab = seecat.io.read_tsv(fullfile(g, 'planted_contrast-BgtA_desc-clusterFWE_clusters.tsv'));
first = Tab(find(Tab.survives, 1), :);
tc.verifyLessThan(norm([first.x first.y first.z] - (M(1:3, :) * [10; 10; 10; 1])'), 7);
Tf = seecat.io.read_tsv(fullfile(g, 'planted_contrast-BgtA_desc-tfceFWE_clusters.tsv'));
tc.verifyGreaterThanOrEqual(height(Tf), 1);
tc.verifyLessThan(norm([Tf.x(1) Tf.y(1) Tf.z(1)] - (M(1:3, :) * [10; 10; 10; 1])'), 7);
tc.verifyLessThan(Tf.p_peak_tfce_fwe(1), 0.05);
tc.verifyTrue(exist(fullfile(g, 'planted_contrast-BgtA_desc-tfceFWE_stat-p_statmap.nii.gz'), 'file') == 2);
j = jsondecode(fileread(fullfile(g, 'planted_contrast-BgtA_stat-t_statmap.json')));
tc.verifyEqual(j.DegreesOfFreedom(:)', [1 n - 2]);
V = spm_vol(gunzipTo(fullfile(g, 'planted_contrast-BgtA_stat-t_statmap.nii.gz'), root));
tc.verifySubstring(V.descrip, sprintf('CAT{T_[%.1f]}{dLh_', n - 2));
end

function testTfceAgainstDefinition(tc)
% Two blobs; TFCE by its definition, cluster sizes found voxel by voxel
rng(3);
v = zeros(9, 9, 9);
v(2:4, 2:4, 2:4) = 1 + rand(3, 3, 3);
v(7, 7, 7) = 2.5;
v(5, 5, 5) = -3;                               % negative: no enhancement
E = 0.5; H = 2; dh = max(v(:)) / 100;
ref = zeros(size(v));
for h = dh:dh:max(v(:))
    [lab, nc] = spm_bwlabel(double(v >= h), 26);
    for k = 1:nc
        in = lab == k;
        ref(in) = ref(in) + nnz(in) ^ E * h ^ H * dh;
    end
end
t = seecat.stat.tfce(v, E, H, 26);
tc.verifyEqual(t, ref, 'AbsTol', 1e-10);
tc.verifyEqual(t(5, 5, 5), 0);
end

function testPermutationTfce(tc)
% One-sample: every sign flip of 8 maps is used (2^8 = 256 < n_perm) and a
% planted effect survives; null data give p >= alpha almost everywhere.
rng(7);
dim = [12 12 12];
mask = true(dim);
n = 8;
X = ones(n, 1);
con = struct('name', 'pos', 'type', 't', 'weights', 1);
blob = zeros(dim);
blob(4:8, 4:8, 4:8) = 1.5;
Y = randn(n, prod(dim)) + blob(:)';
G = seecat.stat.glm(Y, X, con);
P = seecat.stat.permutation(Y, X, G.con, mask, struct('scheme', 'flip', 'n_perm', 1000));
tc.verifyEqual(P.n_perm, 256);
tc.verifyLessThan(median(P.p_fwe(blob(:) > 0)), 0.05);
tc.verifyGreaterThan(median(P.p_fwe(blob(:) == 0)), 0.5);
tc.verifyGreaterThanOrEqual(min(P.p_fwe), 1 / 256);
% two-sample with random permutations: reproducible (fixed seed), F works
g = [zeros(10, 1); ones(10, 1)];
X2 = [1 - g, g];
Y2 = randn(20, prod(dim)) + 1.5 * g * blob(:)';
c2 = struct('name', {'BgtA', 'diff'}, 'type', {'t', 'F'}, 'weights', {[-1 1], [-1 1]});
G2 = seecat.stat.glm(Y2, X2, c2);
o = struct('scheme', 'perm', 'n_perm', 200);
A = seecat.stat.permutation(Y2, X2, G2.con, mask, o);
B = seecat.stat.permutation(Y2, X2, G2.con, mask, o);
tc.verifyEqual(A(1).max_null, B(1).max_null);
tc.verifyLessThan(median(A(1).p_fwe(blob(:) > 0)), 0.05);
tc.verifyLessThan(median(A(2).p_fwe(blob(:) > 0)), 0.05);
% paired: swaps within subjects, all 2^6 of them
s = repelem((1:6)', 2);
lv = repmat([1; 0], 6, 1);
X3 = [lv, 1 - lv, double(s == 1:6)];
Y3 = randn(12, prod(dim)) + lv * blob(:)' + s * ones(1, prod(dim));
c3 = struct('name', 'AgtB', 'type', 't', 'weights', [1 -1 zeros(1, 6)]);
G3 = seecat.stat.glm(Y3, X3, c3);
P3 = seecat.stat.permutation(Y3, X3, G3.con, mask, struct('scheme', 'within', 'blocks', s, 'n_perm', 500));
tc.verifyEqual(P3.n_perm, 64);
end

%% Helpers -------------------------------------------------------------------

function cfg = baseCfg()
cfg = seecat.config('stat');
end

function f = gunzipTo(gz, d)
g = gunzip(gz, fullfile(d, 'unz'));
f = g{1};
end

function out = quiet(fn)
[~, out] = evalc('fn()');
end

function leaveAndRemove(old, d)
cd(old);
rmdir(d, 's');
end
