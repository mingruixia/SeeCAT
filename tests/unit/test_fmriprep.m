function tests = test_fmriprep
% Tests for the fmriprep pipeline (denoising fMRIPrep outputs), on a small
% synthetic fMRIPrep folder made in setup.
%   results = runtests('tests/unit/test_fmriprep.m')
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
root = tempname;
tc.TestData.root = root;
tc.TestData.fp = fullfile(root, 'derivatives', 'fmriprep');
makeRun(tc.TestData.fp, '01', 'regressors', 'confounds_regressors00');   % older fMRIPrep naming
makeRun(tc.TestData.fp, '02', 'timeseries', 'confounds_timeseries');
end

function teardown(tc)
rmdir(tc.TestData.root, 's');
end

function testDenoisesWithOwnFlagsAndDropsNonSteadyState(tc)
cfg = baseCfg(tc);
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.status, {'ok'; 'ok'});
tc.verifyEqual(S.dummy_scans, [2; 2]);
tc.verifyEqual(S.n_frames, [58; 58]);
tc.verifyEqual(S.n_flagged, [4; 4]);              % FD spike at frame 30 -> 29..32
out = fullfile(tc.TestData.root, 'derivatives', 'seecat', 'sub-01', 'func');   % default: next to fmriprep
stem = 'sub-01_task-rest_space-MNI152NLin2009cAsym_';
for f = {[stem 'desc-denoised_bold.nii.gz'], [stem 'desc-denoisedSm6_bold.nii.gz'], ...
        [stem 'desc-brain_mask.nii.gz'], 'sub-01_task-rest_desc-confounds_timeseries.tsv'}
    tc.verifyTrue(exist(fullfile(out, f{1}), 'file') == 2, f{1});
end
T = seecat.io.read_tsv(fullfile(out, 'sub-01_task-rest_desc-confounds_timeseries.tsv'));
tc.verifyEqual(height(T), 58);
tc.verifyEqual(find(T.censor)', 27:30);            % frames 29..32 of the original run
tc.verifyFalse(any(contains(T.Properties.VariableNames, 'non_steady_state')));
tc.verifyFalse(ismember('motion_outlier00', T.Properties.VariableNames));   % fMRIPrep's flags replaced
Y = seecat.io.read_nii(fullfile(out, [stem 'desc-denoised_bold.nii.gz']));
tc.verifySize(Y, [8 8 8 58]);
j = jsondecode(fileread(fullfile(out, [stem 'desc-denoised_bold.json'])));
tc.verifyEqual(j.NonSteadyStateVolumesDropped, 2);
tc.verifyEqual(j.RepetitionTime, 2);
tc.verifySubstring(j.Sources{1}, 'bids:fmriprep:sub-01/func/');
end

function testDummyScansCanBeSet(tc)
cfg = baseCfg(tc);
cfg.dummy_scans = 5;
cfg.subjects = {'02'};
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.dummy_scans, 5);
tc.verifyEqual(S.n_frames, 55);
end

function testSelectionProblemsAreReported(tc)
cfg = baseCfg(tc);
delete(fullfile(tc.TestData.fp, 'sub-02', 'func', 'sub-02_task-rest_desc-confounds_timeseries.tsv'));
tc.verifyError(@() seecat.fmriprep.plan(cfg), 'SeeCAT:bids');
try
    seecat.fmriprep.plan(cfg);
catch err
    tc.verifySubstring(err.message, 'sub-02_task-rest: no desc-confounds');
end
cfg.space = 'T1w';
tc.verifyError(@() seecat.fmriprep.plan(cfg), 'SeeCAT:bids');
end

function testOldACompCorNeedsExplicitColumns(tc)
cfg = baseCfg(tc);
cfg.subjects = {'01'};
cfg.denoise.regressors = {'friston24', 'acompcor'};
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.status, {'failed'});
tc.verifySubstring(S.message{1}, 'a_comp_cor_*');
cfg.denoise.regressors = {'friston24', 'a_comp_cor_00', 'a_comp_cor_01'};
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.status, {'ok'});
end

%% Helpers -------------------------------------------------------------------

function cfg = baseCfg(tc)
cfg = seecat.config('fmriprep');
cfg.fmriprep_dir = tc.TestData.fp;
end

function makeRun(fp, sub, suffix, style)
% A fMRIPrep-like run: 60 frames, 2 non-steady-state, an FD spike at 30
rng(str2double(sub));
d = fullfile(fp, ['sub-' sub], 'func');
mkdir(d);
stem = fullfile(d, ['sub-' sub '_task-rest']);
nT = 60;
M = [-2 0 0 8; 0 2 0 -8; 0 0 2 -8; 0 0 0 1];
V = struct('dim', [8 8 8], 'mat', M);
Y = 1000 + 10 * randn(8, 8, 8, nT);
Y(:, :, :, 1:2) = Y(:, :, :, 1:2) + 300;          % non-steady-state
mask = false(8, 8, 8);
mask(2:7, 2:7, 2:7) = true;
Y(repmat(~mask, 1, 1, 1, nT)) = 0;
seecat.io.write_nii(Y, V, [stem '_space-MNI152NLin2009cAsym_desc-preproc_bold.nii.gz']);
seecat.io.write_nii(uint8(mask), V, [stem '_space-MNI152NLin2009cAsym_desc-brain_mask.nii.gz'], 'DataType', 'uint8');
seecat.util.write_json([stem '_space-MNI152NLin2009cAsym_desc-preproc_bold.json'], struct('RepetitionTime', 2, 'SkullStripped', false));
T = seecat.denoise.motion_regressors(cumsum(randn(nT, 6) * 0.01));
T.white_matter = randn(nT, 1);
T.csf = randn(nT, 1);
T.global_signal = randn(nT, 1);
fd = abs(randn(nT, 1)) * 0.1;
fd(1) = NaN;
fd(30) = 1.2;
T.framewise_displacement = fd;
T.a_comp_cor_00 = randn(nT, 1);
T.a_comp_cor_01 = randn(nT, 1);
if strcmp(style, 'confounds_regressors00')
    T.non_steady_state_outlier00 = [1; zeros(nT - 1, 1)];
    T.non_steady_state_outlier01 = [0; 1; zeros(nT - 2, 1)];
    T.motion_outlier00 = [zeros(10, 1); 1; zeros(nT - 11, 1)];
else
    T.non_steady_state_outlier_00 = [1; zeros(nT - 1, 1)];
    T.non_steady_state_outlier_01 = [0; 1; zeros(nT - 2, 1)];
    T.motion_outlier_00 = [zeros(10, 1); 1; zeros(nT - 11, 1)];
end
seecat.io.write_tsv(T, [stem '_desc-confounds_' suffix '.tsv']);
end

function out = quiet(fn)
[~, out] = evalc('fn()');
end
