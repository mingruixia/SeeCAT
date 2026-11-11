function tests = test_review5
% Regression tests for the findings of the 2026-11-12 review: the coverage
% check of Gradients uses the grid of the BOLD series, as the analysis does,
% not the grid the brain mask is stored on (C09), and two covered runs
% whose brain masks do not overlap still stop a group-mask analysis (C10,
% the case the manual now names).
%   results = runtests('tests/unit/test_review5.m')
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

function setup(tc)
tc.TestData.root = tempname;
tc.TestData.in = fullfile(tc.TestData.root, 'derivatives', 'seecat');
for s = 1:3
    makeRun(tc.TestData.in, sprintf('%02d', s));
end
end

function teardown(tc)
if exist(tc.TestData.root, 'dir')
    rmdir(tc.TestData.root, 's');
end
end

function testGivenMaskCoverageDoesNotDependOnTheBrainMaskGrid(tc)
% C09: the brain mask of sub-03 holds x = 6 and 9 mm only. Stored cropped
% (2x6x6) the run was left out as "no voxel of the mask", stored padded to
% the BOLD grid it was kept, with the same series and the same mask voxels
in = tc.TestData.in;
half = false(6, 6, 6);
half(1:3, :, :) = true;                            % x = -6, -3, 0 mm
mask = fullfile(tc.TestData.root, 'half_mask.nii');
seecat.io.write_nii(uint8(half), grid6(), mask, 'DataType', 'uint8');
all3 = {'sub-01_task-rest', 'sub-02_task-rest', 'sub-03_task-rest'};
for form = {'cropped', 'padded'}
    writeBrain(in, '03', form{1});
    cfg = gradientConfig(in, mask);
    cfg.mask_mode = 'given';
    cfg.output_dir = fullfile(tc.TestData.root, ['out_' form{1}]);
    [units, planned] = seecat.gradient.plan(cfg);
    tc.verifyEqual({units.runs.id}, all3, form{1});
    tc.verifyFalse(isfield(planned, 'empty_mask'), form{1});
    S = quiet(@() seecat.run(cfg));
    tc.verifyEqual(S.status, {'ok'}, [form{1} ': ' S.message{1}]);
    tc.verifyEqual(S.n_runs, 3, form{1});
    tc.verifyNumElements(dir(fullfile(cfg.output_dir, 'sub-03', 'func', '*_connectivity.nii.gz')), 2, form{1});
end
end

function testCoverageWithinTheBrainMaskIsTakenOnTheBoldGrid(tc)
% C09, modes run and group: the same brain mask gives the same answer
% whatever grid it is stored on, also at another voxel size
in = tc.TestData.in;
half = false(6, 6, 6);
half(1:3, :, :) = true;
mask = fullfile(tc.TestData.root, 'half_mask.nii');
seecat.io.write_nii(uint8(half), grid6(), mask, 'DataType', 'uint8');
writeBrain(in, '02', 'coarse');                    % the whole grid, as 3x3x3 voxels of 6 mm
for form = {'cropped', 'padded'}
    writeBrain(in, '03', form{1});                 % x = 6 and 9 mm: outside the mask
    for mode = {'run', 'group'}
        cfg = gradientConfig(in, mask);
        cfg.mask_mode = mode{1};
        [units, planned] = seecat.gradient.plan(cfg);
        label = [form{1} ' ' mode{1}];
        tc.verifyEqual(planned.empty_mask, {'sub-03_task-rest'}, label);
        tc.verifyEqual({units.runs.id}, {'sub-01_task-rest', 'sub-02_task-rest'}, label);
    end
end
N = seecat.gradient.nodes(gradientConfig(in, mask));
[runs, ~] = seecat.bids.derivative_units(gradientConfig(in, mask), 'denoised');
tc.verifyEqual(seecat.gradient.covered(runs, N, 'run'), [true true false]);
tc.verifyEqual(seecat.gradient.covered(runs, N, 'given'), [true true true]);
end

function testMaskOutsideTheBoldGridIsStillLeftOut(tc)
% C09: a mask that does not reach a run's BOLD grid still leaves it out,
% also when the run's brain mask is stored on a grid that the mask reaches
in = tc.TestData.in;
shiftBold(in, '02', 1000);                         % the series is 1 m away; its brain mask stays
mask = fullfile(tc.TestData.root, 'full_mask.nii');
seecat.io.write_nii(uint8(true(6, 6, 6)), grid6(), mask, 'DataType', 'uint8');
for mode = {'given', 'run', 'group'}
    cfg = gradientConfig(in, mask);
    cfg.mask_mode = mode{1};
    [units, planned] = seecat.gradient.plan(cfg);
    tc.verifyEqual(planned.empty_mask, {'sub-02_task-rest'}, mode{1});
    tc.verifyEqual({units.runs.id}, {'sub-01_task-rest', 'sub-03_task-rest'}, mode{1});
    S = quiet(@() seecat.run(cfg));
    tc.verifyEqual(S.status, {'ok'}, [mode{1} ': ' S.message{1}]);
    tc.verifyEqual(S.n_runs, 2, mode{1});
end
end

