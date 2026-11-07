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
cfg.group_mask = true;
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
