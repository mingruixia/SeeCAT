function tests = test_bandpass
% Tests for seecat.denoise.bandpass: equal to the 1.0 filter for ordinary
% bands, and the phase-0 fixes (high-pass only, low cutoff 0).
%   results = runtests('tests/unit/test_bandpass.m')
tests = functiontests(localfunctions);
end

function setupOnce(~)
addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'SeeCAT'));
end

function testBandFilterMatchesLegacyForTypicalBand(tc)
rng(1);
x = randn(150, 40);
y = seecat.denoise.bandpass(x, 2, [0.01 0.1]);
yRef = legacyBandFilter(x, 2, [0.01 0.1]);
tc.verifyEqual(y, yRef, 'AbsTol', 1e-10);
end

function testBandFilterHighPassOnly(tc)
% Legacy code errored here (stray "s" after the condition).
% High cutoff 0 means "no low-pass": same as passing the Nyquist frequency,
% which the legacy code handled correctly.
rng(2);
x = randn(150, 5) + (1:150)' / 50;
y = seecat.denoise.bandpass(x, 2, [0.01 0]);
tc.verifyTrue(isreal(y));
tc.verifyEqual(y, real(legacyBandFilter(x, 2, [0.01 0.25])), 'AbsTol', 1e-10);
end

function testBandFilterLowCutoffZero(tc)
% Legacy mirror index ran past the end of the mask when the low cutoff was 0.
rng(3);
x = randn(150, 5);
y = seecat.denoise.bandpass(x, 2, [0 0.1]);
tc.verifySize(y, size(x));
tc.verifyTrue(isreal(y));
end

%% Seed FC -----------------------------------------------------------------

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
