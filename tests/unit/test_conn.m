function tests = test_conn
% Tests for seecat.conn (degree, seed FC) and the fc and degree pipelines.
%   results = runtests('tests/unit/test_conn.m')
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

function testDegreeEqualsBruteForce(tc)
rng(1);
T = 80;
V = 300;
Y = randn(T, V) + randn(T, 1) * 0.6;          % shared signal: many r above 0.2
Y(:, 7) = 5;                                   % no variance: no connections
xyz = rand(3, V) * 100;
o = struct('threshold', 0.25, 'sign', {{'positive', 'absolute', 'negative'}}, ...
    'weight', {{'binary', 'weighted'}}, 'exclude_local_mm', 10, 'distance_edges', [0 40 Inf], 'block', 37);
[D, maps] = seecat.conn.degree(Y, xyz, o);
tc.verifySize(D, [V 12]);
ref = bruteForce(Y, xyz, o, maps);
tc.verifyEqual(D, ref, 'AbsTol', 1e-9);
tc.verifyEqual(D(7, :), zeros(1, 12));
% Without distance options the voxel itself is still excluded
[D1, m1] = seecat.conn.degree(Y, xyz, struct('threshold', 0.25, 'block', 50));
tc.verifyEqual(D1, bruteForce(Y, xyz, struct('threshold', 0.25, 'exclude_local_mm', 0, ...
    'distance_edges', [0 Inf]), m1), 'AbsTol', 1e-9);
end

function testSeedFc(tc)
rng(2);
T = 100;
s = randn(T, 1);
Y = [s + 0.1 * randn(T, 3), -s + randn(T, 1), randn(T, 1), zeros(T, 1)];
seeds = false(6, 2);
seeds(1:3, 1) = true;
seeds(6, 2) = true;                            % only a voxel without signal
[r, z, empty] = seecat.conn.seed_fc(Y, seeds);
tc.verifyEqual(empty, [false true]);
tc.verifyEqual(r(1, 4), corr(mean(Y(:, 1:3), 2), Y(:, 4)), 'AbsTol', 1e-12);
tc.verifyLessThan(r(1, 4), -0.5);
tc.verifyEqual(r(1, 6), 0);                    % no variance
tc.verifyEqual(r(2, :), zeros(1, 6));
tc.verifyTrue(all(isfinite(z(:))));
tc.verifyEqual(z, atanh(r), 'AbsTol', 1e-12);
end

function testPipelinesOnDerivatives(tc)
root = tempname;
c = onCleanup(@() rmdir(root, 's'));
in = fullfile(root, 'derivatives', 'seecat');
makeRun(in, '01');
makeRun(in, '02');
cfg = seecat.config('fc');
cfg.input_dir = in;
cfg.seeds = struct('name', {'A', 'B'}, 'center', {[-6 -6 -6], [6 6 6]}, 'radius', 4);
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.status, {'ok'; 'ok'});
tc.verifyEqual(S.n_kept, [45; 45]);            % 5 censored frames dropped
f = fullfile(in, 'sub-01', 'func', 'sub-01_task-rest_space-IXI549Space_res-3_desc-A_stat-z_connectivity.nii.gz');
tc.verifyTrue(exist(f, 'file') == 2);
j = jsondecode(fileread(strrep(f, '.nii.gz', '.json')));
tc.verifyEqual(j.FramesUsed, 45);
tc.verifyEqual(j.Seed.RadiusMM, 4);

cfg = seecat.config('degree');
cfg.input_dir = in;
cfg.mask = 'brain';
cfg.sign = {'positive', 'negative'};
cfg.weight = {'binary'};
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.status, {'ok'; 'ok'});
d = dir(fullfile(in, 'sub-02', 'func', '*_desc-deg*_connectivity.nii.gz'));
names = sort({d.name})';
tc.verifyEqual(numel(names), 8);               % 2 signs x raw/z x unsmoothed/Sm6
tc.verifyTrue(any(contains(names, 'desc-degNegBinR0p2Sm6_stat-z')));
z = seecat.io.read_nii(fullfile(in, 'sub-02', 'func', ...
    'sub-02_task-rest_space-IXI549Space_res-3_desc-degPosBinR0p2_stat-z_connectivity.nii.gz'));
