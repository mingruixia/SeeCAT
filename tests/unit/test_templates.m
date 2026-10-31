function tests = test_templates
% Tests for the TPM-based group masks in SeeCAT/templates.
%   results = runtests('tests/unit/test_templates.m')
tests = functiontests(localfunctions);
end

function setupOnce(tc)
here = fileparts(mfilename('fullpath'));
tc.TestData.repo = fullfile(here, '..', '..', 'SeeCAT');
addpath(tc.TestData.repo);
spmDir = getenv('SEECAT_SPM');
if isempty(spmDir)
    spmDir = 'D:/verysync/dropbox/SciTools/MatlabToolbox/spm';
end
addpath(spmDir);
tc.TestData.out = tempname;
files = seecat.util.make_templates(tc.TestData.out, [2 3]);
tc.TestData.files = files;
end

function teardownOnce(tc)
rmdir(tc.TestData.out, 's');
end

function testRegeneratingGivesTheCommittedMasks(tc)
tc.verifyNumElements(tc.TestData.files, 8);
for i = 1:numel(tc.TestData.files)
    [~, name, ext] = fileparts(tc.TestData.files{i});
    [a, Va] = seecat.io.read_nii(tc.TestData.files{i});
    [b, Vb] = seecat.io.read_nii(fullfile(tc.TestData.repo, 'templates', [name ext]));
    tc.verifyEqual(a, b, name);
    tc.verifyEqual(Va.mat, Vb.mat, name);
end
end

function testGridsMatchNormaliseOutput(tc)
[~, V3] = seecat.io.read_nii(fullfile(tc.TestData.out, 'tpl-IXI549Space_res-3_label-GM_mask.nii'));
tc.verifyEqual(V3.dim, [61 73 61]);
tc.verifyEqual(V3.mat, [-3 0 0 93; 0 3 0 -129; 0 0 3 -75; 0 0 0 1]);   % SeeCAT 1.0 masks' grid
[~, V2] = seecat.io.read_nii(fullfile(tc.TestData.out, 'tpl-IXI549Space_res-2_label-GM_mask.nii'));
tc.verifyEqual(V2.dim, [91 109 91]);
tc.verifyEqual(V2.mat, [-2 0 0 92; 0 2 0 -128; 0 0 2 -74; 0 0 0 1]);
end

function testMasksAreSensible(tc)
f = @(n) seecat.io.read_nii(fullfile(tc.TestData.out, ['tpl-IXI549Space_res-3_' n '_mask.nii'])) > 0;
brain = f('desc-brain');
[~, V] = seecat.io.read_nii(fullfile(tc.TestData.out, 'tpl-IXI549Space_res-3_desc-brain_mask.nii'));
icv = seecat.io.read_nii(fullfile(spm('dir'), 'tpm', 'mask_ICV.nii'), 'Ref', V, 'Interp', 1) > 0.5;
tc.verifyGreaterThan(2 * nnz(brain & icv) / (nnz(brain) + nnz(icv)), 0.98);
for t = {'label-GM', 'label-WM', 'label-CSF'}
    m = f(t{1});
    tc.verifyGreaterThan(nnz(m), 1000, t{1});
    tc.verifyGreaterThan(nnz(m & brain) / nnz(m), 0.95, t{1});
end
j = jsondecode(fileread(fullfile(tc.TestData.out, 'tpl-IXI549Space_res-3_label-GM_mask.json')));
tc.verifyEqual(j.Threshold, 0.2);
tc.verifyEqual(j.Sources, {'spm/tpm/TPM.nii'});
end
