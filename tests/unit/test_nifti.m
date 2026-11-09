function tests = test_nifti
% Tests for seecat.bids.from_nifti / scan_nifti / organize / plan_rules on
% synthetic NIfTI folders: a scanner-platform export with dcm2niix sidecars
% (field maps, single-band references, ND copies, localizers), modality
% folders without sidecars, numbered 3D volumes, session folders, subject
% IDs in file names, and plans edited by hand.
%   results = runtests('tests/unit/test_nifti.m')
tests = functiontests(localfunctions);
end

function setupOnce(tc)
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..', '..', 'SeeCAT'));
addpath(fullfile(here, '..', 'data'));
spmDir = getenv('SEECAT_SPM');
if isempty(spmDir)
    spmDir = 'D:/verysync/dropbox/SciTools/MatlabToolbox/spm';
end
addpath(spmDir);
tc.assumeTrue(exist('spm_vol', 'file') == 2, 'SPM not on the path');
end

function setup(tc)
tc.TestData.root = tempname;
mkdir(tc.TestData.root);
tc.TestData.src = fullfile(tc.TestData.root, 'export');
tc.TestData.bids = fullfile(tc.TestData.root, 'bids');
end

function teardown(tc)
if exist(tc.TestData.root, 'dir')
    rmdir(tc.TestData.root, 's');
end
end

%% ---- tests ---------------------------------------------------------------

function testPlatformExport(tc)
src = make_nifti_demo(tc.TestData.src, 'sub173_testname');
before = treeHash(src);
T = quiet(@() seecat.bids.from_nifti(src, tc.TestData.bids));
tc.verifyEqual(treeHash(src), before, 'the source folder changed');
named = sort(T.bids(~cellfun(@isempty, T.bids)));
want = sort({ ...
    'sub-173/anat/sub-173_T1w.nii.gz'
    'sub-173/fmap/sub-173_run-1_magnitude1.nii.gz'
    'sub-173/fmap/sub-173_run-1_magnitude2.nii.gz'
    'sub-173/fmap/sub-173_run-1_phasediff.nii.gz'
    'sub-173/fmap/sub-173_run-2_magnitude1.nii.gz'
    'sub-173/fmap/sub-173_run-2_magnitude2.nii.gz'
    'sub-173/fmap/sub-173_run-2_phasediff.nii.gz'
    'sub-173/func/sub-173_task-rest_sbref.nii.gz'
    'sub-173/func/sub-173_task-rest_bold.nii.gz'
    'sub-173/func/sub-173_task-mathaitrust_run-1_bold.nii.gz'
    'sub-173/func/sub-173_task-mathaitrust_run-2_bold.nii.gz'
    'sub-173/func/sub-173_task-alchemy_sbref.nii.gz'
    'sub-173/func/sub-173_task-alchemy_bold.nii.gz'
    'sub-173/func/sub-173_task-igt_run-1_bold.nii.gz'
    'sub-173/func/sub-173_task-igt_run-2_bold.nii.gz'});
tc.verifyEqual(named, want);
note = @(d) T.note(strcmp(T.description, d));
tc.verifyTrue(all(contains(note('localizer1'), 'localizer')));
tc.verifySubstring(char(note('CCBD_T1ISO_MPR_ND')), 'without distortion correction');
B = tc.TestData.bids;
j = readJson(B, 'sub-173/fmap/sub-173_run-1_phasediff.json');
tc.verifyEqual([j.EchoTime1 j.EchoTime2], [0.00492 0.00738], 'AbsTol', 1e-9);
tc.verifyEqual(sort(j.IntendedFor), sort({'bids::sub-173/func/sub-173_task-rest_sbref.nii.gz'; ...
    'bids::sub-173/func/sub-173_task-rest_bold.nii.gz'; ...
    'bids::sub-173/func/sub-173_task-mathaitrust_run-1_bold.nii.gz'; ...
    'bids::sub-173/func/sub-173_task-mathaitrust_run-2_bold.nii.gz'}));