m = seecat.io.read_nii(fullfile(in, 'sub-02', 'func', 'sub-02_task-rest_space-IXI549Space_res-3_desc-brain_mask.nii.gz')) > 0;
tc.verifyEqual(mean(z(m)), 0, 'AbsTol', 1e-5);
tc.verifyEqual(std(z(m)), 1, 'AbsTol', 1e-4);
end

function testDegreeGroupMask(tc)
% Two runs whose brain masks differ: without the group mask 64 and 48
% voxels, with it 48 in both
in = tempname;
c = onCleanup(@() rmdir(in, 's'));
makeRun(in, '01');
makeRun(in, '02');
f = fullfile(in, 'sub-02', 'func', 'sub-02_task-rest_space-IXI549Space_res-3_desc-brain_mask.nii.gz');
[m, V] = seecat.io.read_nii(f);
m(5, :, :) = 0;
seecat.io.write_nii(uint8(m), V(1), f, 'DataType', 'uint8');
cfg = seecat.config('degree');
cfg.input_dir = in;
cfg.mask = 'brain';
cfg.weight = {'binary'};
cfg.smooth_fwhm = 0;
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.n_voxels, [64; 48]);
cfg.mask_mode = 'group';
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.status, {'ok'; 'ok'});
tc.verifyEqual(S.n_voxels, [48; 48]);
g = dir(fullfile(in, 'group', 'masks', 'space-IXI549Space_res-3_desc-group*_mask.nii.gz'));
tc.verifyNumElements(g, 1);
gm = seecat.io.read_nii(fullfile(g.folder, g.name)) > 0;
tc.verifyEqual(nnz(gm), 48);
j = jsondecode(fileread(fullfile(g.folder, strrep(g.name, '.nii.gz', '.json'))));
tc.verifyEqual(j.NumberOfRuns, 2);
for s = {'01', '02'}
    z = seecat.io.read_nii(fullfile(in, ['sub-' s{1}], 'func', ...
        ['sub-' s{1} '_task-rest_space-IXI549Space_res-3_desc-degPosBinR0p2_stat-z_connectivity.nii.gz']));
    tc.verifyEqual(z ~= 0, gm, s{1});
end
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.status, {'skipped'; 'skipped'});
% one subject only: another group mask, and the first one is left as it is
t = g.datenum;
cfg.subjects = {'01'};
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.n_voxels, 64);
tc.verifyNumElements(dir(fullfile(in, 'group', 'masks', '*_mask.nii.gz')), 2);
tc.verifyEqual(dir(fullfile(g.folder, g.name)).datenum, t);
end

function testSeedFcGroupMask(tc)
% The brain mask of sub-02 lacks one slab: with the group mask, both runs'
% maps cover the same 48 voxels; without it, sub-01's covers 64
in = tempname;
c = onCleanup(@() rmdir(in, 's'));
makeRun(in, '01');
makeRun(in, '02');
f = fullfile(in, 'sub-02', 'func', 'sub-02_task-rest_space-IXI549Space_res-3_desc-brain_mask.nii.gz');
[m, V] = seecat.io.read_nii(f);
m(5, :, :) = 0;
seecat.io.write_nii(uint8(m), V(1), f, 'DataType', 'uint8');
cfg = seecat.config('fc');
cfg.input_dir = in;
cfg.seeds = struct('name', 'A', 'center', [0 0 0], 'radius', 6);
map = @(s) seecat.io.read_nii(fullfile(in, ['sub-' s], 'func', ...
    ['sub-' s '_task-rest_space-IXI549Space_res-3_desc-A_stat-z_connectivity.nii.gz']));
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.status, {'ok'; 'ok'});
tc.verifyEqual(nnz(map('01')), 64);
cfg.mask_mode = 'group';
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.status, {'ok'; 'ok'});
g = dir(fullfile(in, 'group', 'masks', '*_desc-group*_mask.nii.gz'));
gm = seecat.io.read_nii(fullfile(g.folder, g.name)) > 0;
tc.verifyEqual(nnz(gm), 48);
for s = {'01', '02'}
    tc.verifyEqual(map(s{1}) ~= 0, gm, s{1});
end
j = jsondecode(fileread(fullfile(in, 'sub-01', 'func', ...
    'sub-01_task-rest_space-IXI549Space_res-3_desc-A_stat-z_connectivity.json')));