function testGridOfAnImageWithoutItsData(tc)
% seecat.io.nii_grid gives the grid spm_vol gives, for .nii and .nii.gz
V0 = struct('dim', [5 6 7], 'mat', [0 -2 0 10; 3 0 0 -20; 0 0 4 5; 0 0 0 1]);
Y = rand(5, 6, 7, 3);
for ext = {'.nii', '.nii.gz'}
    f = fullfile(tc.TestData.root, ['grid' ext{1}]);
    seecat.io.write_nii(Y, V0, f);
    [~, V] = seecat.io.read_nii(f);
    G = seecat.io.nii_grid(f);
    tc.verifyEqual(G.dim(1:3), V(1).dim(1:3), ext{1});
    tc.verifyEqual(G.mat, V(1).mat, 'AbsTol', 1e-10, ext{1});
    tc.verifyEqual(G.mat, V0.mat, 'AbsTol', 1e-4, ext{1});
    m = seecat.io.read_nii(f, 'Ref', G, 'Volumes', 1);     % usable as a reference grid
    tc.verifyEqual(m, Y(:, :, :, 1), 'AbsTol', 1e-4, ext{1});
end
tc.verifyError(@() seecat.io.nii_grid(fullfile(tc.TestData.root, 'none.nii.gz')), 'SeeCAT:read');
end

function testCoveredRunsWithoutCommonBrainVoxelsStopGroupMode(tc)
% C10: both runs have voxels of the mask, yet their brain masks share none:
% mask_mode group stops (SeeCAT:conn), run and given go on
in = tc.TestData.in;
writeBrain(in, '01', 'low');
writeBrain(in, '02', 'high');
mask = fullfile(tc.TestData.root, 'full_mask.nii');
seecat.io.write_nii(uint8(true(6, 6, 6)), grid6(), mask, 'DataType', 'uint8');
cfg = gradientConfig(in, mask);
cfg.subjects = {'01', '02'};
cfg.mask_mode = 'group';
tc.verifyError(@() seecat.gradient.plan(cfg), 'SeeCAT:conn');
tc.verifySubstring(errorMessage(@() seecat.gradient.plan(cfg)), 'no voxel in common');
for mode = {'run', 'given'}
    cfg.mask_mode = mode{1};
    [units, planned] = seecat.gradient.plan(cfg);
    tc.verifyNumElements(units.runs, 2, mode{1});
    tc.verifyFalse(isfield(planned, 'empty_mask'), mode{1});
end
end

function cfg = gradientConfig(in, mask)
cfg = seecat.config('gradient');
cfg.input_dir = in;
cfg.n_workers = 0;
cfg.node_size = 3;
cfg.n_components = 3;
cfg.n_maps = 2;
cfg.mask = mask;
end

function V = grid6()
% The grid of the runs: 6x6x6 voxels of 3 mm, x = -6 ... 9 mm
V = struct('dim', [6 6 6], 'mat', [3 0 0 -9; 0 3 0 -9; 0 0 3 -9; 0 0 0 1]);
end

function writeBrain(in, sub, form)
% Write a run's brain mask: 'cropped' and 'padded' hold x = 6 and 9 mm, on
% a 2x6x6 grid or on the BOLD grid; 'coarse' the whole grid as 6 mm voxels;
% 'low' and 'high' the halves x <= 0 and x > 0 mm
f = fullfile(in, ['sub-' sub], 'func', ['sub-' sub '_task-rest_space-IXI549Space_res-3_desc-brain_mask.nii.gz']);
V = grid6();
switch form
    case 'cropped'
        V.dim = [2 6 6];
        V.mat(1, 4) = 3;
        b = true(2, 6, 6);
    case 'padded'
        b = false(6, 6, 6);
        b(5:6, :, :) = true;
    case 'coarse'
        V = struct('dim', [3 3 3], 'mat', [6 0 0 -10.5; 0 6 0 -10.5; 0 0 6 -10.5; 0 0 0 1]);
        b = true(3, 3, 3);
    case 'low'
        b = false(6, 6, 6);
        b(1:3, :, :) = true;
    case 'high'
        b = false(6, 6, 6);
        b(4:6, :, :) = true;
end
seecat.io.write_nii(uint8(b), V, f, 'DataType', 'uint8');
end

function shiftBold(in, sub, mm)
% Move a run's BOLD series MM mm along x; its brain mask stays
f = fullfile(in, ['sub-' sub], 'func', ['sub-' sub '_task-rest_space-IXI549Space_res-3_desc-denoised_bold.nii.gz']);
[data, V] = seecat.io.read_nii(f);
V = V(1);
V.mat(1, 4) = V.mat(1, 4) + mm;
seecat.io.write_nii(data, V, f);
end

function makeRun(in, sub)
% 6x6x6 voxels at 3 mm; the two ends of x follow two signals
rng(str2double(sub));
d = fullfile(in, ['sub-' sub], 'func');
mkdir(d);
stem = fullfile(d, ['sub-' sub '_task-rest']);
V = grid6();
nT = 120;
a = randn(nT, 1);
b = randn(nT, 1);
w = reshape(linspace(1, 0, 6), 6, 1, 1);
Y = reshape(a, 1, 1, 1, nT) .* w + reshape(b, 1, 1, 1, nT) .* (1 - w) + 0.7 * randn(6, 6, 6, nT);
seecat.io.write_nii(Y, V, [stem '_space-IXI549Space_res-3_desc-denoised_bold.nii.gz']);
seecat.io.write_nii(uint8(true(6, 6, 6)), V, [stem '_space-IXI549Space_res-3_desc-brain_mask.nii.gz'], 'DataType', 'uint8');
T = table();
T.framewise_displacement = rand(nT, 1);
T.censor = zeros(nT, 1);
seecat.io.write_tsv(T, [stem '_desc-confounds_timeseries.tsv']);
end

function out = quiet(fn)
[~, out] = evalc('fn()');
end

function msg = errorMessage(fn)
msg = '';
try
    fn();
catch err
    msg = err.message;
end
end
