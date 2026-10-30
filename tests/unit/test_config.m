function tests = test_config
% Unit tests for seecat.config / check_config / save_config.
%   results = runtests('tests/unit/test_config.m')
tests = functiontests(localfunctions);
end

function setupOnce(tc)
root = fullfile(fileparts(mfilename('fullpath')), '..', '..');
addpath(fullfile(root, 'SeeCAT'));
tc.TestData.tmp = tempname;
mkdir(tc.TestData.tmp);
end

function teardownOnce(tc)
rmdir(tc.TestData.tmp, 's');
end

function testDefaultsAreValid(tc)
cfg = seecat.config('prep');
cfg.bids_dir = tc.TestData.tmp;
seecat.check_config(cfg);
tc.verifyEqual(cfg.pipeline, 'prep');
tc.verifyEqual(cfg.censor.mode, 'censor');
tc.verifyEqual(cfg.normalise.voxel_size, 3);
tc.verifyFalse(ismember('gs', cfg.denoise.regressors));
end

function testAllProblemsReportedTogether(tc)
cfg = seecat.config('prep');                  % bids_dir left empty
cfg.denoise.regresors = {'gs'};               % typo
cfg.censor.mode = 'spike';
cfg.n_workers = -1;
cfg = rmfield(cfg, 'smooth');
msg = errorMessage(@() seecat.check_config(cfg));
tc.verifySubstring(msg, 'bids_dir must be');
tc.verifySubstring(msg, 'denoise.regresors is not a known option');
tc.verifySubstring(msg, 'censor.mode must be');
tc.verifySubstring(msg, 'n_workers must be');
tc.verifySubstring(msg, 'smooth.enable is missing');
end

function testJsonRoundTrip(tc)
cfg = seecat.config('prep');
cfg.bids_dir = tc.TestData.tmp;
cfg.subjects = {'10159'};                     % one-element list
cfg.denoise.band = [];
cfg.smooth.fwhm = [6 6 8];
f = fullfile(tc.TestData.tmp, 'sub', 'cfg.json');
seecat.save_config(cfg, f);
back = seecat.config(f);
tc.verifyEqual(back, cfg);
seecat.check_config(back);
end

function testPartialJsonTakesDefaults(tc)
f = fullfile(tc.TestData.tmp, 'partial.json');
fid = fopen(f, 'w');
fprintf(fid, '{"pipeline": "prep", "subjects": ["01", "02"], "censor": {"fd_threshold": 0.3}, "keep_work": 1}');
fclose(fid);
cfg = seecat.config(f);
def = seecat.config('prep');
tc.verifyEqual(cfg.subjects, {'01', '02'});
tc.verifyEqual(cfg.censor.fd_threshold, 0.3);
tc.verifyEqual(cfg.censor.before, def.censor.before);
tc.verifyEqual(cfg.keep_work, true);
tc.verifyEqual(cfg.normalise.bounding_box, def.normalise.bounding_box);
end

function testUnknownPipeline(tc)
tc.verifyError(@() seecat.config('dti'), 'SeeCAT:config');
tc.verifyError(@() seecat.config(struct('task', 'rest')), 'SeeCAT:config');
end

function msg = errorMessage(fn)
msg = '';
try
    fn();
catch err
    msg = err.message;
end
end
