function tests = test_run
% Tests for seecat.run, run_step and derivative naming, using the test-only
% "demo" pipeline in tests/fixtures.
%   results = runtests('tests/unit/test_run.m')
tests = functiontests(localfunctions);
end

function setupOnce(tc)
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
tc.TestData.out = fullfile(tempname, 'derivatives', 'seecat');
end

function teardown(tc)
d = fileparts(fileparts(tc.TestData.out));
if exist(d, 'dir')
    rmdir(d, 's');
end
end

function testRunWritesSummaryLogsAndCleansWork(tc)
cfg = demoCfg(tc);
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.status, {'ok'; 'ok'; 'ok'});
tc.verifyEqual(S.value, [1; 1; 1]);
tc.verifyEqual(S.label, {'Lu1'; 'Lu2'; 'Lu3'});
logs = fullfile(cfg.output_dir, 'logs');
tc.verifyNumElements(dir(fullfile(logs, 'demo_*_config.json')), 1);
tc.verifyNumElements(dir(fullfile(logs, 'demo_*', 'u*.log')), 3);
tc.verifyNumElements(dir(fullfile(logs, 'done', 'demo_u*.json')), 3);
tsv = dir(fullfile(cfg.output_dir, 'reports', 'demo_*_summary.tsv'));
tc.verifyNumElements(tsv, 1);
txt = fileread(fullfile(tsv.folder, tsv.name));
tc.verifySubstring(txt, sprintf('unit\tstatus\tseconds\tmessage\tvalue\tlabel'));
tc.verifySubstring(txt, sprintf('u2\tok\t'));
tc.verifyFalse(exist(fullfile(cfg.work_dir, 'demo', 'u1'), 'dir') == 7);   % keep_work false
tc.verifyEqual(calls(cfg, 'u1'), {'step1'; 'step2'});
end

function testRerunSkipsFinishedUnitsUntilOptionsChange(tc)
cfg = demoCfg(tc);
quiet(@() seecat.run(cfg));
cfg.n_workers = 0;                      % not part of the identity of a run
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.status, {'skipped'; 'skipped'; 'skipped'});
tc.verifyEqual(S.value, [1; 1; 1]);      % results come from the marker
tc.verifyEqual(calls(cfg, 'u1'), {'step1'; 'step2'});
cfg.value = 2;
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.status, {'ok'; 'ok'; 'ok'});
tc.verifyEqual(numel(calls(cfg, 'u1')), 4);
cfg.overwrite = true;
quiet(@() seecat.run(cfg));
tc.verifyEqual(numel(calls(cfg, 'u1')), 6);
end

function testFailureIsolatedAndResumedStepwise(tc)
cfg = demoCfg(tc);
cfg.fail_units = {'u2'};
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.status, {'ok'; 'failed'; 'ok'});
tc.verifySubstring(S.message{2}, 'Unit u2 failed on purpose');
tc.verifyTrue(exist(fullfile(cfg.work_dir, 'demo', 'u2', 'step1.done.mat'), 'file') == 2);
log = dir(fullfile(cfg.output_dir, 'logs', 'demo_*', 'u2.log'));
tc.verifySubstring(fileread(fullfile(log.folder, log.name)), 'run_unit>step2 (line');   % stack kept
% Fix the cause: u2 resumes at step 2. fail_units is part of the options,
% so u1/u3 run again too; but step 1 of u2 is reused from its work folder.
cfg.fail_units = {};
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.status, {'ok'; 'ok'; 'ok'});
tc.verifyEqual(calls(cfg, 'u2'), {'step1'; 'step2'; 'step2'});
end

function testParallelRun(tc)
cfg = demoCfg(tc);
cfg.n_workers = 2;
cfg.fail_units = {'u3'};
S = quiet(@() seecat.run(cfg));
tc.verifyEqual(S.status, {'ok'; 'ok'; 'failed'});
end

function testDerivName(tc)
src = 'D:/bids/sub-01/ses-2/func/sub-01_ses-2_task-rest_acq-mb3_run-1_bold.nii.gz';
r = seecat.bids.deriv_name(src, 'desc', 'preproc', 'space', 'IXI549Space', 'res', '3');
tc.verifyEqual(r, 'sub-01/ses-2/func/sub-01_ses-2_task-rest_acq-mb3_run-1_space-IXI549Space_res-3_desc-preproc_bold.nii.gz');
r = seecat.bids.deriv_name(src, 'desc', 'confounds', 'suffix', 'timeseries', 'ext', '.tsv');
tc.verifyEqual(r, 'sub-01/ses-2/func/sub-01_ses-2_task-rest_acq-mb3_run-1_desc-confounds_timeseries.tsv');
[~, n] = seecat.bids.deriv_name(src, 'stat', 'z', 'desc', 'PCC', 'space', 'IXI549Space', 'suffix', 'connectivity');
tc.verifyEqual(n, 'sub-01_ses-2_task-rest_acq-mb3_run-1_space-IXI549Space_desc-PCC_stat-z_connectivity.nii.gz');
r = seecat.bids.deriv_name('sub-01_T1w.nii', 'datatype', 'anat', 'label', 'GM', 'suffix', 'probseg', 'ext', '.nii.gz');
tc.verifyEqual(r, 'sub-01/anat/sub-01_label-GM_probseg.nii.gz');
r = seecat.bids.deriv_name(src, 'task', '', 'acq', '', 'run', '', 'datatype', 'anat', 'suffix', 'mask');
tc.verifyEqual(r, 'sub-01/ses-2/anat/sub-01_ses-2_mask.nii.gz');
tc.verifyError(@() seecat.bids.deriv_name(src, 'desc', 'pre_proc'), 'SeeCAT:bids');
tc.verifyError(@() seecat.bids.deriv_name('sub-01_T1w.nii'), 'SeeCAT:bids');      % datatype unknown
end

function testPrepPlanResolvesFoldersAndUnits(tc)
root = fileparts(fileparts(tc.TestData.out));
bids = fullfile(root, 'bids');
mkdir(fullfile(bids, 'sub-01', 'func'));
fclose(fopen(fullfile(bids, 'sub-01', 'func', 'sub-01_task-rest_bold.nii.gz'), 'w'));
seecat.util.write_json(fullfile(bids, 'task-rest_bold.json'), struct('RepetitionTime', 2));
cfg = seecat.config('prep');
cfg.bids_dir = bids;
[U, cfg] = seecat.prep.plan(cfg);
tc.verifyEqual({U.id}, {'sub-01_task-rest'});
tc.verifyEqual(cfg.output_dir, fullfile(bids, 'derivatives', 'seecat'));
tc.verifyEqual(cfg.work_dir, fullfile(bids, 'derivatives', 'seecat_work'));
d = jsondecode(fileread(fullfile(cfg.output_dir, 'dataset_description.json')));
tc.verifyEqual(d.DatasetType, 'derivative');
tc.verifyEqual(d.GeneratedBy.Name, 'SeeCAT');
end

%% Helpers -------------------------------------------------------------------

function cfg = demoCfg(tc)
cfg = seecat.config('demo');
cfg.output_dir = tc.TestData.out;
cfg.work_dir = fullfile(fileparts(tc.TestData.out), 'seecat_work');
end

function c = calls(cfg, unit)
c = strsplit(strtrim(fileread(fullfile(cfg.output_dir, 'calls', [unit '.txt']))), newline)';
c = strtrim(c);
end

function out = quiet(fn)
[~, out] = evalc('fn()');
end
