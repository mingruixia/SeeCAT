function tests = test_view
% Tests for the viewer model (seecat.view.Model) and atlases, headless.
%   results = runtests('tests/unit/test_view.m')
tests = functiontests(localfunctions);
end

function setupOnce(tc)
addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'SeeCAT'));
spmDir = getenv('SEECAT_SPM');
if isempty(spmDir)
    spmDir = 'D:/verysync/dropbox/SciTools/MatlabToolbox/spm';
end
addpath(spmDir);
tc.TestData.d = tempname;
mkdir(tc.TestData.d);
% A T map with a blob, on a 3 mm grid, with a SeeCAT JSON sidecar
rng(1);
dim = [40 48 40];
M = [-3 0 0 60; 0 3 0 -84; 0 0 3 -60; 0 0 0 1];
t = randn(dim);
spm_smooth(t, t, [2 2 2]);
t = t / std(t(:)) ;
[i, j, k] = ndgrid(1:dim(1), 1:dim(2), 1:dim(3));
t = t + 8 * exp(-((i - 20) .^ 2 + (j - 30) .^ 2 + (k - 25) .^ 2) / 8);
f = fullfile(tc.TestData.d, 'grp_contrast-x_stat-t_statmap.nii');
seecat.io.write_nii(t, struct('mat', M, 'dim', dim), f);
mask = true(dim);
G = struct('res', randn(12, nnz(mask)), 'ResSS', [], 'trRV', 10);
G.ResSS = sum(G.res .^ 2, 1);
S = seecat.stat.smoothness(G, mask, struct('mat', M, 'dim', dim));
seecat.util.write_json(strrep(f, '.nii', '.json'), struct('Statistic', 'T', 'DegreesOfFreedom', [1 10], ...
    'Resels', S.R, 'FWHMvoxels', S.FWHM, 'SearchVoxels', S.nVox));
tc.TestData.f = f;
tc.TestData.S = S;
tc.TestData.t = t;
tc.TestData.M = M;
end

function teardownOnce(tc)
rmdir(tc.TestData.d, 's');
end

function testThresholdsEqualInference(tc)
m = seecat.view.Model();
i = m.addLayer(tc.TestData.f);
tc.verifyEqual(m.layers(i).stat.type, 'T');
[~, k] = max(abs(m.layers(i).shown(:)));             % the cursor starts at the strongest voxel
[a, b, c] = ind2sub(size(tc.TestData.t), k);
tc.verifyEqual(m.cursor, (tc.TestData.M(1:3, :) * [a; b; c; 1])', 'AbsTol', 1e-9);
m.setThreshold(i, struct('mode', 'p', 'value', 0.001, 'sign', 'pos', 'correction', 'cluster_fwe', ...
    'alpha', 0.05, 'cdt_p', 0.001));
t = tc.TestData.t;
mask = t ~= 0;
c = struct('type', 't', 'df', [1 10], 'stat', t(mask)', 'p', max(spm_Tcdf(-t(mask)', 10), realmin));
I = seecat.stat.inference(c, mask, struct('mat', tc.TestData.M, 'dim', size(t)), tc.TestData.S, ...
    struct('method', 'cluster_fwe', 'alpha', 0.05, 'cdt_p', 0.001));
tc.verifyEqual(m.layers(i).result.height, I.height, 'AbsTol', 1e-10);
tc.verifyEqual(m.layers(i).shown ~= 0, I.label > 0);
T = m.clusters(i);
tc.verifyGreaterThanOrEqual(height(T), 1);
% uncorrected p: two-sided split when both signs are shown
m.setThreshold(i, struct('mode', 'p', 'value', 0.01, 'sign', 'both', 'correction', 'none'));
tc.verifyEqual(m.layers(i).result.height, [spm_u(0.005, [1 10], 'T'), -spm_u(0.005, [1 10], 'T')], 'AbsTol', 1e-10);
end

function testLegacyHeaderIsRead(tc)
d = tc.TestData.d;
f = fullfile(d, 'legacy_T.nii');
seecat.io.write_nii(tc.TestData.t, struct('mat', tc.TestData.M, 'dim', size(tc.TestData.t)), f, ...
    'Descrip', 'CAT{T_[8.0]}{dLh_0.114607}{FWHMx_10.7FWHMy_10.6FWHMz_10.4mm}');
m = seecat.view.Model();
i = m.addLayer(f);
tc.verifyEqual(m.layers(i).stat.type, 'T');
tc.verifyEqual(m.layers(i).stat.df, [1 8]);
tc.verifyEqual(m.layers(i).stat.S.FWHM, [10.7 10.6 10.4] / 3, 'AbsTol', 1e-12);
end

function testPixelAndMmAreInverse(tc)
m = seecat.view.Model();
m.addLayer(tc.TestData.f);
m.cursor = [12 -40 20];
for r = [false true]
    m.radiological = r;
    for v = {'axial', 'coronal', 'sagittal'}
        [~, pos] = m.slice(v{1});
        tc.verifyEqual(m.mmAt(v{1}, pos), m.cursor, 'AbsTol', 1e-9, v{1});
    end
end
% radiological flips left-right in axial and coronal views only
m.radiological = false;
[a, p1] = m.slice('axial');
m.radiological = true;
[b, p2] = m.slice('axial');
tc.verifyEqual(b, flip(a, 2));
tc.verifyEqual(p1(1) + p2(1), size(a, 2) + 1);
end

function testUnderlayFollowsSpace(tc)
d = tc.TestData.d;
f = fullfile(d, 'sub-01_space-MNI152NLin2009cAsym_desc-x_stat-z_statmap.nii');
copyfile(tc.TestData.f, f);
m = seecat.view.Model();
m.addLayer(f);
tc.verifyEqual(m.underlay.name, 'mni2009c');
m2 = seecat.view.Model();
m2.addLayer(tc.TestData.f);
tc.verifyEqual(m2.underlay.name, 'ch2');
end

function testAtlasLabels(tc)
m = seecat.view.Model();
s = m.labelAt([0 -53 26]);                       % posterior cingulate / precuneus
tc.verifySubstring(s, 'Neuromorphometrics: ');
tc.verifyTrue(contains(s, 'precuneus') || contains(s, 'posterior cingulate'), s);
tc.verifyEqual(m.labelAt([0 0 200]), '');        % outside every atlas
end
