function tests = test_qc
% Tests for seecat.qc (per-run and group QC pages) on synthetic data.
%   results = runtests('tests/unit/test_qc.m')
tests = functiontests(localfunctions);
end

function setupOnce(~)
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..', '..', 'SeeCAT'));
spmDir = getenv('SEECAT_SPM');
if isempty(spmDir)
    spmDir = 'D:/verysync/dropbox/SciTools/MatlabToolbox/spm';
end
addpath(spmDir);
end

function testCarpetAndSlices(tc)
rng(1);
Y = randn(40, 300);
keep = true(40, 1);
keep(10:12) = false;
img = seecat.qc.carpet(Y, [ones(200, 1); 2 * ones(100, 1)], struct('rows', 60, 'width', 2, 'keep', keep));
tc.verifySize(img, [62 80 3]);                         % 60 rows + 2 separator rows; 2 px per frame
tc.verifyGreaterThan(mean(img(1:10, 21, 1)), mean(img(1:10, 21, 2)));   % frame 11: tinted red
tc.verifyEqual(img(1:10, 1, 1), img(1:10, 1, 2));      % kept frames stay grey
vol = zeros(10, 12, 8);
vol(2:9, 2:11, 2:7) = 1;
vol(2:4, 2:11, 2:7) = 2;                               % brighter at low x indices
hdr = struct('mat', [-3 0 0 15; 0 3 0 -18; 0 0 3 -12; 0 0 0 1], 'dim', size(vol));
rgb = seecat.qc.slices(vol, hdr, struct('mask', vol > 0, 'color', [1 0 0], 'style', 'edge', 'alpha', 1), ...
    struct('n', 2, 'scale', 1));
tc.verifyEqual(size(rgb, 3), 3);
% x flipped in the header (mat(1,1) < 0): low indices are on the right (world +x)
row = rgb(round(size(rgb, 1) / 6), 1:10, 2);
tc.verifyGreaterThan(mean(row(6:9)), mean(row(2:5)));
end

function testRunAndGroupReports(tc)
rng(2);
root = tempname;
c = onCleanup(@() rmdir(root, 's'));
work = fullfile(root, 'work');
out = fullfile(root, 'derivatives', 'seecat');
mkdir(work);
dim = [14 14 12];
nT = 60;
M = [-3 0 0 21; 0 3 0 -21; 0 0 3 -18; 0 0 0 1];
hdr = struct('mat', M, 'dim', dim);
mask = false(dim);
mask(3:12, 3:12, 3:10) = true;
spike = zeros(1, 1, 1, nT);
spike(30) = 40;
Y = 1000 + randn([dim nT]) * 5 + spike;
Y(repmat(~mask, 1, 1, 1, nT)) = 0;
seecat.io.write_nii(Y, hdr, fullfile(work, 'bold.nii'));
Yd = 1000 + randn([dim nT]) * 2;
Yd(repmat(~mask, 1, 1, 1, nT)) = 0;
seecat.io.write_nii(Yd, hdr, fullfile(work, 'denoised.nii'));
seecat.io.write_nii(uint8(mask), hdr, fullfile(work, 'mask.nii'), 'DataType', 'uint8');
T = table();
fd = abs(randn(nT, 1)) * 0.05;
fd(1) = NaN;
fd(30) = 1.5;
T.framewise_displacement = fd;
for n = {'trans_x', 'trans_y', 'trans_z', 'rot_x', 'rot_y', 'rot_z'}
    T.(n{1}) = cumsum(randn(nT, 1) * 0.01);
end
T.censor = zeros(nT, 1);
T.censor(29:32) = 1;
seecat.io.write_tsv(T, fullfile(work, 'confounds.tsv'));
R = struct('id', 'sub-01_task-rest', 'sub', '01', 'output_dir', out, 'work_dir', work, ...
    'manifest', fullfile(root, 'manifest.txt'), 'pipeline', 'prep', 'tr', 2, ...
    'bold', fullfile(work, 'bold.nii'), 'denoised', fullfile(work, 'denoised.nii'), ...
    'mask', fullfile(work, 'mask.nii'), 'confounds', fullfile(work, 'confounds.tsv'), ...
    'fd_threshold', 0.5, 'summary', struct('mean_fd', 0.3, 'max_fd', 1.5, 'n_flagged', 4, ...
    'n_frames', nT, 'minutes_kept', 1.9, 'low_data', true));
Mt = seecat.qc.run_report(R);
tc.verifyGreaterThan(Mt.fd_dvars_r_preproc, 0.5);       % the spike frame moves both
tc.verifyEqual(Mt.mean_fd, 0.3);
s = fullfile(out, 'sub-01');
for f = {'sub-01_task-rest_desc-qc_report.html', 'sub-01_task-rest_desc-qc_metrics.json', ...
        fullfile('figures', 'sub-01_task-rest_desc-carpet.png'), fullfile('figures', 'sub-01_task-rest_desc-registration.png')}
    tc.verifyTrue(exist(fullfile(s, f{1}), 'file') == 2, f{1});
end
html = fileread(fullfile(s, 'sub-01_task-rest_desc-qc_report.html'));
tc.verifySubstring(html, '<h2>Carpet plots</h2>');
tc.verifySubstring(html, 'Voxels of the brain mask');   % no tissue maps given
tc.verifySubstring(html, 'class="shade"');              % censored frames in the charts
tc.verifyNumElements(strsplit(strtrim(fileread(R.manifest)), newline), 4);   % 2 figures, page, metrics
G = seecat.qc.group_report(out, 'prep', table({'sub-02_task-rest'}, {'failed'}, {'boom'}, ...
    'VariableNames', {'unit', 'status', 'message'}));
tc.verifyEqual(G.flag, {'high FD, little data'});
g = fileread(fullfile(out, 'reports', 'prep_qc.html'));
tc.verifySubstring(g, 'href="../sub-01/sub-01_task-rest_desc-qc_report.html"');
tc.verifySubstring(g, 'sub-02_task-rest: boom');
tc.verifyTrue(exist(fullfile(out, 'reports', 'prep_qc.tsv'), 'file') == 2);
end
