function tests = test_bids
% Unit tests for seecat.bids on a synthetic dataset (empty image files).
%   results = runtests('tests/unit/test_bids.m')
tests = functiontests(localfunctions);
end

function setupOnce(tc)
root = fullfile(fileparts(mfilename('fullpath')), '..', '..');
addpath(fullfile(root, 'SeeCAT'));
d = tempname;
mkdir(d);
tc.TestData.root = d;
makeDataset(d);
tc.TestData.L = seecat.bids.layout(d);
end

function teardownOnce(tc)
rmdir(tc.TestData.root, 's');
end

function testLayoutSkipsNonRawFolders(tc)
L = tc.TestData.L;
tc.verifyEqual(L.subjects, {'01', '02'});            % derivatives/sub-99 ignored
tc.verifyEqual(L.description.Name, 'synthetic');
tc.verifyFalse(any(contains({L.files.path}, 'derivatives')));
tc.verifyFalse(any(strcmp({L.files.name}, 'notes.txt')));
end

function testQuery(tc)
L = tc.TestData.L;
F = seecat.bids.query(L, 'suffix', 'bold', 'ext', '.nii.gz', 'task', 'rest');
tc.verifyEqual(numel(F), 4);
F = seecat.bids.query(L, 'suffix', 'bold', 'sub', '01', 'ses', '2', 'run', '2');
tc.verifyEqual({F.name}, {'sub-01_ses-2_task-rest_run-2_bold.nii.gz'});
F = seecat.bids.query(L, 'suffix', 'bold', 'acq', 'mb3');   % files without acq never match
tc.verifyEqual({F.sub}, {'02'});
tc.verifyEmpty(seecat.bids.query(L, 'suffix', 'bold', 'task', 'motor'));
end

function testMetadataInheritance(tc)
L = tc.TestData.L;
f = seecat.bids.query(L, 'suffix', 'bold', 'sub', '01', 'ses', '1', 'task', 'rest');
m = seecat.bids.metadata(L, f(1));
tc.verifyEqual(m.RepetitionTime, 2);                  % top level
tc.verifyEqual(m.SliceTiming, [0; 1; 0.5; 1.5]);
tc.verifyFalse(isfield(m, 'MultibandAccelerationFactor'));   % acq-mb3 file does not apply
f = seecat.bids.query(L, 'suffix', 'bold', 'sub', '02', 'task', 'rest');
m = seecat.bids.metadata(L, f(1));
tc.verifyEqual(m.RepetitionTime, 0.75);               % subject file overrides
tc.verifyEqual(m.MultibandAccelerationFactor, 3);     % acq-specific top-level file
tc.verifyEqual(m.SliceTiming, [0; 1; 0.5; 1.5]);      % still inherited
end

function testBoldUnits(tc)
L = tc.TestData.L;
cfg = selection('rest');
U = seecat.bids.bold_units(L, cfg);
tc.verifyEqual({U.id}, {'sub-01_ses-1_task-rest', 'sub-01_ses-2_task-rest_run-1', ...
    'sub-01_ses-2_task-rest_run-2', 'sub-02_task-rest_acq-mb3'});
tc.verifyEqual([U.tr], [2 2 2 0.75]);
% ses-2 has no T1w: falls back to the subject's ses-1 T1w
tc.verifySubstring(U(2).t1w, 'sub-01_ses-1_T1w.nii.gz');
tc.verifySubstring(U(4).t1w, 'sub-02_T1w.nii.gz');
cfg.subjects = {'02'};
U = seecat.bids.bold_units(L, cfg);
tc.verifyEqual({U.sub}, {'02'});
end

function testBoldUnitsTaskSelection(tc)
% empty: every task; several labels as a list or comma separated
L = tc.TestData.L;
msg = errorMessage(@() seecat.bids.bold_units(L, selection('')));
tc.verifySubstring(msg, 'sub-01_ses-1_task-nback_bold.nii.gz: RepetitionTime missing');   % nback is taken too
tc.verifyFalse(contains(msg, 'several tasks'));
for t = {'rest, nback', {'rest', 'nback'}}
    msg = errorMessage(@() seecat.bids.bold_units(L, selection(t{1})));
    tc.verifySubstring(msg, 'task-nback_bold.nii.gz: RepetitionTime missing');