tc.verifyEqual(j.GroupMask, ['bids:seecat:group/masks/' g.name]);
end

function testDegreeMaskAsGiven(tc)
% A mask of 80 voxels, 16 of them outside the brain masks (64 voxels).
% sub-02 has signal there (as fMRIPrep data can), sub-01 has not
[in, mf, c] = maskAsGivenData(); %#ok<ASGLU>
cfg = seecat.config('degree');
cfg.input_dir = in;
cfg.mask = mf;
cfg.weight = {'binary'};
cfg.smooth_fwhm = 0;
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.n_voxels, [64; 64]);          % the mask within each brain mask
cfg.mask_mode = 'given';
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.status, {'ok'; 'ok'});
tc.verifyEqual(S.n_voxels, [80; 80]);          % the mask as given
file = @(s, k) fullfile(in, ['sub-' s], 'func', ...
    ['sub-' s '_task-rest_space-IXI549Space_res-3_desc-degPosBinR0p2_stat-' k '_connectivity.nii.gz']);
raw1 = seecat.io.read_nii(file('01', 'raw'));
raw2 = seecat.io.read_nii(file('02', 'raw'));
tc.verifyTrue(all(raw1(6, 2:5, 2:5) == 0, 'all'));     % no signal: degree 0
tc.verifyTrue(all(raw2(6, 2:5, 2:5) > 0, 'all'));      % signal outside the brain mask is used
z1 = seecat.io.read_nii(file('01', 'z'));
d = raw1(2:5, 2:5, 2:5);
z = z1(2:5, 2:5, 2:5);
tc.verifyEqual(double(z(:)), (double(d(:)) - mean(d(:))) / std(double(d(:))), 'AbsTol', 1e-4);  % over voxels with signal
tc.verifyTrue(all(z1(6, 2:5, 2:5) == 0, 'all'));
j = jsondecode(fileread(strrep(file('01', 'raw'), '.nii.gz', '.json')));
tc.verifyEqual(j.MaskMode, 'given');
tc.verifyEqual([j.Voxels j.VoxelsWithSignal], [80 64]);
% 'given' needs a mask other than the subject's brain mask
cfg.mask = 'brain';
tc.verifyError(@() quiet(@() seecat.run(cfg)), 'SeeCAT:conn');
% the flags of earlier 2.1 development builds become mask_mode
old = rmfield(cfg, 'mask_mode');
old.mask_only = true;
tc.verifyEqual(seecat.config(old).mask_mode, 'given');
old = rmfield(old, 'mask_only');
old.group_mask = true;
c2 = seecat.config(old);
tc.verifyEqual(c2.mask_mode, 'group');
tc.verifyFalse(isfield(c2, 'group_mask'));
cfg.mask_mode = 'other';
tc.verifyError(@() quiet(@() seecat.run(cfg)), ?MException);
end

function testSeedFcMaskAsGiven(tc)
% The seed is one voxel outside the brain masks, where sub-02 has signal:
% it is empty unless the mask is used as given
[in, mf, c] = maskAsGivenData(); %#ok<ASGLU>
cfg = seecat.config('fc');
cfg.input_dir = in;
cfg.mask = mf;
cfg.seeds = struct('name', 'A', 'center', [-9 0 0], 'radius', 1);   % voxel (6, 3, 3)
map = @(s) seecat.io.read_nii(fullfile(in, ['sub-' s], 'func', ...
    ['sub-' s '_task-rest_space-IXI549Space_res-3_desc-A_stat-z_connectivity.nii.gz']));
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.status, {'ok'; 'ok'});
tc.verifyEqual(S.empty_seeds, [1; 1]);
cfg.seeds = struct('name', 'A', 'center', [0 0 0], 'radius', 6);
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.empty_seeds, [0; 0]);
tc.verifyEqual(nnz(map('02')), 64);              % the mask within the brain mask
cfg.mask_mode = 'given';
cfg.seeds = struct('name', 'A', 'center', [-9 0 0], 'radius', 1);
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.status, {'ok'; 'ok'});
tc.verifyEqual(S.empty_seeds, [1; 0]);           % sub-01 has no signal there
m2 = map('02');
tc.verifyEqual(nnz(m2), 80);                     % the whole mask
tc.verifyGreaterThan(m2(6, 3, 3), 3);            % the seed itself
j = jsondecode(fileread(fullfile(in, 'sub-02', 'func', ...
    'sub-02_task-rest_space-IXI549Space_res-3_desc-A_stat-z_connectivity.json')));
