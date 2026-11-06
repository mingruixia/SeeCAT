function tests = test_harmonize
% Tests for seecat.harmonize: ComBat against neuroCombat (fixtures made by
% tests/validation/make_combat_reference.py), CovBat, splines, the pipeline.
%   results = runtests('tests/unit/test_harmonize.m')
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

function testCombatEqualsNeuroCombat(tc)
d = fullfile(fileparts(mfilename('fullpath')), '..', 'fixtures', 'combat');
Y = readmatrix(fullfile(d, 'Y.csv'));
C = readtable(fullfile(d, 'covars.csv'));
mod = [double(C.group == 1), C.age];
v = {'param', struct(), 1e-4
    'nonparam', struct('parametric', false), 1e-6
    'noeb', struct('eb', false), 1e-6
    'meanonly', struct('mean_only', true), 1e-6
    'ref', struct('ref', 'B'), 1e-6};
for i = 1:size(v, 1)
    H = seecat.harmonize.combat(Y, C.site, mod, v{i, 2});
    R = readmatrix(fullfile(d, ['H_' v{i, 1} '.csv']));
    tc.verifyEqual(H, R, 'AbsTol', v{i, 3}, v{i, 1});   % neuroCombat computes in float32
end
end

function testCombatRemovesSitesAndKeepsGroups(tc)
rng(2);
n = 90;
site = repelem({'A'; 'B'; 'C'}, 30);
g = repmat([0; 1], 45, 1);
s = repelem([0; 2; -1], 30);
sc = repelem([1; 2; 0.5], 30);
Y = randn(n, 200) .* sc + g * 1.0 + s;          % the ComBat model: shared group effect
for m = {'combat', 'covbat'}
    if strcmp(m{1}, 'covbat')
        H = seecat.harmonize.covbat(Y, site, g);
    else
        H = seecat.harmonize.combat(Y, site, g);
    end
    siteMeans = [mean(H(s == 0 & g == 0, :), 'all'), mean(H(s == 2 & g == 0, :), 'all'), mean(H(s == -1 & g == 0, :), 'all')];
    tc.verifyLessThan(range(siteMeans), 0.25, m{1});
    groupEffect = mean(H(g == 1, :), 'all') - mean(H(g == 0, :), 'all');
    tc.verifyEqual(groupEffect, 1, 'AbsTol', 0.2, m{1});
    sds = arrayfun(@(k) std(H(s == k, :), 0, 'all'), [0 2 -1]);
    tc.verifyLessThan(max(sds) / min(sds), 1.3, m{1});
end
tc.verifyError(@() seecat.harmonize.combat(Y, repmat({'A'}, n, 1)), 'SeeCAT:harmonize');
end

function testSplineBasis(tc)
x = linspace(10, 80, 200)';
B = seecat.harmonize.spline_basis(x, 6);
tc.verifyEqual(size(B, 2), 6);
% straight lines are in the span, and the fit is linear beyond the boundary knots
r = x - [ones(200, 1), B] * ([ones(200, 1), B] \ x);
tc.verifyLessThan(max(abs(r)), 1e-8);
y = sin(x / 10);
f = [ones(200, 1), B] * ([ones(200, 1), B] \ y);
tc.verifyLessThan(sqrt(mean((f - y) .^ 2)), 0.05);
end

function testPipeline(tc)
rng(4);
root = tempname;
c = onCleanup(@() rmdir(root, 's'));
in = fullfile(root, 'derivatives', 'seecat');
M = [-3 0 0 9; 0 3 0 -9; 0 0 3 -9; 0 0 0 1];
n = 24;
site = repelem({'S1'; 'S2'; 'S3'}, 8);
grp = repmat({'CTL'; 'PAT'}, 12, 1);
age = 20 + 40 * rand(n, 1);
shift = repelem([0; 1.5; -1], 8);
for i = 1:n
    sub = sprintf('%02d', i);
    d = fullfile(in, ['sub-' sub], 'func');
    mkdir(d);
    v = randn(6, 6, 6) + 5 + shift(i) + strcmp(grp{i}, 'PAT') * 0.8;
    seecat.io.write_nii(v, struct('dim', [6 6 6], 'mat', M), ...
        fullfile(d, ['sub-' sub '_task-rest_space-IXI549Space_res-3_desc-PCC_stat-z_connectivity.nii.gz']));
    seecat.io.write_nii(v + randn(6, 6, 6), struct('dim', [6 6 6], 'mat', M), ...
        fullfile(d, ['sub-' sub '_task-rest_space-IXI549Space_res-3_desc-B_stat-z_connectivity.nii.gz']));
end
P = table(strcat('sub-', arrayfun(@(i) sprintf('%02d', i), (1:n)', 'UniformOutput', false)), site, grp, age, ...
    'VariableNames', {'participant_id', 'site', 'group', 'age'});
seecat.io.write_tsv(P, fullfile(in, 'participants.tsv'));
cfg = seecat.config('harmonize');
cfg.input_dir = in;
cfg.maps = struct('desc', 'PCC', 'stat', 'z');
cfg.covariates = {'group'};
cfg.nonlinear = {'age'};
cfg.method = 'combat_gam';
cfg.mask = 'brain';
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.status, {'ok'}, S.message{1});
tc.verifyGreaterThan(S.site_effect_before, 0.9);
tc.verifyLessThan(S.site_effect_after, 0.1);
f = fullfile(in, 'sub-03', 'func', 'sub-03_task-rest_space-IXI549Space_res-3_desc-PCCComBat_stat-z_connectivity.nii.gz');
tc.verifyTrue(exist(f, 'file') == 2);
j = jsondecode(fileread(strrep(f, '.nii.gz', '.json')));
tc.verifyEqual(j.Harmonization, 'combat_gam');
tc.verifyEqual(j.Site, 'S1');
R = dir(fullfile(in, 'group', 'harmonizeComBat_PCCz_*', 'harmonizeComBat_PCCz_*_report.json'));
tc.verifyNumElements(R, 1);
% a second measure is its own unit: the first one's maps stay
cfg.maps = struct('desc', 'B', 'stat', 'z');
S2 = quiet(@() seecat.run(cfg));
tc.verifyEqual(S2.status, {'ok'});
tc.verifyTrue(exist(f, 'file') == 2);
tc.verifyTrue(exist(strrep(f, 'desc-PCCComBat', 'desc-BComBat'), 'file') == 2);
% the harmonised maps are what Statistics then selects
cfg2 = seecat.config('stat');
cfg2.name = 'h';
cfg2.input_dir = in;
cfg2.maps = struct('desc', 'PCCComBat', 'stat', 'z');
cfg2.design = 'two_sample';
cfg2.factor = 'group';
cfg2.mask = 'brain';
units = seecat.stat.plan(seecat.config(cfg2));
tc.verifyEqual(height(units.maps), n);
end

function out = quiet(fn)
[~, out] = evalc('fn()');
end
