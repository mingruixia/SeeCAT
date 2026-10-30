function tests = test_io
% Unit tests for sc_read_nii / sc_write_nii.
%   results = runtests('tests/unit/test_io.m')
tests = functiontests(localfunctions);
end

function setupOnce(tc)
root = fullfile(fileparts(mfilename('fullpath')), '..', '..');
addpath(genpath(fullfile(root, 'SeeCAT')));
spmDir = getenv('SEECAT_SPM');
if isempty(spmDir)
    spmDir = 'D:/verysync/dropbox/SciTools/MatlabToolbox/spm';
end
addpath(spmDir);
tc.TestData.tmp = tempname;
mkdir(tc.TestData.tmp);
end

function teardownOnce(tc)
rmdir(tc.TestData.tmp, 's');
end

function testRoundTrip3DKeepsVoxelsAndAffine(tc)
% LAS affine (negative x step): nothing may be flipped on the way through
rng(1);
Y = randn(5, 6, 7);
ref = grid([5 6 7], lasMat());
f = fullfile(tc.TestData.tmp, 'rt3d', 'a.nii');      % folder does not exist yet
V = sc_write_nii(Y, ref, f, 'Descrip', 'T map');
[Z, H] = sc_read_nii(f);
tc.verifyEqual(Z, double(single(Y)));
tc.verifyEqual(H.mat, lasMat());
tc.verifyEqual(V.descrip, 'T map');
tc.verifyEqual(V.dt(1), 16);
end

function testRoundTrip4DVolumesAndClass(tc)
rng(2);
Y = randn(4, 4, 3, 10);
ref = grid([4 4 3], rasMat());
f = fullfile(tc.TestData.tmp, 'b.nii');
sc_write_nii(Y, ref, f, 'DataType', 'float64');
[Z, H] = sc_read_nii(f, 'Volumes', [2 5 9], 'Class', 'single');
tc.verifyClass(Z, 'single');
tc.verifyEqual(Z, single(Y(:, :, :, [2 5 9])));
tc.verifyEqual([H.n], [2 1 5 1 9 1]);
end

function testGzip(tc)
rng(3);
Y = randn(4, 5, 6, 3);
f = fullfile(tc.TestData.tmp, 'c.nii.gz');
V = sc_write_nii(Y, grid([4 5 6], rasMat()), f);
tc.verifyEmpty(V);
tc.verifyTrue(exist(f, 'file') == 2);
tc.verifyFalse(exist(f(1:end-3), 'file') == 2);
[Z, H] = sc_read_nii(f);
tc.verifyEqual(Z, double(single(Y)));
tc.verifyEqual(H(1).fname, f);
% a .gz file also works as the reference for writing
sc_write_nii(Z(:, :, :, 1), f, fullfile(tc.TestData.tmp, 'c2.nii'));
end

function testFileListStacksVolumes(tc)
rng(4);
ref = grid([3 3 3], rasMat());
f = cell(3, 1);
Y = randn(3, 3, 3, 4);
f{1} = fullfile(tc.TestData.tmp, 'l1.nii');
f{2} = fullfile(tc.TestData.tmp, 'l2.nii');
sc_write_nii(Y(:, :, :, 1), ref, f{1});
sc_write_nii(Y(:, :, :, 2:4), ref, f{2});         % 3D and 4D mixed
[Z, H] = sc_read_nii(f(1:2));
tc.verifyEqual(Z, double(single(Y)));
tc.verifyNumElements(H, 4);
% a third file on a shifted grid is rejected without 'Ref'
f{3} = fullfile(tc.TestData.tmp, 'l3.nii');
M = rasMat(); M(1, 4) = M(1, 4) + 1;
sc_write_nii(Y(:, :, :, 1), grid([3 3 3], M), f{3});
tc.verifyError(@() sc_read_nii(f), 'SeeCAT:read');
end

function testRefResamplesInWorldSpace(tc)
% The same world-space image stored as RAS and as LAS reads back identically
% on a common grid. This is the case y_ReadRPI got wrong when the field of
% view is not centred on x = 0.
rng(5);
Yras = randn(6, 5, 4);
Mras = rasMat();
Mras(1, 4) = 7;                                   % off-centre in x
fr = fullfile(tc.TestData.tmp, 'ras.nii');
fl = fullfile(tc.TestData.tmp, 'las.nii');
sc_write_nii(Yras, grid([6 5 4], Mras), fr);
Mlas = Mras * [-1 0 0 7; 0 1 0 0; 0 0 1 0; 0 0 0 1];   % voxel i -> 7 - i, x step negated
sc_write_nii(flip(Yras, 1), grid([6 5 4], Mlas), fl);
[Zl, H] = sc_read_nii(fl, 'Ref', spm_vol(fr));
tc.verifyEqual(Zl, double(single(Yras)), 'AbsTol', 1e-6);
tc.verifyEqual(H.mat, Mras);
% stored orientation is kept when no 'Ref' is given
[Zl0, Hl] = sc_read_nii(fl);
tc.verifyEqual(Zl0, double(single(flip(Yras, 1))));
tc.verifyEqual(Hl.mat, Mlas, 'AbsTol', 1e-12);
end

function testRealignedSeriesReadsAsStored(tc)
% Realignment stores one affine per volume in a 4D file
rng(6);
Y = randn(4, 4, 4, 3);
f = fullfile(tc.TestData.tmp, 'r.nii');
sc_write_nii(Y, grid([4 4 4], rasMat()), f);
M = rasMat(); M(1, 4) = M(1, 4) + 0.5;
spm_get_space([f ',2'], M);
[Z, H] = sc_read_nii(f);
tc.verifyEqual(Z, double(single(Y)));
tc.verifyEqual(H(2).mat, M, 'AbsTol', 1e-6);
end

function testIntegerOutput(tc)
Y = [1.4 -2.6 NaN 40000];
Y = reshape([Y zeros(1, 4)], 2, 2, 2);
f = fullfile(tc.TestData.tmp, 'i.nii');
tc.verifyWarning(@() sc_write_nii(Y, grid([2 2 2], rasMat()), f, 'DataType', 'int16'), 'SeeCAT:write');
Z = sc_read_nii(f);
tc.verifyEqual(Z(1:4), [1 -3 0 32767]);
tc.verifyEqual(spm_vol(f).dt(1), 4);
end

function testSizeMismatchIsAnError(tc)
f = fullfile(tc.TestData.tmp, 'bad.nii');
tc.verifyError(@() sc_write_nii(zeros(3, 3, 3), grid([3 3 4], rasMat()), f), 'SeeCAT:write');
end

%% Helpers -------------------------------------------------------------------

function h = grid(dim, M)
h = struct('dim', dim, 'mat', M);
end

function M = rasMat()
M = [2 0 0 -4; 0 2 0 -5; 0 0 2 -6; 0 0 0 1];
end

function M = lasMat()
M = [-2 0 0 4; 0 2 0 -5; 0 0 2 -6; 0 0 0 1];
end
