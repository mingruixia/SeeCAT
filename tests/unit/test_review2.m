function tests = test_review2
% Regression tests for the findings of the 2026-11-06 review (R01-R04 and
% the concurrency note): inputs are never written over or deleted, files
% named in the config are followed, unit ids stay apart, an empty analysis
% mask is reported, a unit is locked while it runs.
%   results = runtests('tests/unit/test_review2.m')
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

%% R01: the output folder may not be the fMRIPrep folder, however it is written
function testOutputFolderMayNotBeTheInputFolder(tc)
fp = fullfile(tc.TestData.root, 'derivatives', 'fmriprep');
makeFmriprepRun(fp, '01');
before = treeHashes(fp);
cfg = seecat.config('fmriprep');
cfg.fmriprep_dir = fp;
cd(fullfile(tc.TestData.root, 'derivatives'));
for out = {fp, [fp filesep], 'fmriprep', fullfile('.', 'fmriprep', '..', 'fmriprep')}
    cfg.output_dir = out{1};
    tc.verifyError(@() quiet(@() seecat.run(cfg)), 'SeeCAT:config', out{1});
end
tc.verifyEqual(treeHashes(fp), before);
end

%% R01: a unit that would write over one of its inputs stops and leaves it
function testUnitNeverWritesOverOrDeletesItsInput(tc)
root = tc.TestData.root;
cfg = demoCfg(root);
in = fullfile(cfg.output_dir, 'deriv', 'in.txt');
writeText(in, 'input');
cfg.input_file = in;
cfg.output_name = fullfile('deriv', 'in.txt');
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.status, {'failed'; 'failed'; 'failed'});
tc.verifySubstring(S.message{1}, 'input files');
tc.verifyEqual(fileread(in), 'input');
% a manifest that lists the input (from an older run) does not get it deleted
cfg.output_name = '';
writeText(fullfile(cfg.output_dir, 'logs', 'outputs', 'demo_u1.txt'), sprintf('deriv/in.txt\n'));
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.status, {'ok'; 'ok'; 'ok'});
tc.verifyEqual(fileread(in), 'input');
end

%% R02: a file named only in the config is an input; contents count, not the date
function testFilesNamedInTheConfigAreFollowed(tc)
cfg = demoCfg(tc.TestData.root);
side = fullfile(tc.TestData.root, 'seed.txt');
writeText(side, 'a');
cfg.side_file = side;
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.status, {'ok'; 'ok'; 'ok'});
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.status, {'skipped'; 'skipped'; 'skipped'});
t = java.io.File(side).lastModified();
writeText(side, 'b');                                % same size ...
java.io.File(side).setLastModified(t);               % ... and same date
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.status, {'ok'; 'ok'; 'ok'});
tc.verifySubstring(unitLogs(cfg, 'u1'), 'the inputs changed');
end

%% R02: results of other SeeCAT code are not reused
function testCodeChangeRedoesUnits(tc)
cfg = demoCfg(tc.TestData.root);
quiet(@() seecat.run(cfg));
marker = fullfile(cfg.output_dir, 'logs', 'done', 'demo_u2.json');
m = jsondecode(fileread(marker));
tc.verifyEqual(m.code_hash, seecat.util.code_fingerprint());
m.code_hash = 'older';
seecat.util.write_json(marker, m);
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.status, {'skipped'; 'ok'; 'skipped'});
tc.verifySubstring(unitLogs(cfg, 'u2'), 'code changed');
end

%% R02, R04: Statistics follows its mask file and reports an empty mask
function testStatMaskEditedAndEmptyMask(tc)
d = fullfile(tc.TestData.root, 'seecat');
M = [-3 0 0 9; 0 3 0 -9; 0 0 3 -9; 0 0 0 1];
V = struct('dim', [6 6 6], 'mat', M);
rng(2);
for i = 1:12
    f = fullfile(d, sprintf('sub-%02d', i), 'func', sprintf('sub-%02d_task-rest_desc-PCC_stat-z_connectivity.nii', i));
    seecat.io.write_nii(randn(6, 6, 6) + 1, V, f);
end
mask = fullfile(tc.TestData.root, 'mask.nii');
seecat.io.write_nii(ones(6, 6, 6), V, mask);
cfg = seecat.config('stat');
cfg.name = 'm';
cfg.input_dir = d;
cfg.maps = struct('desc', 'PCC', 'stat', 'z');
cfg.mask = mask;
cfg.inference = {};
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.status, {'ok'}, S.message{1});
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.status, {'skipped'});
m = zeros(6, 6, 6);
m(1:3, :, :) = 1;
seecat.io.write_nii(m, V, mask);                     % same path, same size
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.status, {'ok'});
L = dir(fullfile(d, 'logs', 'stat_*', 'm.log'));
txt = strjoin(arrayfun(@(f) fileread(fullfile(f.folder, f.name)), L, 'UniformOutput', false));
tc.verifySubstring(txt, '108 voxels in the analysis mask');
seecat.io.write_nii(zeros(6, 6, 6), V, mask);
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.status, {'failed'});
tc.verifySubstring(S.message{1}, 'analysis mask is empty');
end