j = readJson(B, 'sub-173/fmap/sub-173_run-2_magnitude1.json');
tc.verifyTrue(all(contains(j.IntendedFor, {'alchemy', 'igt'})));
tc.verifyFalse(any(contains(j.IntendedFor, 'mathaitrust')));
j = readJson(B, 'sub-173/func/sub-173_task-igt_run-2_bold.json');
tc.verifyEqual(j.TaskName, 'igt');
tc.verifyFalse(any(isfield(j, {'PatientName', 'PatientID', 'PatientBirthDate', 'PatientSex'})));
tc.verifyTrue(isfield(j, 'SliceTiming'));
P = seecat.io.read_tsv(fullfile(B, 'participants.tsv'));
tc.verifyEqual(P.participant_id, {'sub-173'});
tc.verifyEqual(P.sex, {'M'});
tc.verifyEqual(P.age, 18);
rep = fileread(fullfile(B, 'code', 'seecat', 'from_nifti_sub-173.tsv'));
tc.verifyFalse(contains(rep, 'testname'), 'the folder name with the person''s name is in the dataset');
tc.verifySubstring(rep, 'sub-173/2026-10-13T11_09_18/functional/');
L = seecat.bids.layout(B);
tc.verifyEqual(L.subjects, {'173'});
% importing again keeps everything
T2 = quiet(@() seecat.bids.from_nifti(src, tc.TestData.bids));
tc.verifyTrue(all(contains(T2.note(~cellfun(@isempty, T2.bids)), 'already in the dataset')));
end

function testHardLinks(tc)
src = make_nifti_demo(tc.TestData.src, 'S01');
T = quiet(@() seecat.bids.from_nifti(src, tc.TestData.bids, 'link', true));
f = fullfile(tc.TestData.bids, T.bids{find(~cellfun(@isempty, T.bids), 1)});
tc.verifyTrue(exist(f, 'file') == 2);
tc.verifyNotEmpty(seecat.io.nii_info(f).dim);
end

function testModalityFoldersWithoutSidecars(tc)
src = tc.TestData.src;
for s = {'S001', 'S002'}
    img4d(fullfile(src, 'FunRaw', s{1}, 'rest.nii'), [6 6 4], 25);
    img3d(fullfile(src, 'T1Raw', s{1}, [s{1} '_mprage.nii']), [100 100 100], 1);
end
[S, ~, info] = seecat.bids.scan_nifti(src);
tc.verifyEqual(S.subject, {'S001'; 'S002'});
tc.verifySubstring(info.layout, 'level 2');
T = quiet(@() seecat.bids.from_nifti(src, tc.TestData.bids, 'tr', 2));
tc.verifyEqual(sort(T.bids(~cellfun(@isempty, T.bids))), sort({ ...
    'sub-S001/anat/sub-S001_T1w.nii.gz'; 'sub-S001/func/sub-S001_task-rest_bold.nii.gz'; ...
    'sub-S002/anat/sub-S002_T1w.nii.gz'; 'sub-S002/func/sub-S002_task-rest_bold.nii.gz'}));
j = readJson(tc.TestData.bids, 'sub-S001/func/sub-S001_task-rest_bold.json');
tc.verifyEqual(j.RepetitionTime, 2);
tc.verifyEqual(j.TaskName, 'rest');
h = seecat.io.nii_info(fullfile(tc.TestData.bids, 'sub-S001/func/sub-S001_task-rest_bold.nii.gz'));
tc.verifyEqual(h.dim, [6 6 4 25]);
end

function testNumbered3DVolumesAreOneRun(tc)
src = fullfile(tc.TestData.src, 'subj07', 'rest');
for k = 1:22
    img3d(fullfile(src, sprintf('f%04d.nii', k)), [6 6 4], k);