tc.verifyEqual(j.MaskMode, 'given');
cfg.seeds = struct('name', 'A', 'center', [0 0 0], 'radius', 6);
S = quiet(@() seecat.run(cfg));
m1 = map('01');
tc.verifyEqual(nnz(m1), 64);                     % no signal in the slab outside sub-01's brain
tc.verifyTrue(all(m1(6, 2:5, 2:5) == 0, 'all'));
end

function [in, mf, c] = maskAsGivenData()
% Two runs (brain mask 2:5 in each direction), a mask file of the voxels
% 2:6 x 2:5 x 2:5, and signal in the slab x = 6 for sub-02 only
in = tempname;
c = onCleanup(@() rmdir(in, 's'));
makeRun(in, '01');
makeRun(in, '02');
f = fullfile(in, 'sub-02', 'func', 'sub-02_task-rest_space-IXI549Space_res-3_desc-denoised_bold.nii.gz');
[Y, V] = seecat.io.read_nii(f);
rng(5);
Y(6, 2:5, 2:5, :) = Y(5, 2:5, 2:5, :) + 0.5 * randn(1, 4, 4, size(Y, 4));
seecat.io.write_nii(Y, V(1), f);
m = false(6, 6, 6);
m(2:6, 2:5, 2:5) = true;
mf = fullfile(in, 'mymask.nii');
seecat.io.write_nii(uint8(m), V(1), mf, 'DataType', 'uint8');
end

function testGroupMaskFollowsTheGrid(tc)
% Moving every run 100 mm along x (same arrays, same paths) must rewrite
% the group mask on the new grid: the results then equal those of a fresh
% output folder (2026-11-09 review, C01)
in = tempname;
c = onCleanup(@() rmdir(in, 's'));
makeRun(in, '01');
makeRun(in, '02');
cfg = seecat.config('fc');
cfg.input_dir = in;
cfg.mask_mode = 'group';
cfg.seeds = struct('name', 'A', 'center', [0 0 0], 'radius', 6);
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.empty_seeds, [0; 0]);
for s = {'01', '02'}
    for f = {'desc-denoised_bold', 'desc-brain_mask'}
        p = fullfile(in, ['sub-' s{1}], 'func', ['sub-' s{1} '_task-rest_space-IXI549Space_res-3_' f{1} '.nii.gz']);
        [Y, V] = seecat.io.read_nii(p);
        V = V(1);
        V.mat(1, 4) = V.mat(1, 4) + 100;
        if contains(f{1}, 'mask')
            seecat.io.write_nii(uint8(Y), V, p, 'DataType', 'uint8');
        else
            seecat.io.write_nii(Y, V, p);
        end
    end
end
cfg.seeds.center = [100 0 0];
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.status, {'ok'; 'ok'});
tc.verifyEqual(S.empty_seeds, [0; 0]);
g = dir(fullfile(in, 'group', 'masks', '*_desc-group*_mask.nii.gz'));
tc.verifyNumElements(g, 1);
[~, Vg] = seecat.io.read_nii(fullfile(g.folder, g.name));
tc.verifyEqual(Vg(1).mat(1, 4), 109, 'AbsTol', 1e-4);
tc.verifyEmpty(dir(fullfile(g.folder, 'tmp*')));        % no temporary file left
fresh = fullfile(in, 'fresh');
cfg.output_dir = fresh;
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.status, {'ok'; 'ok'});
rel = fullfile('sub-01', 'func', 'sub-01_task-rest_space-IXI549Space_res-3_desc-A_stat-z_connectivity.nii.gz');
tc.verifyEqual(seecat.io.read_nii(fullfile(in, rel)), seecat.io.read_nii(fullfile(fresh, rel)), 'AbsTol', 1e-6);
end

