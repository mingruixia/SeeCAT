function tests = test_p0_fixes
% Unit tests for the phase-0 bug fixes, on synthetic data.
%   results = runtests('tests/unit/test_p0_fixes.m')
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

%% Band-pass filter -------------------------------------------------------

function testBandFilterMatchesLegacyForTypicalBand(tc)
rng(1);
x = randn(150, 40);
y = sc_bandpass(x, 2, [0.01 0.1]);
yRef = legacyBandFilter(x, 2, [0.01 0.1]);
tc.verifyEqual(y, yRef, 'AbsTol', 1e-10);
end

function testBandFilterHighPassOnly(tc)
% Legacy code errored here (stray "s" after the condition).
% High cutoff 0 means "no low-pass": same as passing the Nyquist frequency,
% which the legacy code handled correctly.
rng(2);
x = randn(150, 5) + (1:150)' / 50;
y = sc_bandpass(x, 2, [0.01 0]);
tc.verifyTrue(isreal(y));
tc.verifyEqual(y, real(legacyBandFilter(x, 2, [0.01 0.25])), 'AbsTol', 1e-10);
end

function testBandFilterLowCutoffZero(tc)
% Legacy mirror index ran past the end of the mask when the low cutoff was 0.
rng(3);
x = randn(150, 5);
y = sc_bandpass(x, 2, [0 0.1]);
tc.verifySize(y, size(x));
tc.verifyTrue(isreal(y));
end

%% Seed FC -----------------------------------------------------------------

function testSeedFCMatchesCorr(tc)
d = fullfile(tc.TestData.tmp, 'fc');
[dataFile, hdr, seedSig, vox] = makeSeedData(d, 'sub-01');
mask = zeros(hdr.dim);
mask(2:end-1, 2:end-1, 2:end-1) = 1;
mask_ind = reshape(mask > 0, 1, []);
seed_ind = {false(1, prod(hdr.dim))};
seed_ind{1}(sub2ind(hdr.dim, 4, 4, 4)) = true;
outDir = fullfile(d, 'out');
mkdir(fullfile(outDir, 'FC_Seed01')); mkdir(fullfile(outDir, 'zFC_Seed01'));
sc_seed_fc_subject(dataFile, 'sub-01', hdr, mask_ind, seed_ind, outDir);
r = spm_read_vols(spm_vol(fullfile(outDir, 'FC_Seed01', 'FC_Seed01_sub-01.nii')));
z = spm_read_vols(spm_vol(fullfile(outDir, 'zFC_Seed01', 'zFC_Seed01_sub-01.nii')));
rRef = corr(seedSig, vox)';
rRef(~isfinite(rRef)) = 0;                               % constant voxel
rRef = reshape(rRef, hdr.dim);
tc.verifyEqual(r(mask > 0), rRef(mask > 0), 'AbsTol', 1e-6);
tc.verifyEqual(r(mask == 0), zeros(nnz(mask == 0), 1));
tc.verifyTrue(all(isfinite(z(:))));                       % seed voxel r=1 must not give Inf
tc.verifyEqual(z(5, 5, 5), 0);                           % zero-variance voxel -> 0, not NaN
end

%% Statistics: repeated-measures ANOVA ---------------------------------------

function testRepeatedMeasuresFMatchesManual(tc)
rng(4);
nSub = 8; nCond = 3; dim = [3 3 3];
subjEffect = 5 * randn(nSub, 1);
condEffect = [0; 1; 2];
d = fullfile(tc.TestData.tmp, 'rm');
mkdir(d);
cells = cell(nCond, 1);
Y = zeros(nSub, nCond, prod(dim));
for c = 1:nCond
    for s = 1:nSub
        v = subjEffect(s) + condEffect(c) + randn(dim);
        Y(s, c, :) = v(:);
        f = fullfile(d, sprintf('c%d_s%02d.nii', c, s));
        writeVol(f, v);
        cells{c}{s, 1} = f;
    end
end
F = runStat(tc, 5, cells, fullfile(d, 'out'), 'FR');
for k = [1 14 27]
    tc.verifyEqual(F(k), rmAnovaF(Y(:, :, k)), 'RelTol', 1e-6);
end
end

%% Helpers -------------------------------------------------------------------

