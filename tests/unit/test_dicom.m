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
% Two fMRI_MB series share a name: run-1 and run-2 by series number
mb = conv.bids(contains(conv.bids, 'task-mb'));
tc.verifyEqual(sort(mb), {'sub-01/func/sub-01_task-mb_run-1_bold.nii.gz'; 'sub-01/func/sub-01_task-mb_run-2_bold.nii.gz'});
tc.verifyTrue(any(contains(conv.bids, 'fmap/sub-01_dir-AP_run-')));
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
% rule for both must give two runs, not one series with two images
qa = fullfile(tc.TestData.qa, 'dcm_qa');
r = rule('^(ax_int_35sl|noPF_noPAT_noPOS_PEres100_ES0p59_BW2222_AP)$', 'func', 'bold', struct('task', 'x'));
T = quiet(@() seecat.bids.from_dicom(fullfile(qa, 'In'), tc.TestData.bids, 'sub', '01', 'rules', r));
got = T(~cellfun(@isempty, T.bids), :);
tc.verifyEqual(got.series, [8; 8]);
tc.verifyEqual(sort(got.bids), {'sub-01/func/sub-01_task-x_run-1_bold.nii.gz'; 'sub-01/func/sub-01_task-x_run-2_bold.nii.gz'});
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

function out = quiet(fn)
[~, out] = evalc('fn()');
end