function testDegreeConstantMapsAreNotNaN(tc)
% No connection reaches r = 0.9999: every degree is 0, so the z map is
% undefined; it is written as 0 and flagged, never as NaN (review C02)
in = tempname;
c = onCleanup(@() rmdir(in, 's'));
makeRun(in, '01');
cfg = seecat.config('degree');
cfg.input_dir = in;
cfg.mask = 'brain';
cfg.threshold = 0.9999;
cfg.weight = {'binary'};
cfg.smooth_fwhm = 0;
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.status, {'ok'});
tc.verifyEqual(S.n_constant_maps, 1);
f = fullfile(in, 'sub-01', 'func', 'sub-01_task-rest_space-IXI549Space_res-3_desc-degPosBinR0p9999_stat-z_connectivity');
z = seecat.io.read_nii([f '.nii.gz']);
tc.verifyTrue(all(isfinite(z(:))));
tc.verifyTrue(all(z(:) == 0));
j = jsondecode(fileread([f '.json']));
tc.verifyFalse(j.ZScoreDefined);
cfg.threshold = 0.2;                       % a normal network: defined
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.n_constant_maps, 0);
j = jsondecode(fileread(strrep([f '.json'], 'R0p9999', 'R0p2')));
tc.verifyTrue(j.ZScoreDefined);
end

function testEmptyAnalysisMaskFails(tc)
% A mask that lies 1000 mm away has no voxel on the BOLD grid: every mask
% mode of Degree and Seed FC fails, without maps (2026-11-10 review, C04)
root = tempname;
c = onCleanup(@() rmdir(root, 's'));
in = fullfile(root, 'in');
makeRun(in, '01');
makeRun(in, '02');
M = [-3 0 0 1009; 0 3 0 -9; 0 0 3 -9; 0 0 0 1];
far = fullfile(root, 'far_mask.nii');
seecat.io.write_nii(uint8(ones(6, 6, 6)), struct('dim', [6 6 6], 'mat', M), far, 'DataType', 'uint8');
for p = {'degree', 'fc'}
    for mode = {'run', 'group', 'given'}
        cfg = seecat.config(p{1});
        cfg.input_dir = in;
        cfg.output_dir = fullfile(root, [p{1} '-' mode{1}]);
        cfg.mask = far;
        cfg.mask_mode = mode{1};
        if strcmp(p{1}, 'degree')
            cfg.smooth_fwhm = 0;
        else
            cfg.seeds = struct('name', 'A', 'center', [0 0 0], 'radius', 6);   % a valid seed
        end
        S = quiet(@() seecat.run(cfg));
        tc.verifyEqual(S.status, {'failed'; 'failed'}, [p{1} ' ' mode{1}]);
        tc.verifyTrue(all(contains(S.message, 'analysis mask')), [p{1} ' ' mode{1}]);
        tc.verifyEmpty(dir(fullfile(cfg.output_dir, 'sub-*', 'func', '*_connectivity.nii.gz')), [p{1} ' ' mode{1}]);
    end
end
% A seed outside a small but non-empty target mask is still valid
small = false(6, 6, 6);
small(2:3, 2:5, 2:5) = true;
[~, V] = seecat.io.read_nii(fullfile(in, 'sub-01', 'func', 'sub-01_task-rest_space-IXI549Space_res-3_desc-brain_mask.nii.gz'));
mf = fullfile(root, 'small_mask.nii');
seecat.io.write_nii(uint8(small), V(1), mf, 'DataType', 'uint8');
cfg = seecat.config('fc');
cfg.input_dir = in;
cfg.output_dir = fullfile(root, 'small');
cfg.mask = mf;
cfg.seeds = struct('name', 'A', 'center', [-6 0 0], 'radius', 1);           % voxel (5, 3, 3)
for mode = {'run', 'given'}
    cfg.mask_mode = mode{1};
    S = quiet(@() seecat.run(cfg));
    tc.verifyEqual(S.status, {'ok'; 'ok'}, mode{1});
    tc.verifyEqual(S.empty_seeds, [0; 0], mode{1});
end
end

