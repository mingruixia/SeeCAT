function tests = test_denoise
% Tests for seecat.denoise: FD, frame flagging, interpolation, the
% censor-aware denoising model, regressor selection and aCompCor.
%   results = runtests('tests/unit/test_denoise.m')
tests = functiontests(localfunctions);
end

function setupOnce(~)
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..', '..', 'SeeCAT'));
end

function testFdPower(tc)
rp = zeros(4, 6);
rp(2, 1) = 0.3;                 % 0.3 mm in x
rp(3, :) = [0.3 0 0 0.01 0 0];  % plus 0.01 rad = 0.5 mm on the 50 mm sphere
rp(4, :) = rp(3, :);
fd = seecat.denoise.fd_power(rp);
tc.verifyTrue(isnan(fd(1)));
tc.verifyEqual(fd(2:4), [0.3; 0.5; 0], 'AbsTol', 1e-12);
end

function testFlagFramesNeighboursAndEdges(tc)
fd = [NaN 0 0 0.6 0 0 0 0 0 0.9]';
bad = seecat.denoise.flag_frames(fd, 0.5, 1, 2);
tc.verifyEqual(find(bad)', [3 4 5 6 9 10]);
tc.verifyFalse(any(seecat.denoise.flag_frames([NaN; 0.1], 0.5, 1, 2)));
end

function testSplineKeepsGoodFramesAndFillsGaps(tc)
tr = 2;
t = (0:99)' * tr;
y = sin(2 * pi * 0.02 * t);
bad = false(100, 1);
bad([1 2 40:42 100]) = true;
z = seecat.denoise.interpolate(y + 10 * bad, bad, tr, 'spline');
tc.verifyEqual(z(~bad), y(~bad));
tc.verifyEqual(z(40:42), y(40:42), 'AbsTol', 1e-2);
tc.verifyEqual(z(1:2), [y(3); y(3)]);      % edges: nearest good frame
tc.verifyEqual(z(100), y(99));
end

function testSpectralRecoversInBandSignal(tc)
tr = 2;
t = (0:149)' * tr;
y = sin(2 * pi * 0.03 * t) + 0.5 * cos(2 * pi * 0.05 * t);
bad = false(150, 1);
bad([30:33 80:82]) = true;
z = seecat.denoise.interpolate(y + 10 * bad, bad, tr, 'spectral', 0.1);
tc.verifyEqual(z(~bad), y(~bad));
tc.verifyLessThan(max(abs(z(bad) - y(bad))), 0.3);   % ridge shrinks a little
% A large offset (BOLD is ~1000) must not change the fill: the mean is not
% shrunk, or the filled frames would form a step the band-pass spreads
z2 = seecat.denoise.interpolate(y + 1000, bad, tr, 'spectral', 0.1);
tc.verifyEqual(z2(bad) - 1000, z(bad), 'AbsTol', 1e-8);
end

function testSpectralBeatsMeanWithNoise(tc)
% In-band signal plus broadband noise, interior gaps: the fill must be
% closer to the signal than the mean is (Lomb-Scargle was not).
rng(4);
tr = 2;
T = 150;
bad = false(T, 1);
bad([30:33 70 100:104]) = true;
s = seecat.denoise.bandpass(randn(T, 200), tr, [0.01 0.1]);
s = s ./ std(s);
z = seecat.denoise.interpolate(s + 0.5 * randn(T, 200), bad, tr, 'spectral', 0.1);
errFill = sqrt(mean((z(bad, :) - s(bad, :)) .^ 2, 'all'));
errMean = sqrt(mean((mean(s(~bad, :)) - s(bad, :)) .^ 2, 'all'));
tc.verifyLessThan(errFill, 0.9 * errMean);
end

function testCleanRemovesConfoundsInBand(tc)
rng(1);
tr = 2;
T = 200;
R = seecat.denoise.bandpass(randn(T, 3), tr, [0.01 0.1]) * 5;
s = seecat.denoise.bandpass(randn(T, 4), tr, [0.01 0.1]);
Y = s + R * [1 2 0 3; 0 1 1 0; 2 0 1 1] + 100;
E = seecat.denoise.clean(Y, R, opt(tr, []));
% Residuals are orthogonal to the band-passed regressors
tc.verifyLessThan(max(abs(corr(E, seecat.denoise.bandpass(R, tr, [0.01 0.1]))), [], 'all'), 1e-8);
tc.verifyGreaterThan(min(diag(corr(E, s))), 0.9);
tc.verifyEqual(mean(E), zeros(1, 4), 'AbsTol', 1e-10);
end

function testCensoredSpikeDoesNotLeak(tc)
% The point of the censor flow: whatever the data hold on flagged frames,
% the residuals of good frames are the same.
rng(2);
tr = 2;
T = 150;
R = randn(T, 6);
Y = randn(T, 5) + R(:, 1:5);
bad = false(T, 1);
bad(70:73) = true;
spiked = Y;
spiked(bad, :) = spiked(bad, :) + 50;
Rspiked = R;
Rspiked(bad, 1) = 20;                     % a regressor spike too
E1 = seecat.denoise.clean(Y, R, opt(tr, bad));
E2 = seecat.denoise.clean(spiked, Rspiked, opt(tr, bad));
tc.verifyEqual(E2(~bad, :), E1(~bad, :), 'AbsTol', 1e-10);
% Without censoring the band-pass spreads the spike to other frames
E3 = seecat.denoise.clean(spiked, R, opt(tr, []));
E4 = seecat.denoise.clean(Y, R, opt(tr, []));
tc.verifyGreaterThan(max(abs(E3(60:69, :) - E4(60:69, :)), [], 'all'), 1);
end

function testCleanFailsWithTooFewGoodFrames(tc)
o = opt(2, [false(8, 1); true(32, 1)]);
o.band = [];
tc.verifyError(@() seecat.denoise.clean(randn(40, 2), randn(40, 10), o), 'SeeCAT:denoise');
% Enough frames to fit, but too few degrees of freedom left (30 - 22 = 8)
o = opt(2, [false(30, 1); true(30, 1)]);
o.band = [];
tc.verifyError(@() seecat.denoise.clean(randn(60, 2), randn(60, 20), o), 'SeeCAT:denoise');
o.bad = [false(40, 1); true(20, 1)];                  % 40 - 22 = 18: fine
tc.verifyWarningFree(@() seecat.denoise.clean(randn(60, 2), randn(60, 20), o));
end

function testSelectRegressors(tc)
rp = cumsum(randn(20, 6) * 0.01);
T = seecat.denoise.motion_regressors(rp);
tc.verifyEqual(width(T), 24);
T.white_matter = randn(20, 1);
T.csf = randn(20, 1);
T.c_comp_cor_00 = randn(20, 1);
T.w_comp_cor_00 = randn(20, 1);
[R, cols] = seecat.denoise.select_regressors(T, {'friston24', 'wm', 'csf', 'trans_x'});
tc.verifySize(R, [20 26]);
tc.verifyEqual(cols(25:26), {'white_matter', 'csf'});
tc.verifyFalse(any(isnan(R(:))));          % n/a first derivative -> 0
[~, cols] = seecat.denoise.select_regressors(T, {'acompcor'});
tc.verifyEqual(cols, {'c_comp_cor_00', 'w_comp_cor_00'});
tc.verifyError(@() seecat.denoise.select_regressors(T, {'gs'}), 'SeeCAT:denoise');
end

function testCompCorFindsSharedSignal(tc)
rng(3);
T = 120;
g = randn(T, 1);
Y = g * rand(1, 300) * 3 + randn(T, 300);
bad = false(T, 1);
bad(50) = true;
Y(50, :) = 1000;                          % a flagged frame cannot drive the components
C = seecat.denoise.compcor(Y, 5, 1, ~bad);
tc.verifySize(C, [T 5]);
tc.verifyGreaterThan(abs(corr(C(~bad, 1), g(~bad))), 0.95);
end

function testTsvRoundTrip(tc)
f = [tempname '.tsv'];
c = onCleanup(@() delete(f));
T = table([1; NaN; 3], {'a'; ''; 'c'}, 'VariableNames', {'trans_x_derivative1', 'name'});
seecat.io.write_tsv(T, f);
tc.verifySubstring(fileread(f), sprintf('n/a\tn/a'));
U = seecat.io.read_tsv(f);
tc.verifyEqual(U.Properties.VariableNames, T.Properties.VariableNames);
tc.verifyEqual(U.trans_x_derivative1, [1; NaN; 3]);
end

function o = opt(tr, bad)
o = struct('tr', tr, 'detrend_order', 1, 'band', [0.01 0.1], 'bad', bad, 'interp', 'spline');
end