end
U = seecat.bids.bold_units(L, selection({'rest'}));
tc.verifyLength(U, 4);
msg = errorMessage(@() seecat.bids.bold_units(L, selection('rest, motor')));
tc.verifySubstring(msg, 'Task "motor" not found. Tasks: nback, rest.');
tc.verifyEqual(seecat.bids.task_list(' rest ,nback,, rest'), {'rest', 'nback'});
tc.verifyEqual(seecat.bids.task_list(''), {});
end

function testSummary(tc)
S = seecat.bids.summary(tc.TestData.L);
tc.verifyEqual(S.subjects, {'01', '02'});
tc.verifyEqual(S.sessions, {'1', '2'});
tc.verifyEqual(S.tasks, {'nback', 'rest'});
tc.verifyEqual(S.runs, [1 4]);
tc.verifyEqual(S.nsub, [1 2]);
tc.verifyEqual(S.text, '2 subjects (01, 02); sessions: 1, 2; tasks: nback (1 run), rest (4 runs)');
S = seecat.bids.summary(tc.TestData.root, 'fmriprep');                 % no desc-preproc runs here
tc.verifySubstring(S.text, 'no desc-preproc BOLD runs found');
end

function testBoldUnitsErrors(tc)
L = tc.TestData.L;
cfg = selection('nback');
cfg.subjects = {'01', '07'};
msg = errorMessage(@() seecat.bids.bold_units(L, cfg));
tc.verifySubstring(msg, 'Subjects not in the dataset: 07');
cfg.subjects = {'01'};
msg = errorMessage(@() seecat.bids.bold_units(L, cfg));
tc.verifySubstring(msg, 'RepetitionTime missing');      % nback has no TR anywhere
end

%% Helpers -------------------------------------------------------------------

function cfg = selection(task)
cfg = struct('subjects', {{}}, 'sessions', {{}}, 'task', {task}, 'runs', {{}});
end

function makeDataset(d)
writeJson(fullfile(d, 'dataset_description.json'), struct('Name', 'synthetic', 'BIDSVersion', '1.9.0'));
writeJson(fullfile(d, 'task-rest_bold.json'), struct('RepetitionTime', 2, 'SliceTiming', [0 1 0.5 1.5]));
writeJson(fullfile(d, 'task-rest_acq-mb3_bold.json'), struct('MultibandAccelerationFactor', 3));
touch(fullfile(d, 'sub-01', 'ses-1', 'anat', 'sub-01_ses-1_T1w.nii.gz'));
touch(fullfile(d, 'sub-01', 'ses-1', 'func', 'sub-01_ses-1_task-rest_bold.nii.gz'));
touch(fullfile(d, 'sub-01', 'ses-1', 'func', 'sub-01_ses-1_task-nback_bold.nii.gz'));
touch(fullfile(d, 'sub-01', 'ses-1', 'func', 'notes.txt'));
touch(fullfile(d, 'sub-01', 'ses-2', 'func', 'sub-01_ses-2_task-rest_run-1_bold.nii.gz'));
touch(fullfile(d, 'sub-01', 'ses-2', 'func', 'sub-01_ses-2_task-rest_run-2_bold.nii.gz'));
touch(fullfile(d, 'sub-02', 'anat', 'sub-02_T1w.nii.gz'));
touch(fullfile(d, 'sub-02', 'func', 'sub-02_task-rest_acq-mb3_bold.nii.gz'));
writeJson(fullfile(d, 'sub-02', 'func', 'sub-02_task-rest_acq-mb3_bold.json'), struct('RepetitionTime', 0.75));
touch(fullfile(d, 'derivatives', 'fmriprep', 'sub-99', 'func', 'sub-99_task-rest_bold.nii.gz'));
end

function touch(f)
if ~exist(fileparts(f), 'dir')
    mkdir(fileparts(f));
end
fclose(fopen(f, 'w'));
end

function writeJson(f, s)
fid = fopen(f, 'w');
fprintf(fid, '%s', jsonencode(s));
fclose(fid);
end

function msg = errorMessage(fn)
msg = '';
try
    fn();
catch err
    msg = err.message;
end
end
