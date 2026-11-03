function tests = test_dicom
% Tests for seecat.bids.from_dicom with the dcm2niix QA data (dcm_qa,
% dcm_qa_philips: https://github.com/rordenlab). Converted images are
% compared with the reference outputs in their Ref folders.
% Needs dcm2niix (SEECAT_DCM2NIIX or the default path below) and the QA data
% (SEECAT_DICOM_QA); skipped when either is missing.
%   results = runtests('tests/unit/test_dicom.m')
tests = functiontests(localfunctions);
end

function setupOnce(tc)
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..', '..', 'SeeCAT'));
spmDir = getenv('SEECAT_SPM');
if isempty(spmDir)
    spmDir = 'D:/verysync/dropbox/SciTools/MatlabToolbox/spm';
end
addpath(spmDir);
if isempty(getenv('SEECAT_DCM2NIIX'))
    setenv('SEECAT_DCM2NIIX', 'D:/data/SeeCAT_tools/dcm2niix/v1.0.20260724/dcm2niix.exe');
end
qa = getenv('SEECAT_DICOM_QA');
if isempty(qa)
    qa = 'D:/data/SeeCAT_testdata/dicom';
end
tc.TestData.qa = qa;
ok = true;
try
    seecat.util.find_dcm2niix();
catch
    ok = false;
end
tc.assumeTrue(ok && exist(fullfile(qa, 'dcm_qa', 'In'), 'dir') == 7, 'dcm2niix or the QA data not available');
end

function setup(tc)
tc.TestData.bids = fullfile(tempname, 'bids');
end

function teardown(tc)
d = fileparts(tc.TestData.bids);
if exist(d, 'dir')
    rmdir(d, 's');
end
end

function testSiemensMatchesReference(tc)
qa = fullfile(tc.TestData.qa, 'dcm_qa');
rules = qaRules();
T = quiet(@() seecat.bids.from_dicom(fullfile(qa, 'In'), tc.TestData.bids, 'sub', '01', 'rules', rules));
conv = T(~cellfun(@isempty, T.bids), :);
tc.verifyGreaterThanOrEqual(height(conv), 40);
% dcm_qa/In holds two studies: ses-1 and ses-2. Two fMRI_MB series of one
% study share a name: run-1 and run-2 by series number
mb = sort(conv.bids(contains(conv.bids, 'task-mb')));
tc.verifyNumElements(mb, 2);
s = regexp(mb{1}, 'ses-(\d)', 'tokens', 'once');
tc.verifyEqual(mb, {sprintf('sub-01/ses-%s/func/sub-01_ses-%s_task-mb_run-1_bold.nii.gz', s{1}, s{1}); ...
    sprintf('sub-01/ses-%s/func/sub-01_ses-%s_task-mb_run-2_bold.nii.gz', s{1}, s{1})});
tc.verifyTrue(any(contains(conv.bids, 'fmap/sub-01_ses-') & contains(conv.bids, '_dir-AP_run-')));
% Every converted image equals the dcm2niix reference
for i = 1:height(conv)
    compareWithRef(tc, fullfile(tc.TestData.bids, conv.bids{i}), fullfile(qa, 'Ref'));
end
% BOLD sidecars carry TaskName and the multiband SliceTiming
j = jsondecode(fileread(fullfile(tc.TestData.bids, strrep(mb{1}, '.nii.gz', '.json'))));
tc.verifyEqual(j.TaskName, 'mb');
tc.verifyNumElements(j.SliceTiming, 36);
tc.verifyFalse(isfield(j, 'PatientName'));
end

function testDatasetFilesAndRunsTogetherWithBidsReader(tc)
qa = fullfile(tc.TestData.qa, 'dcm_qa');
quiet(@() seecat.bids.from_dicom(fullfile(qa, 'In', 'Orientation', 'axmb'), tc.TestData.bids, 'sub', '01', 'rules', qaRules()));
quiet(@() seecat.bids.from_dicom(fullfile(qa, 'In', 'Orientation', 'axmb'), tc.TestData.bids, 'sub', '02', 'rules', qaRules()));
d = jsondecode(fileread(fullfile(tc.TestData.bids, 'dataset_description.json')));
tc.verifyEqual(d.DatasetType, 'raw');
tc.verifyEqual(d.GeneratedBy(1).Name, 'dcm2niix');
P = seecat.io.read_tsv(fullfile(tc.TestData.bids, 'participants.tsv'));
tc.verifyEqual(P.participant_id, {'sub-01'; 'sub-02'});
tc.verifyTrue(exist(fullfile(tc.TestData.bids, 'code', 'seecat', 'from_dicom_sub-01.tsv'), 'file') == 2);
% The result reads as a BIDS dataset with TR and slice times
L = seecat.bids.layout(tc.TestData.bids);
cfg = seecat.config('prep');
cfg.bids_dir = tc.TestData.bids;
cfg.task = 'mb';
U = seecat.bids.bold_units(L, cfg);
tc.verifyNumElements(U, 4);
tc.verifyEqual(U(1).tr, 3);
tc.verifyNumElements(U(1).meta.SliceTiming, 36);
% A second conversion into the same place is refused unless overwrite
tc.verifyError(@() quiet(@() seecat.bids.from_dicom(fullfile(qa, 'In', 'Orientation', 'axmb'), ...
    tc.TestData.bids, 'sub', '01', 'rules', qaRules())), 'SeeCAT:bids');
quiet(@() seecat.bids.from_dicom(fullfile(qa, 'In', 'Orientation', 'axmb'), tc.TestData.bids, ...
    'sub', '01', 'rules', qaRules(), 'overwrite', true));
end

function testSameSeriesNumberInTwoStudies(tc)
% Series 8 exists in two studies of dcm_qa (ax_int_35sl and an AP EPI); one
% rule for both must give two images, not one series with two images:
% two sessions when the session is automatic, two runs in a given session
qa = fullfile(tc.TestData.qa, 'dcm_qa');
r = rule('^(ax_int_35sl|noPF_noPAT_noPOS_PEres100_ES0p59_BW2222_AP)$', 'func', 'bold', struct('task', 'x'));
T = quiet(@() seecat.bids.from_dicom(fullfile(qa, 'In'), tc.TestData.bids, 'sub', '01', 'rules', r));
got = T(~cellfun(@isempty, T.bids), :);
tc.verifyEqual(got.series, [8; 8]);
tc.verifyEqual(sort(got.bids), {'sub-01/ses-1/func/sub-01_ses-1_task-x_bold.nii.gz'; ...
    'sub-01/ses-2/func/sub-01_ses-2_task-x_bold.nii.gz'});
T = quiet(@() seecat.bids.from_dicom(fullfile(qa, 'In'), tc.TestData.bids, 'sub', '02', 'ses', 'a', 'rules', r));
got = T(~cellfun(@isempty, T.bids), :);
tc.verifyEqual(sort(got.bids), {'sub-02/ses-a/func/sub-02_ses-a_task-x_run-1_bold.nii.gz'; ...
    'sub-02/ses-a/func/sub-02_ses-a_task-x_run-2_bold.nii.gz'});
end

function testSessionsFollowStudies(tc)
% Two studies give ses-1 (the earlier) and ses-2; converting again keeps
% them; a single-study subject gets no session folder, and a second study
% for it then needs a session label
qa = fullfile(tc.TestData.qa, 'dcm_qa');
bids = tc.TestData.bids;
T = quiet(@() seecat.bids.from_dicom(fullfile(qa, 'In'), bids, 'sub', '01', 'rules', qaRules()));
tc.verifyEqual(unique(T.session), {'1'; '2'});
M = seecat.io.read_tsv(fullfile(bids, 'code', 'seecat', 'from_dicom_sessions.tsv'));
tc.verifyEqual(height(M), 2);
tc.verifyEqual(M.session_id(:)', [1 2]);
tc.verifyLessThan(M.study(1), M.study(2));
% axmb is part of the 2014 study: it goes back into that study's session
T2 = quiet(@() seecat.bids.from_dicom(fullfile(qa, 'In', 'Orientation', 'axmb'), bids, 'sub', '01', ...
    'rules', qaRules(), 'overwrite', true));
tc.verifyEqual(unique(T2.session), unique(T.session(contains(T.bids, 'task-orient'))));
tc.verifyEmpty(dir(fullfile(bids, 'sub-01', 'ses-3')));
% one study, new subject: no session folder
T3 = quiet(@() seecat.bids.from_dicom(fullfile(qa, 'In', 'Orientation', 'axmb'), bids, 'sub', '02', 'rules', qaRules()));
tc.verifyEqual(unique(T3.session), {''});
tc.verifyTrue(exist(fullfile(bids, 'sub-02', 'func'), 'dir') == 7);
tc.verifyError(@() quiet(@() seecat.bids.from_dicom(fullfile(qa, 'In', 'TotalReadoutTime'), bids, ...
    'sub', '02', 'rules', qaRules())), 'SeeCAT:bids');
end

function testSubjectsFromFolderNames(tc)
% dcm_qa_philips/In holds one folder per site (different people): each is a
% subject, named after its folder
qa = fullfile(tc.TestData.qa, 'dcm_qa_philips', 'In');
tc.assumeTrue(exist(qa, 'dir') == 7, 'dcm_qa_philips not available');
r = struct('match', struct('SeriesDescription', '^EPI'), 'datatype', 'func', 'suffix', 'bold', ...
    'entities', struct('task', 'test'));
T = quiet(@() seecat.bids.from_dicom(qa, tc.TestData.bids, 'rules', r));
D = dir(qa);
want = regexprep({D([D.isdir] & ~startsWith({D.name}, '.')).name}, '[^a-zA-Z0-9]', '');
tc.verifyEqual(sort(unique(T.subject)), sort(want(:)));
P = seecat.io.read_tsv(fullfile(tc.TestData.bids, 'participants.tsv'));
tc.verifyEqual(sort(P.participant_id), sort(strcat('sub-', want(:))));
tc.verifyTrue(any(strcmp(T.bids, 'sub-Magdeburg2014/func/sub-Magdeburg2014_task-test_bold.nii.gz')));
end

function testSeriesFoldersOfOnePersonAreOneSubject(tc)
% Orientation/axmb holds two series folders of one phantom: one subject named
% after the folder, not two subjects
qa = fullfile(tc.TestData.qa, 'dcm_qa', 'In', 'Orientation', 'axmb');
D = dir(qa);
tc.assumeEqual(nnz([D.isdir] & ~startsWith({D.name}, '.')), 2);
T = quiet(@() seecat.bids.from_dicom(qa, tc.TestData.bids, 'rules', qaRules()));
tc.verifyEqual(unique(T.subject), {'axmb'});
tc.verifyTrue(all(startsWith(T.bids(~cellfun(@isempty, T.bids)), 'sub-axmb/func/')));
end

function testFailedSubjectDoesNotStopTheOthers(tc)
% S_02 holds a DICOM header without its image data: dcm2niix fails on it,
% S_01 still converts; S_03 holds no DICOM and is skipped
root = fullfile(fileparts(tc.TestData.bids), 'dicom');
mkdir(fullfile(root, 'S_01'));
mkdir(fullfile(root, 'S_02'));
mkdir(fullfile(root, 'S_03'));
copyfile(fullfile(tc.TestData.qa, 'dcm_qa', 'In', 'Orientation', 'axmb'), fullfile(root, 'S_01'));
src = series(tc, 'B', 1);
F = dir(fullfile(src, '*'));
F = F(~[F.isdir]);
fid = fopen(fullfile(src, F(1).name), 'r');
bytes = fread(fid, Inf, '*uint8');
fclose(fid);
fid = fopen(fullfile(root, 'S_02', 'IM0001'), 'w');
fwrite(fid, bytes(1:round(numel(bytes) / 3)));
fclose(fid);
fid = fopen(fullfile(root, 'S_03', 'readme.dat'), 'w'); fprintf(fid, 'not DICOM'); fclose(fid);
T = quiet(@() seecat.bids.from_dicom(root, tc.TestData.bids, 'rules', qaRules()));
tc.verifyEqual(sort(unique(T.subject)), {'S01'; 'S02'});
tc.verifyTrue(all(contains(T.bids(strcmp(T.subject, 'S01')), 'sub-S01/func/')));
bad = T(strcmp(T.subject, 'S02'), :);
tc.verifyEqual(height(bad), 1);
tc.verifySubstring(bad.note{1}, 'dcm2niix');
end

function testModalityFoldersWithSubjectFolders(tc)
% T1/S_01, REST/S_01, T1/S_02, REST/S_02: subjects S01 and S02 (told apart
% by PatientID), each converted from its two folders
root = fullfile(fileparts(tc.TestData.bids), 'dicom');
layout(tc, root, {'T1/S_01', 'A', 1; 'REST/S_01', 'A', 2; 'T1/S_02', 'B', 1; 'REST/S_02', 'B', 2});
[S, roots, info] = seecat.bids.scan_dicom(root);
tc.verifyEqual(info.mode, 'PatientID');
tc.verifyEqual(S.subject, {'S01'; 'S02'});
tc.verifyEqual(cellfun(@numel, roots), [2; 2]);
tc.verifyEqual(S.source{1}, 'REST/S_01; T1/S_01');
T = quiet(@() seecat.bids.from_dicom(root, tc.TestData.bids, 'rules', qaRules()));
got = T.bids(strcmp(T.subject, 'S01') & ~cellfun(@isempty, T.bids));
tc.verifyNumElements(got, 2);                     % both axmb series, from two folders
tc.verifyEqual(sort(got), {'sub-S01/func/sub-S01_task-mb_run-1_bold.nii.gz'; ...
    'sub-S01/func/sub-S01_task-mb_run-2_bold.nii.gz'});
end

function testSubjectFoldersWithVisitsAndSeries(tc)
% S_01/visit1/<series>, S_02/visit1/<series>: the subject folder names them
root = fullfile(fileparts(tc.TestData.bids), 'dicom');
layout(tc, root, {'S_01/visit1/a', 'A', 1; 'S_01/visit1/b', 'A', 2; 'S_02/visit1/a', 'B', 1});
[S, roots] = seecat.bids.scan_dicom(root);
tc.verifyEqual(S.subject, {'S01'; 'S02'});
tc.verifyEqual(roots{1}, {fullfile(root, 'S_01')});
% one person's series only: named after the folder above them
[S, ~, info] = seecat.bids.scan_dicom(fullfile(root, 'S_01', 'visit1'));
tc.verifyEqual(S.subject, {'visit1'});
tc.verifyEqual(info.mode, 'PatientID');
end

function testAnonymisedFoldersAreReadFromTheTree(tc)
% PatientID removed: modality folders with subject folders inside are
% recognised from the tree; one folder per subject too
root = fullfile(fileparts(tc.TestData.bids), 'dicom');
layout(tc, root, {'T1/S_01', 'A', 1; 'REST/S_01', 'A', 2; 'T1/S_02', 'A', 1; 'REST/S_02', 'A', 2; ...
    'T1/S_03', 'A', 1; 'REST/S_03', 'A', 2});
anonymise(root);
[S, ~, info] = seecat.bids.scan_dicom(root);
tc.verifyEqual(info.mode, 'folders');
tc.verifyEqual(S.subject, {'S01'; 'S02'; 'S03'});
tc.verifySubstring(info.layout, 'modalities');
% two subjects, two modalities: the modality names decide
root2 = fullfile(fileparts(tc.TestData.bids), 'dicom2');
layout(tc, root2, {'T1/S_01', 'A', 1; 'REST/S_01', 'A', 2; 'T1/S_02', 'A', 1; 'REST/S_02', 'A', 2});
anonymise(root2);
S = seecat.bids.scan_dicom(root2);
tc.verifyEqual(S.subject, {'S01'; 'S02'});
root3 = fullfile(fileparts(tc.TestData.bids), 'dicom3');
layout(tc, root3, {'S_01/T1', 'A', 1; 'S_01/REST', 'A', 2; 'S_02/T1', 'A', 1; 'S_02/REST', 'A', 2});
anonymise(root3);
S = seecat.bids.scan_dicom(root3);
tc.verifyEqual(S.subject, {'S01'; 'S02'});
end

function testFolderWithTwoPatientsIsAnError(tc)
root = fullfile(fileparts(tc.TestData.bids), 'dicom');
mkdir(root);
copyFiles(series(tc, 'A', 1), root, 'a_');
copyFiles(series(tc, 'B', 1), root, 'z_');
tc.verifyError(@() seecat.bids.scan_dicom(root), 'SeeCAT:bids');
end

function testPhilipsWithoutSliceTimingIsReported(tc)
qa = fullfile(tc.TestData.qa, 'dcm_qa_philips');
tc.assumeTrue(exist(fullfile(qa, 'In', 'Magdeburg_2014'), 'dir') == 7, 'dcm_qa_philips not available');
r = struct('match', struct('SeriesDescription', '^EPI'), 'datatype', 'func', 'suffix', 'bold', ...
    'entities', struct('task', 'test'));
T = quiet(@() seecat.bids.from_dicom(fullfile(qa, 'In', 'Magdeburg_2014'), tc.TestData.bids, 'sub', '01', 'rules', r));
row = T(~cellfun(@isempty, T.bids), :);
tc.verifyNumElements(row.bids, 1);
tc.verifySubstring(row.note{1}, 'no SliceTiming');
compareWithRef(tc, fullfile(tc.TestData.bids, row.bids{1}), fullfile(qa, 'Ref'));
end

function testDefaultRulesSkipEverythingUnknown(tc)
qa = fullfile(tc.TestData.qa, 'dcm_qa');
T = quiet(@() seecat.bids.from_dicom(fullfile(qa, 'In', 'Orientation', 'axmb'), tc.TestData.bids, 'sub', '01'));
tc.verifyTrue(all(cellfun(@isempty, T.bids)));
tc.verifyTrue(all(strcmp(T.note, 'no rule matched')));
end

function testRuleErrors(tc)
tc.verifyError(@() seecat.bids.dicom_rules(struct('match', struct('SeriesDescription', 'x'), ...
    'datatype', 'func', 'suffix', 'bold')), 'SeeCAT:bids');                      % func without task
tc.verifyError(@() seecat.bids.from_dicom(tc.TestData.qa, tc.TestData.bids, 'sub', 'a_b'), 'SeeCAT:bids');
end

%% Helpers -------------------------------------------------------------------

function r = qaRules()
r(1) = rule('^fMRI_MB_', 'func', 'bold', struct('task', 'mb'));
r(2) = rule('^(ax|cor|sag)_(asc|desc|int)', 'func', 'bold', struct('task', 'orient'));
r(3) = rule('_AP$', 'fmap', 'epi', struct('dir', 'AP'));
r(4) = rule('_PA$', 'fmap', 'epi', struct('dir', 'PA'));
r(5) = rule('_LR$', 'fmap', 'epi', struct('dir', 'LR'));
r(6) = rule('_RL$', 'fmap', 'epi', struct('dir', 'RL'));
end

function r = rule(pattern, datatype, suffix, ent)
r = struct('match', struct('SeriesDescription', pattern), 'datatype', datatype, 'suffix', suffix, 'entities', ent);
end

function compareWithRef(tc, nii, refDir)
% Find the reference image of the same series and compare data, affine and
% every sidecar field present in both
j = jsondecode(fileread(strrep(nii, '.nii.gz', '.json')));
R = dir(fullfile(refDir, '*.json'));
ref = '';
for k = 1:numel(R)
    rj = jsondecode(fileread(fullfile(R(k).folder, R(k).name)));
    if isfield(rj, 'SeriesNumber') && isequal(rj.SeriesNumber, j.SeriesNumber) && ...
            strcmp(rj.SeriesDescription, j.SeriesDescription)
        ref = fullfile(R(k).folder, R(k).name);
        break
    end
end
tc.assertNotEmpty(ref, sprintf('no reference for %s', nii));
[a, Va] = seecat.io.read_nii(nii);
[b, Vb] = seecat.io.read_nii(regexprep(ref, '\.json$', '.nii'));
tc.verifyEqual(a, b, sprintf('data differ: %s', nii));
tc.verifyEqual(Va(1).mat, Vb(1).mat, 'AbsTol', 1e-4, sprintf('affine differs: %s', nii));
% WipMemBlock: dcm2niix v1.0.20260724 itself prefixes it with an identifier
% that the reference version did not write (seen running dcm2niix directly)
skip = {'TaskName', 'ConversionSoftwareVersion', 'WipMemBlock'};
f = setdiff(intersect(fieldnames(j), fieldnames(rj)), skip);
diffs = f(~cellfun(@(x) isequaln(j.(x), rj.(x)) || ...
    (isnumeric(j.(x)) && isnumeric(rj.(x)) && isequal(size(j.(x)), size(rj.(x))) && ...
    max(abs(j.(x)(:) - rj.(x)(:))) < 1e-6), f));
tc.verifyEmpty(diffs, sprintf('%s: sidecar fields differ from the reference: %s', nii, strjoin(diffs, ', ')));
end

function d = series(tc, who, k)
% A small series folder of person A (the Orientation phantom, axmb) or B
% (the TotalReadoutTime session); K picks one of two
qa = fullfile(tc.TestData.qa, 'dcm_qa', 'In');
if who == 'A'
    D = dir(fullfile(qa, 'Orientation', 'axmb'));
else
    D = dir(fullfile(qa, 'TotalReadoutTime', 'PF_PAT_POS_PFOV_PEres_INTERP_test2', '*_0016'));
    D = [D; dir(fullfile(qa, 'TotalReadoutTime', 'PF_PAT_POS_PFOV_PEres_INTERP_test2', '*_0017'))];
end
D = D([D.isdir] & ~startsWith({D.name}, '.'));
d = fullfile(D(k).folder, D(k).name);
end

function layout(tc, root, spec)
% SPEC rows: folder under ROOT, person, series number (see series)
for i = 1:size(spec, 1)
    dst = fullfile(root, spec{i, 1});
    mkdir(dst);
    copyFiles(series(tc, spec{i, 2}, spec{i, 3}), dst, '');
end
end

function copyFiles(src, dst, prefix)
F = dir(fullfile(src, '*'));
for f = F(~[F.isdir])'
    copyfile(fullfile(f.folder, f.name), fullfile(dst, [prefix f.name]));
end
end

function anonymise(root)
% Overwrite PatientID and PatientName with x's of the same length
F = dir(fullfile(root, '**', '*'));
for f = F(~[F.isdir])'
    file = fullfile(f.folder, f.name);
    fid = fopen(file, 'r');
    b = fread(fid, Inf, '*uint8')';
    fclose(fid);
    for el = [32 16]                               % (0010,0020), (0010,0010)
        p = strfind(b(133:min(end, 65536)), uint8([16 0 el 0])) + 132;
        if isempty(p), continue, end
        p = p(1);
        if all(b(p + 4:p + 5) >= 65 & b(p + 4:p + 5) <= 90)
            len = double(b(p + 6)) + 256 * double(b(p + 7));
        else
            len = double(typecast(b(p + 4:p + 7), 'uint32'));
        end
        b(p + 8:p + 7 + len) = uint8('x');
    end
    fid = fopen(file, 'w');
    fwrite(fid, b);
    fclose(fid);
end
end

function out = quiet(fn)
[~, out] = evalc('fn()');
end