function F = runStat(tc, typeValue, cells, outDir, prefix)
mkdir(outDir);
h = SeeCAT_Stat;
set(h, 'Visible', 'off');
c = onCleanup(@() delete(h));
H = guidata(h);
set(H.TypeListbox, 'Value', typeValue);
SeeCAT_Stat('TypeListbox_Callback', H.TypeListbox, [], H);
H = guidata(h);
H.SampleCells = cells(:)';
set(H.MaskEntry, 'String', '');
set(H.OutputDirEntry, 'String', outDir);
set(H.PrefixEntry, 'String', prefix);
guidata(h, H);
SeeCAT_Stat('ComputeButton_Callback', H.ComputeButton, [], H);
% The viewer reads the degrees of freedom from the header description
tc.verifyTrue(startsWith(spm_vol(fullfile(outDir, [prefix '.nii'])).descrip, 'CAT{'));
% Compare in world space: sample the output on the first input's voxel grid
F = sc_resample_to_ref(fullfile(outDir, [prefix '.nii']), spm_vol(cells{1}{1}));
F = F(:);
tc.assertNotEmpty(F);
end

function F = rmAnovaF(Y)
% One-way repeated-measures ANOVA F for an nSub x nCond matrix
[n, k] = size(Y);
gm = mean(Y(:));
ssCond = n * sum((mean(Y, 1) - gm).^2);
ssSubj = k * sum((mean(Y, 2) - gm).^2);
ssTot = sum((Y(:) - gm).^2);
ssErr = ssTot - ssCond - ssSubj;
F = (ssCond / (k - 1)) / (ssErr / ((n - 1) * (k - 1)));
end

function [dataFile, hdr, seedSig, vox] = makeSeedData(d, sub)
rng(5);
dim = [7 7 7]; nT = 120;
mkdir(d);
seedSig = randn(nT, 1);
w = reshape(linspace(-0.9, 0.9, prod(dim)), 1, []);
vox = seedSig * w + 0.5 * randn(nT, prod(dim));
vox(:, sub2ind(dim, 4, 4, 4)) = seedSig;              % seed voxel itself
vox(:, sub2ind(dim, 5, 5, 5)) = 3;                     % constant voxel
seedSig = vox(:, sub2ind(dim, 4, 4, 4));
dataFile = fullfile(d, [sub '_bold.nii']);
N = nifti;
N.dat = file_array(dataFile, [dim nT], 'FLOAT32-LE');
N.mat = [3 0 0 -9; 0 3 0 -9; 0 0 3 -9; 0 0 0 1];
N.mat0 = N.mat;
create(N);
N.dat(:, :, :, :) = reshape(vox', [dim nT]);
hdr = spm_vol(dataFile);
hdr = hdr(1);
end

function writeVol(f, v)
h = struct('fname', f, 'dim', size(v), 'dt', [16 0], 'pinfo', [1; 0; 0], ...
    'mat', [3 0 0 -3; 0 3 0 -3; 0 0 3 -3; 0 0 0 1], 'n', [1 1], 'descrip', '');
spm_write_vol(h, v);
end

function Data_Filtered = legacyBandFilter(Data, SamplePeriod, Band)
% Copy of the SeeCAT 1.0 implementation (valid for 0 < low < high < Nyquist)
sampleFreq = 1/SamplePeriod;
sampleLength = size(Data,1);
paddedLength = 2^nextpow2(sampleLength);
idxLow = ceil(Band(1) * paddedLength * SamplePeriod + 1);
if Band(2) >= sampleFreq/2 || Band(2) == 0
    idxHigh = paddedLength/2 + 1;
else
    idxHigh = fix(Band(2) * paddedLength * SamplePeriod + 1);
end
FrequencyMask = zeros(paddedLength,1);
FrequencyMask(idxLow:idxHigh,1) = 1;
FrequencyMask(paddedLength-idxLow+2:-1:paddedLength-idxHigh+2,1) = 1;
Data = Data - mean(Data);
Data = [Data; zeros(paddedLength-sampleLength, size(Data,2))];
Data = fft(Data);
Data(FrequencyMask==0,:) = 0;
Data = ifft(Data);
Data_Filtered = Data(1:sampleLength,:);
end