end
img3d(fullfile(tc.TestData.src, 'subj07', 'Analyze', 'anat.img'), [6 6 4], 1);
T = quiet(@() seecat.bids.from_nifti(tc.TestData.src, tc.TestData.bids, 'tr', 2.5));
row = T(contains(T.bids, '_bold'), :);
tc.verifyEqual(row.bids, {'sub-07/func/sub-07_task-rest_bold.nii.gz'});
tc.verifySubstring(row.source{1}, '22 volumes');
Y = seecat.io.read_nii(fullfile(tc.TestData.bids, row.bids{1}));
tc.verifyEqual(size(Y, 4), 22);
tc.verifyEqual(squeeze(Y(1, 1, 1, [1 22]))', [1 22]);      % volumes in number order
tc.verifyEqual(seecat.io.nii_info(fullfile(tc.TestData.bids, row.bids{1})).tr, 2.5, 'AbsTol', 1e-6);
end

function testNumberedVolumesKeepSubjectsAndRuns(tc)
% 2 subjects x 2 runs x 20 volumes in one folder: 4 runs, frames in order
src = tc.TestData.src;
for s = 1:2
    for r = 1:2
        for k = 1:20
            img3d(fullfile(src, sprintf('S%02d_rest_run%d_%04d.nii', s, r, k)), [6 6 4], s * 1000 + r * 100 + k);
        end
    end
end
[S, G] = seecat.bids.scan_nifti(src);
tc.verifyEqual(S.subject, {'S01'; 'S02'});
tc.verifyEqual(cellfun(@numel, G), [2; 2]);
tc.verifyEqual(arrayfun(@(g) g.dim(4), [G{:}]), [20 20 20 20]);
T = quiet(@() seecat.bids.from_nifti(src, tc.TestData.bids, 'tr', 2));
tc.verifyEqual(sort(T.bids), sort({'sub-S01/func/sub-S01_task-rest_run-1_bold.nii.gz'; ...
    'sub-S01/func/sub-S01_task-rest_run-2_bold.nii.gz'; 'sub-S02/func/sub-S02_task-rest_run-1_bold.nii.gz'; ...
    'sub-S02/func/sub-S02_task-rest_run-2_bold.nii.gz'}));
for s = 1:2
    for r = 1:2
        Y = seecat.io.read_nii(fullfile(tc.TestData.bids, sprintf('sub-S%02d/func/sub-S%02d_task-rest_run-%d_bold.nii.gz', s, s, r)));
        tc.verifyEqual(squeeze(Y(1, 1, 1, :))', s * 1000 + r * 100 + (1:20), sprintf('S%02d run %d', s, r));
    end
end
% two runs in one subject's folder (run1_vol0001 ..., run2_vol0001 ...)
rmdir(src, 's');
for r = 1:2
    for k = 1:20
        img3d(fullfile(src, 'S01', 'rest', sprintf('run%d_vol%04d.nii', r, k)), [6 6 4], r * 100 + k);
    end
end
T = quiet(@() seecat.bids.from_nifti(src, fullfile(tc.TestData.root, 'bids2'), 'tr', 2));
tc.verifyEqual(sort(T.bids), {'sub-S01/func/sub-S01_task-rest_run-1_bold.nii.gz'; ...
    'sub-S01/func/sub-S01_task-rest_run-2_bold.nii.gz'});
Y = seecat.io.read_nii(fullfile(tc.TestData.root, 'bids2', 'sub-S01/func/sub-S01_task-rest_run-2_bold.nii.gz'));
tc.verifyEqual(squeeze(Y(1, 1, 1, :))', 200 + (1:20));
end

function testNumberedVolumesThatDifferAreNotMerged(tc)
% same size, another orientation; and a gap in the numbers
src = fullfile(tc.TestData.src, 'S01', 'rest');
for k = 1:12
    M = diag([3 3 3 1]);
    if k == 7
        M(1, 4) = 10;                              % shifted
    end
    img(fullfile(src, sprintf('f%04d.nii', k)), [6 6 4], 1, k, M);
end
tc.verifyWarning(@() seecat.bids.scan_nifti(tc.TestData.src), 'SeeCAT:bids');
[~, G] = quiet(@() seecat.bids.scan_nifti(tc.TestData.src));
tc.verifyEqual(numel(G{1}), 12, 'volumes of different orientation were merged');
rmdir(tc.TestData.src, 's');
for k = [1:5 7:12]
    img3d(fullfile(src, sprintf('f%04d.nii', k)), [6 6 4], k);
end
lastwarn('');
[~, G] = quiet(@() seecat.bids.scan_nifti(tc.TestData.src));
tc.verifyEqual(numel(G{1}), 11, 'numbers with a gap were merged');
tc.verifySubstring(lastwarn, '1 missing');
end

function testNamesAreTakenOutOfTheDataset(tc)
src = tc.TestData.src;
img4d(fullfile(src, 'sub173_zhangsan_rest.nii'), [6 6 4], 20);
img4d(fullfile(src, 'sub174_lisi_rest.nii'), [6 6 4], 20);
src2 = fullfile(tc.TestData.root, 'export2');
f = fullfile(src2, 'S175_wangwu', 'wangwu_rest.nii.gz');
img4d(f, [6 6 4], 20);
img4d(fullfile(src2, 'S176_zhaoliu', 'rest.nii'), [6 6 4], 20);
sidecar(f, struct('SeriesNumber', 3, 'SeriesDescription', 'WangWu rest', 'ProtocolName', 'rest_wang_wu', ...
    'PatientName', 'Wang^Wu', 'ScanningSequence', 'EP', 'MRAcquisitionType', '2D', ...
    'ImageType', {{'ORIGINAL'; 'PRIMARY'}}, 'RepetitionTime', 2, 'Notes', struct('by', 'scan of wangwu')));
T = [quiet(@() seecat.bids.from_nifti(src, tc.TestData.bids, 'tr', 2)); ...
    quiet(@() seecat.bids.from_nifti(src2, tc.TestData.bids, 'tr', 2))];
tc.verifyEqual(sort(T.bids), sort({'sub-173/func/sub-173_task-rest_bold.nii.gz'; ...
    'sub-174/func/sub-174_task-rest_bold.nii.gz'; 'sub-S175/func/sub-S175_task-rest_bold.nii.gz'; ...
    'sub-S176/func/sub-S176_task-rest_bold.nii.gz'}));
F = dir(fullfile(tc.TestData.bids, '**', '*'));
F = F(~[F.isdir] & ~endsWith({F.name}, '.nii.gz'));
for k = 1:numel(F)
    txt = lower(fileread(fullfile(F(k).folder, F(k).name)));
    for w = {'zhangsan', 'lisi', 'wangwu', 'wang', 'wu', 'zhaoliu'}
        tc.verifyEmpty(regexp(txt, ['(?<![a-z])' w{1} '(?![a-z])'], 'once'), sprintf('%s in %s', w{1}, F(k).name));
    end
end
j = readJson(tc.TestData.bids, 'sub-S175/func/sub-S175_task-rest_bold.json');
tc.verifyEqual(j.SeriesDescription, 'rest');
tc.verifyEqual(j.ProtocolName, 'rest');
r = fileread(fullfile(tc.TestData.bids, 'code', 'seecat', 'from_nifti_sub-173.tsv'));
tc.verifySubstring(r, 'sub-173_rest.nii');
% scan words are not names; a task only one subject has stays when it is the last word
rmdir(src, 's');
img4d(fullfile(src, 'S01_zhangsan_rest.nii'), [6 6 4], 20);
img4d(fullfile(src, 'S02_nback.nii'), [6 6 4], 20);
[~, G] = seecat.bids.scan_nifti(src);
tc.verifyEqual({G{1}.public, G{2}.public}, {'sub-S01_rest.nii', 'sub-S02_nback.nii'});
tc.verifyEqual({G{1}.desc, G{2}.desc}, {'rest', 'nback'});
end

function testTaskWordsThatMayBeNames(tc)
% S01_memory_bold next to S02_motor_bold: the words may be names, so they
% stay out of the dataset, but the task is "unknown" with a note, not rest
% (2026-11-09 review, C03); a task shared by the subjects is kept
src = tc.TestData.src;
img4d(fullfile(src, 'S01_memory_bold.nii'), [6 6 4], 20);
img4d(fullfile(src, 'S02_motor_bold.nii'), [6 6 4], 20);
T = quiet(@() seecat.bids.from_nifti(src, tc.TestData.bids, 'tr', 2, 'dryrun', true));
tc.verifyEqual(sort(T.bids), {'sub-S01/func/sub-S01_task-unknown_bold.nii.gz'; ...
    'sub-S02/func/sub-S02_task-unknown_bold.nii.gz'});
tc.verifyTrue(all(contains(T.note, 'task not known')));
rmdir(src, 's');
img4d(fullfile(src, 'S01_zhangsan_rest.nii'), [6 6 4], 20);    % a name and a task word: rest
img4d(fullfile(src, 'S02_lisi_rest.nii'), [6 6 4], 20);
img4d(fullfile(src, 'S01_memory_bold.nii'), [6 6 4], 20);       % shared by both: a task
img4d(fullfile(src, 'S02_memory_bold.nii'), [6 6 4], 20);
T = quiet(@() seecat.bids.from_nifti(src, tc.TestData.bids, 'tr', 2, 'dryrun', true));
tc.verifyEqual(sort(T.bids), sort({'sub-S01/func/sub-S01_task-rest_bold.nii.gz'; ...
    'sub-S02/func/sub-S02_task-rest_bold.nii.gz'; 'sub-S01/func/sub-S01_task-memory_bold.nii.gz'; ...
    'sub-S02/func/sub-S02_task-memory_bold.nii.gz'}));
tc.verifyFalse(any(contains(T.note, 'task not known')));
tc.verifyFalse(any(contains(T.description, {'zhangsan', 'lisi'})));
end

function testSessionFoldersAndBidsLikeTree(tc)
src = tc.TestData.src;
for v = {'pre', 'post'}
    img4d(fullfile(src, 'patient12', v{1}, 'rest.nii.gz'), [6 6 4], 20);
end
T = quiet(@() seecat.bids.from_nifti(src, tc.TestData.bids, 'tr', 2));
tc.verifyEqual(sort(T.bids), sort({'sub-patient12/ses-post/func/sub-patient12_ses-post_task-rest_bold.nii.gz'; ...
    'sub-patient12/ses-pre/func/sub-patient12_ses-pre_task-rest_bold.nii.gz'}));
rmdir(src, 's');
img4d(fullfile(src, 'sub-01', 'ses-1', 'func', 'sub-01_ses-1_task-rest_bold.nii.gz'), [6 6 4], 20);
[S, G] = seecat.bids.scan_nifti(src);
tc.verifyEqual(S.subject, {'01'});
tc.verifyEqual(G{1}(1).ses, '1');
end

function testSubjectsFromFileNames(tc)
src = tc.TestData.src;
for s = {'S01', 'S02', 'S03'}
    img4d(fullfile(src, [s{1} '_rest.nii']), [6 6 4], 20);
end
S = seecat.bids.scan_nifti(src);
tc.verifyEqual(S.subject, {'S01'; 'S02'; 'S03'});
S = seecat.bids.scan_nifti(src, 'subject_pattern', 'S0(\d)_');
tc.verifyEqual(S.subject, {'1'; '2'; '3'});
end

function testLabelsDropNames(tc)
src = tc.TestData.src;
img4d(fullfile(src, 'sub173_zhangsan', 'rest.nii'), [6 6 4], 20);
img4d(fullfile(src, 'S_002', 'rest.nii'), [6 6 4], 20);
img4d(fullfile(src, '003_lisi', 'rest.nii'), [6 6 4], 20);
S = seecat.bids.scan_nifti(src);
tc.verifyEqual(sort(S.subject), sort({'173'; 'S002'; '003'}));
end

function testEditedPlanAndRules(tc)
src = make_nifti_demo(fullfile(tc.TestData.src, 'one'), 'sub01_test');
P = seecat.bids.from_nifti(src, tc.TestData.bids, 'dryrun', true);
tc.verifyFalse(exist(tc.TestData.bids, 'dir') == 7, 'a dry run wrote files');
k = strcmp(P.description, 'IGT1');
P.bids{k} = 'sub-01/func/sub-01_task-gambling_run-1_bold.nii.gz';
k = strcmp(P.description, 'IGT2');
P.bids{k} = 'sub-01/func/sub-01_task-gambling_run-2_bold.nii.gz';
P.bids{strcmp(P.description, 'Alchemy')} = '';
T = quiet(@() seecat.bids.from_nifti(src, tc.TestData.bids, 'names', P));
tc.verifyTrue(any(strcmp(T.bids, 'sub-01/func/sub-01_task-gambling_run-2_bold.nii.gz')));
tc.verifyFalse(any(contains(T.bids, 'alchemy')));
tc.verifyEqual(readJson(tc.TestData.bids, 'sub-01/func/sub-01_task-gambling_run-1_bold.json').TaskName, 'gambling');
% a renamed run takes its sbref along; a run left out takes it out
P2 = seecat.bids.from_nifti(src, fullfile(tc.TestData.root, 'b3'), 'dryrun', true);
P2.bids{strcmp(P2.description, 'CCBD_BOLD_PA_REST1')} = 'sub-01/func/sub-01_task-resting_bold.nii.gz';
P2 = seecat.bids.from_nifti(src, fullfile(tc.TestData.root, 'b3'), 'dryrun', true, 'names', P2);
tc.verifyTrue(any(strcmp(P2.bids, 'sub-01/func/sub-01_task-resting_sbref.nii.gz')));
tc.verifyFalse(any(contains(T.bids, 'alchemy_sbref')));
P = T;
P.bids{strcmp(P.description, 'Alchemy')} = '';
P.note{strcmp(P.description, 'Alchemy')} = 'left out in the plan';
rules = seecat.bids.plan_rules(P, fullfile(tc.TestData.root, 'rules.json'));
tc.verifyTrue(any([rules.skip]));
% the next subject, named by the saved rules
src2 = make_nifti_demo(fullfile(tc.TestData.src, 'two'), 'sub02_test');
T2 = quiet(@() seecat.bids.from_nifti(src2, tc.TestData.bids, 'rules', fullfile(tc.TestData.root, 'rules.json')));
tc.verifyTrue(any(strcmp(T2.bids, 'sub-02/func/sub-02_task-gambling_run-2_bold.nii.gz')));
tc.verifyFalse(any(contains(T2.bids, 'alchemy')));
tc.verifyTrue(any(contains(T2.bids, 'phasediff')));          % field maps still recognised
bad = P;
bad.bids{strcmp(bad.description, 'IGT1')} = 'func/rest.nii.gz';
tc.verifyError(@() seecat.bids.from_nifti(src, fullfile(tc.TestData.root, 'b2'), 'names', bad, 'dryrun', true), ...
    'SeeCAT:bids');
end

function testOutputInsideSourceIsRefused(tc)
src = make_nifti_demo(tc.TestData.src, 'S01');
tc.verifyError(@() seecat.bids.from_nifti(src, fullfile(src, 'bids')), 'SeeCAT:bids');
tc.verifyError(@() seecat.bids.from_nifti(src, src), 'SeeCAT:bids');
end

function testSourceKind(tc)
src = make_nifti_demo(tc.TestData.src, 'S01');
tc.verifyEqual(seecat.bids.source_kind(src), 'nifti');
d = fullfile(tc.TestData.root, 'dcm');
mkdir(d);
fid = fopen(fullfile(d, 'IM0001'), 'w');
fwrite(fid, zeros(1, 200, 'uint8'));
fclose(fid);
tc.verifyEqual(seecat.bids.source_kind(d), 'dicom');
end

function testAutoTaskNames(tc)
src = tc.TestData.src;
names = {'ep2d_bold_nback_run1', 'Task-Motor_02', 'CCBD_BOLD_PA_REST2', 'fMRI_faces'};
for k = 1:numel(names)
    f = fullfile(src, 'S1', sprintf('%02d_%s', k, names{k}), [names{k} '.nii.gz']);
    img4d(f, [6 6 4], 20);
    sidecar(f, struct('SeriesNumber', k, 'SeriesDescription', names{k}, 'ScanningSequence', 'EP', ...
        'MRAcquisitionType', '2D', 'ImageType', {{'ORIGINAL'; 'PRIMARY'; 'M'}}, 'RepetitionTime', 2));
end
T = seecat.bids.from_nifti(src, tc.TestData.bids, 'dryrun', true);
tc.verifyEqual(T.bids', {'sub-S1/func/sub-S1_task-nback_bold.nii.gz', 'sub-S1/func/sub-S1_task-motor_bold.nii.gz', ...
    'sub-S1/func/sub-S1_task-rest_bold.nii.gz', 'sub-S1/func/sub-S1_task-faces_bold.nii.gz'});
T = seecat.bids.from_nifti(src, tc.TestData.bids, 'dryrun', true, 'auto', false);
tc.verifyTrue(all(contains(T.note, 'looks like BOLD') | ~cellfun(@isempty, T.bids)));
end

%% ---- synthetic data ------------------------------------------------------

function img3d(file, dim, value)
img(file, dim, 1, value);
end

function img4d(file, dim, nv)
img(file, dim, nv, []);
end

function img(file, dim, nv, value, mat)
% A small int16 image; volume k holds the value k (or VALUE for 3D)
if nargin < 5
    mat = [];
end
[d, name, ext] = fileparts(file);
if ~exist(d, 'dir')
    mkdir(d);
end
gz = strcmp(ext, '.gz');
if gz
    file = fullfile(d, name);                    % write the .nii, then compress
end
analyze = endsWith(file, '.img');
vox = 3;
if prod(dim) >= 1e6
    vox = 1;
end
for k = 1:nv
    if isempty(mat)
        mat = diag([vox vox vox 1]);
    end
    V = struct('fname', file, 'dim', dim, 'dt', [spm_type('int16') 0], 'mat', mat, ...
        'pinfo', [1; 0; 0], 'n', [k 1], 'descrip', 'test');
    if analyze
        V.dt = [spm_type('int16') 0];
    end
    if k == 1
        V = spm_create_vol(V);
    else
        V = spm_create_vol(V);
    end
    v = k;
    if ~isempty(value)
        v = value;
    end
    spm_write_vol(V, v * ones(dim));
end
if gz
    gzip(file, d);
    delete(file);
end
end

function sidecar(niiFile, m)
f = regexprep(niiFile, '(\.nii\.gz|\.nii)$', '.json');
seecat.util.write_json(f, m);
end

function j = readJson(root, rel)
j = jsondecode(fileread(fullfile(root, rel)));
end

function h = treeHash(d)
F = dir(fullfile(d, '**', '*'));
F = F(~[F.isdir]);
s = '';
for k = 1:numel(F)
    s = [s, fullfile(F(k).folder, F(k).name), sprintf('%d|', F(k).bytes), seecat.util.file_md5(fullfile(F(k).folder, F(k).name))]; %#ok<AGROW>
end
h = s;
end

function varargout = quiet(f)
[~, varargout{1:nargout}] = evalc('f()');
end