%% R03: long selections with one beginning are two units; neither deletes the other
function testHarmonizeUnitsOfLongSelectionsStayApart(tc)
in = fullfile(tc.TestData.root, 'seecat');
M = [-3 0 0 9; 0 3 0 -9; 0 0 3 -9; 0 0 0 1];
V = struct('dim', [6 6 6], 'mat', M);
long = repmat('LongFeature', 1, 4);
rng(5);
n = 8;
for i = 1:n
    d = fullfile(in, sprintf('sub-%02d', i), 'func');
    for t = {'A', 'B'}
        seecat.io.write_nii(randn(6, 6, 6) + 5 + mod(i, 2), V, fullfile(d, ...
            sprintf('sub-%02d_task-rest_desc-%s%s_stat-z_connectivity.nii.gz', i, long, t{1})));
    end
end
P = table(arrayfun(@(i) sprintf('sub-%02d', i), (1:n)', 'UniformOutput', false), ...
    repmat({'S1'; 'S2'}, n / 2, 1), 'VariableNames', {'participant_id', 'site'});
seecat.io.write_tsv(P, fullfile(in, 'participants.tsv'));
cfg = seecat.config('harmonize');
cfg.input_dir = in;
cfg.mask = 'brain';
cfg.maps = struct('desc', [long 'A'], 'stat', 'z');
uA = seecat.harmonize.plan(seecat.config(cfg));
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.status, {'ok'}, S.message{1});
cfg.maps = struct('stat', 'z', 'desc', [long 'B']);
uB = seecat.harmonize.plan(seecat.config(cfg));
tc.verifyNotEqual(uA.id, uB.id);
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.status, {'ok'}, S.message{1});
count = @(t) numel(dir(fullfile(in, 'sub-*', 'func', ['*desc-' long t 'ComBat_*.nii.gz'])));
tc.verifyEqual(count('A'), n);
tc.verifyEqual(count('B'), n);
% the order of the selector's fields does not change the unit
cfg.maps = struct('desc', [long 'B'], 'stat', 'z');
uB2 = seecat.harmonize.plan(seecat.config(cfg));
tc.verifyEqual(uB2.id, uB.id);
end

%% Concurrency: a unit held by another live process is left alone; a stale lock is taken over
function testLockedUnitIsLeftAlone(tc)
cfg = demoCfg(tc.TestData.root);
lock = fullfile(cfg.output_dir, 'logs', 'locks', 'demo_u2');
mkdir(lock);
host = char(java.net.InetAddress.getLocalHost().getHostName());
owner = struct('run', 'demo_other', 'host', host, 'pid', feature('getpid'), 'started', 'now');
seecat.util.write_json(fullfile(lock, 'owner.json'), owner);
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.status, {'ok'; 'failed'; 'ok'});
tc.verifySubstring(S.message{2}, 'demo_other');
tc.verifyTrue(exist(lock, 'dir') == 7);              % not ours to remove
owner.pid = deadPid();
seecat.util.write_json(fullfile(lock, 'owner.json'), owner);
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.status{2}, 'ok');
tc.verifyFalse(exist(lock, 'dir') == 7);
tc.verifyEmpty(dir(fullfile(cfg.output_dir, 'logs', 'locks', 'demo_*')));
end

%% helpers
function cfg = demoCfg(root)
cfg = seecat.config('demo');
cfg.output_dir = fullfile(root, 'derivatives', 'seecat');
cfg.work_dir = fullfile(root, 'work');
cfg.n_workers = 0;
end

function p = deadPid()
p = 4000000;                                         % above any pid Windows or Linux hands out
while true
    try
        if ~java.lang.ProcessHandle.of(p).isPresent()
            return
        end
    catch
        return
    end
    p = p + 1;
end
end

function makeFmriprepRun(fp, sub)
d = fullfile(fp, ['sub-' sub], 'func');
mkdir(d);
stem = fullfile(d, ['sub-' sub '_task-rest']);
nT = 20;
V = struct('dim', [6 6 6], 'mat', [-2 0 0 6; 0 2 0 -6; 0 0 2 -6; 0 0 0 1]);
seecat.io.write_nii(1000 + randn(6, 6, 6, nT), V, [stem '_space-MNI152NLin2009cAsym_desc-preproc_bold.nii.gz']);
seecat.io.write_nii(uint8(ones(6, 6, 6)), V, [stem '_space-MNI152NLin2009cAsym_desc-brain_mask.nii.gz'], 'DataType', 'uint8');
seecat.util.write_json([stem '_space-MNI152NLin2009cAsym_desc-preproc_bold.json'], struct('RepetitionTime', 2));
T = seecat.denoise.motion_regressors(cumsum(randn(nT, 6) * 0.01));
T.framewise_displacement = [NaN; abs(randn(nT - 1, 1)) * 0.1];
seecat.io.write_tsv(T, [stem '_desc-confounds_timeseries.tsv']);
end

function H = treeHashes(d)
F = dir(fullfile(d, '**', '*'));
F = F(~[F.isdir]);
H = sort(arrayfun(@(f) [strrep(fullfile(f.folder, f.name), d, '') '|' ...
    seecat.util.file_md5(fullfile(f.folder, f.name))], F, 'UniformOutput', false));
end

function txt = unitLogs(cfg, unit)
L = dir(fullfile(cfg.output_dir, 'logs', 'demo_*', [unit '.log']));
txt = strjoin(arrayfun(@(f) fileread(fullfile(f.folder, f.name)), L, 'UniformOutput', false));
end

function writeText(f, s)
d = fileparts(f);
if ~exist(d, 'dir')
    mkdir(d);
end
fid = fopen(f, 'w');
fprintf(fid, '%s', s);
fclose(fid);
end

function out = quiet(fn)
[~, out] = evalc('fn()');
end