function testTooFewFramesFail(tc)
% With 0 or 1 frame left after censoring no correlation can be computed:
% the run fails without maps; 2 frames are the minimum (review C05)
root = tempname;
c = onCleanup(@() rmdir(root, 's'));
in = fullfile(root, 'in');
makeRun(in, '01');
tsv = fullfile(in, 'sub-01', 'func', 'sub-01_task-rest_desc-confounds_timeseries.tsv');
T0 = seecat.io.read_tsv(tsv);
for kept = [0 1 2]
    T = T0;
    T.censor = ones(height(T), 1);
    T.censor(1:kept) = 0;
    seecat.io.write_tsv(T, tsv);
    for p = {'degree', 'fc'}
        cfg = seecat.config(p{1});
        cfg.input_dir = in;
        cfg.output_dir = fullfile(root, sprintf('%s-%d', p{1}, kept));
        cfg.mask = 'brain';
        if strcmp(p{1}, 'degree')
            cfg.smooth_fwhm = 0;
        else
            cfg.seeds = struct('name', 'A', 'center', [0 0 0], 'radius', 6);
        end
        S = quiet(@() seecat.run(cfg));
        out = dir(fullfile(cfg.output_dir, 'sub-01', 'func', '*_connectivity.nii.gz'));
        if kept < 2
            tc.verifyEqual(S.status, {'failed'}, sprintf('%s %d', p{1}, kept));
            tc.verifyTrue(contains(S.message{1}, sprintf('keeps %d of 50 frames', kept)));
            tc.verifyEmpty(out);
        else
            tc.verifyEqual(S.status, {'ok'}, sprintf('%s %d', p{1}, kept));
            tc.verifyNotEmpty(out);
        end
    end
end
end

function testSeedsFromJsonConfig(tc)
f = [tempname '.json'];
c = onCleanup(@() delete(f));
fid = fopen(f, 'w');
fprintf(fid, '{"pipeline": "fc", "seeds": [{"name": "PCC", "center": [0, -53, 26], "radius": 6}, {"name": "ROI", "file": "x.nii"}]}');
fclose(fid);
cfg = seecat.config(f);
tc.verifySize(cfg.seeds, [1 2]);
tc.verifyEqual(cfg.seeds(1).center, [0 -53 26]);
tc.verifyEqual(cfg.seeds(2).file, 'x.nii');
tc.verifyEmpty(cfg.seeds(2).center);
end

%% Helpers -------------------------------------------------------------------

function ref = bruteForce(Y, xyz, o, maps)
% Straight from the definition, one voxel at a time
V = size(Y, 2);
r = corr(Y);
r(~isfinite(r)) = 0;
ref = zeros(V, numel(maps));
for j = 1:V
    d = sqrt(sum((xyz - xyz(:, j)) .^ 2, 1));
    for k = 1:numel(maps)
        m = maps(k);
        x = r(j, :);
        switch m.sign
            case 'absolute'
                x = abs(x);
            case 'negative'
                x = -x;
        end
        x(x < o.threshold) = 0;
        x(d < o.exclude_local_mm) = 0;
        x(~(d > m.lo & d <= m.hi)) = 0;
        if strcmp(m.weight, 'binary')
            ref(j, k) = nnz(x > 0);
        else
            ref(j, k) = sum(x);
        end
    end
end
ref(~(std(Y) > 0), :) = 0;
end

function makeRun(in, sub)
% A SeeCAT-derivatives-like run: 6x6x6, 50 frames, frames 20-24 censored
rng(str2double(sub));
d = fullfile(in, ['sub-' sub], 'func');
mkdir(d);
stem = fullfile(d, ['sub-' sub '_task-rest']);
M = [-3 0 0 9; 0 3 0 -9; 0 0 3 -9; 0 0 0 1];
V = struct('dim', [6 6 6], 'mat', M);
nT = 50;
Y = randn(6, 6, 6, nT) + reshape(randn(nT, 1), 1, 1, 1, nT) * 0.8;
mask = false(6, 6, 6);
mask(2:5, 2:5, 2:5) = true;
Y(repmat(~mask, 1, 1, 1, nT)) = 0;
seecat.io.write_nii(Y, V, [stem '_space-IXI549Space_res-3_desc-denoised_bold.nii.gz']);
seecat.io.write_nii(uint8(mask), V, [stem '_space-IXI549Space_res-3_desc-brain_mask.nii.gz'], 'DataType', 'uint8');
T = table();
T.framewise_displacement = rand(nT, 1);
T.censor = zeros(nT, 1);
T.censor(20:24) = 1;
seecat.io.write_tsv(T, [stem '_desc-confounds_timeseries.tsv']);
end

function out = quiet(fn)
[~, out] = evalc('fn()');
end
