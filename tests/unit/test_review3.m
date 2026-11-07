function tests = test_review3
% Regression tests for the findings of the 2026-11-07 review: files named
% by a relative path are followed (U02), and an edit to SeeCAT's code in a
% running MATLAB session is found (U04). U01 and U03 (NIfTI import) are in
% test_nifti.
%   results = runtests('tests/unit/test_review3.m')
tests = functiontests(localfunctions);
end

function setupOnce(~)
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..', '..', 'SeeCAT'));
addpath(fullfile(here, '..', 'fixtures'));
spmDir = getenv('SEECAT_SPM');
if isempty(spmDir)
    spmDir = 'D:/verysync/dropbox/SciTools/MatlabToolbox/spm';
end
addpath(spmDir);
end

function setup(tc)
tc.TestData.root = tempname;
mkdir(tc.TestData.root);
tc.TestData.cwd = pwd;
end

function teardown(tc)
cd(tc.TestData.cwd);
if exist(tc.TestData.root, 'dir')
    rmdir(tc.TestData.root, 's');
end
end

%% U02: every way of writing a path names the same file; keywords are not files
function testRelativePathsAreInputs(tc)
root = tc.TestData.root;
d = fullfile(root, 'rois');
writeText(fullfile(d, 'seed.nii'), 'a');
cd(d);
abs_ = fullfile(d, 'seed.nii');
for p = {abs_, 'seed.nii', fullfile('.', 'seed.nii'), fullfile('..', 'rois', 'seed.nii'), './seed.nii'}
    [~, files] = seecat.util.input_fingerprint(struct(), struct('seed', p{1}, 'mask', 'gm', 'kind', 'auto'));
    tc.verifyEqual(files, {seecat.util.canonical_path(abs_)}, p{1});
end
h1 = seecat.util.input_fingerprint(struct(), struct('seed', 'seed.nii'));
writeText(fullfile(d, 'seed.nii'), 'b');                % same size
tc.verifyNotEqual(seecat.util.input_fingerprint(struct(), struct('seed', 'seed.nii')), h1);
% a file found only on the MATLAB path (an SPM function) is not an input
[~, files] = seecat.util.input_fingerprint(struct(), struct('f', 'spm_vol.m'));
tc.verifyEmpty(files);
end

%% U02: Statistics with mask = 'mask.nii' (relative) redoes the unit when the mask changes
function testRelativeMaskIsFollowed(tc)
root = tc.TestData.root;
d = fullfile(root, 'seecat');
M = [-3 0 0 9; 0 3 0 -9; 0 0 3 -9; 0 0 0 1];
V = struct('dim', [6 6 6], 'mat', M);
rng(3);
for i = 1:12
    f = fullfile(d, sprintf('sub-%02d', i), 'func', sprintf('sub-%02d_task-rest_desc-PCC_stat-z_connectivity.nii', i));
    seecat.io.write_nii(randn(6, 6, 6) + 1, V, f);
end
cd(root);
seecat.io.write_nii(ones(6, 6, 6), V, 'mask.nii');
cfg = seecat.config('stat');
cfg.name = 'm';
cfg.input_dir = d;
cfg.maps = struct('desc', 'PCC', 'stat', 'z');
cfg.mask = 'mask.nii';
cfg.inference = {};
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.status, {'ok'}, S.message{1});
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.status, {'skipped'});
m = zeros(6, 6, 6);
m(1:3, :, :) = 1;
seecat.io.write_nii(m, V, 'mask.nii');                % same path, same size
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.status, {'ok'}, 'a relative mask that changed was not followed');
L = dir(fullfile(d, 'logs', 'stat_*', 'm.log'));
txt = strjoin(arrayfun(@(f) fileread(fullfile(f.folder, f.name)), L, 'UniformOutput', false));
tc.verifySubstring(txt, '108 voxels in the analysis mask');
end

%% U02: the demo pipeline with a relative side file: skipped, then redone after an edit
function testRelativeFileInConfigRedoesUnits(tc)
root = tc.TestData.root;
cfg = seecat.config('demo');
cfg.output_dir = fullfile(root, 'derivatives', 'seecat');
cfg.work_dir = fullfile(root, 'work');
cfg.n_workers = 0;
cd(root);
writeText('side.txt', 'a');
cfg.side_file = 'side.txt';
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.status, {'ok'; 'ok'; 'ok'});
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.status, {'skipped'; 'skipped'; 'skipped'});
writeText('side.txt', 'b');
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.status, {'ok'; 'ok'; 'ok'});
end

%% U04: editing a code file in a running session changes the code fingerprint
function testCodeEditInSessionIsFound(tc)
here = fileparts(mfilename('fullpath'));
copy = fullfile(tc.TestData.root, 'code');
copyfile(fullfile(here, '..', '..', 'SeeCAT', '+seecat'), fullfile(copy, '+seecat'));
addpath(copy);
tc.addTeardown(@() rmpath(copy));
fp = fullfile(copy, '+seecat', '+util', 'code_fingerprint.m');
tc.verifyEqual(which('seecat.util.code_fingerprint'), fp);
h1 = seecat.util.code_fingerprint();
tc.verifyEqual(seecat.util.code_fingerprint(), h1);       % nothing changed: the same
f = fullfile(copy, '+seecat', '+conn', 'seed_fc.m');
txt = fileread(f);
writeText(f, [txt sprintf('\n%% edited\n')]);
tc.verifyNotEqual(seecat.util.code_fingerprint(), h1, 'an edit in this session was not found');
% a window file is not computing code
h2 = seecat.util.code_fingerprint();
g = dir(fullfile(copy, '+seecat', '+gui', '*.m'));
g = fullfile(g(1).folder, g(1).name);
writeText(g, [fileread(g) sprintf('\n%% edited\n')]);
tc.verifyEqual(seecat.util.code_fingerprint(), h2);
end

%% ---- helpers -------------------------------------------------------------

function writeText(f, s)
d = fileparts(f);
if ~isempty(d) && ~exist(d, 'dir')
    mkdir(d);
end
fid = fopen(f, 'w');
fprintf(fid, '%s', s);
fclose(fid);
end

function out = quiet(fn)
[~, out] = evalc('fn()');
end
