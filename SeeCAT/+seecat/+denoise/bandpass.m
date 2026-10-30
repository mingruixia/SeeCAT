function Data_Filtered = bandpass(Data, SamplePeriod, Band)
% BANDPASS  Ideal FFT band-pass filter applied to each column of DATA.
%   Y = seecat.denoise.bandpass(X, TR, [low high])   % Hz; high = 0 or >= Nyquist: high-pass only
% Columns are demeaned; data are zero-padded to the next power of two.
sampleFreq 	 = 1/SamplePeriod;
sampleLength = size(Data,1);
paddedLength = 2^nextpow2(sampleLength);
LowCutoff_HighPass = Band(1);
HighCutoff_LowPass = Band(2);
if (HighCutoff_LowPass>=sampleFreq/2)||(HighCutoff_LowPass==0)
    HighCutoff_LowPass = sampleFreq/2;   % no low-pass
end
% Frequency of each FFT bin, folded so the mask is symmetric
k = (0:paddedLength-1)';
binFreq = min(k, paddedLength-k) / (paddedLength*SamplePeriod);
FrequencySetZero_Index = binFreq < LowCutoff_HighPass | binFreq > HighCutoff_LowPass;
Data = Data - repmat(mean(Data),size(Data,1),1);
Data = [Data;zeros(paddedLength -sampleLength,size(Data,2))];
Data = fft(Data);
Data(FrequencySetZero_Index,:) = 0;
Data = real(ifft(Data));
Data_Filtered = Data(1:sampleLength,:);
