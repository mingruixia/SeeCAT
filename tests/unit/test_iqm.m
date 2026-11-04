function tests = test_iqm
% IQMs against MRIQC 24.0.2's own functions on the same inputs (fixtures
% made by tests/validation/make_iqm_reference.py), and QC exclusions.
%   results = runtests('tests/unit/test_iqm.m')
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
tc.TestData.fx = fullfile(here, '..', 'fixtures', 'iqm');
end

function testAnatEqualsMriqc(tc)
d = tc.TestData.fx;
v = @(n, sz) reshape(readmatrix(fullfile(d, [n '.csv']), 'FileType', 'text'), sz);
sz = [24 24 24];
pv = {v('csf', sz), v('gm', sz), v('wm', sz)};
Q = seecat.qc.iqm_anat(v('t1', sz), v('inu', sz), pv, v('head', sz) > 0, v('air', sz) > 0, v('rot', sz) > 0, [1 1 1]);
R = jsondecode(fileread(fullfile(d, 'iqm_anat.json')));
compare(tc, Q, R);
end

function testBoldEqualsMriqc(tc)
d = tc.TestData.fx;
Y = reshape(readmatrix(fullfile(d, 'bold.csv'), 'FileType', 'text'), [14 14 8 40]);
m = reshape(readmatrix(fullfile(d, 'bold_mask.csv'), 'FileType', 'text'), [14 14 8]) > 0;
fd = readmatrix(fullfile(d, 'fd.csv'), 'FileType', 'text');
Q = seecat.qc.iqm_bold(Y, m, fd, [3 3 3], 0);
R = jsondecode(fileread(fullfile(d, 'iqm_bold.json')));
compare(tc, Q, R);
% the AFNI-style metrics behave: more outliers and worse quality with spikes
Y2 = Y;
Y2(:, :, :, 10) = Y2(:, :, :, 10) * 1.3;
Q2 = seecat.qc.iqm_bold(Y2, m, fd, [3 3 3], 0);
tc.verifyGreaterThan(Q2.aor, Q.aor);
tc.verifyGreaterThan(Q2.aqi, Q.aqi - 1e-12);
tc.verifyGreaterThan(Q.gcor, 0);
end

function testRunKeys(tc)
k = @(n) seecat.qc.exclusions('key', n);
tc.verifyEqual(k('sub-01_task-rest_space-IXI549Space_res-3_desc-PCC_stat-z_connectivity.nii.gz'), 'sub-01_task-rest');
tc.verifyEqual(k('sub-01_ses-2_task-rest_run-1_desc-denoised_bold.nii.gz'), 'sub-01_ses-2_task-rest_run-1');
tc.verifyEqual(k('sub-01_ses-2_task-rest_run-1'), 'sub-01_ses-2_task-rest_run-1');
tc.verifyEqual(k('sub-01_space-IXI549Space_res-1p5_label-GM_desc-modulatedSm8_probseg.nii.gz'), 'sub-01');
tc.verifyEqual(k('sub-01_T1w'), 'sub-01');
end

function testGroupReportRulesAndUserDecisions(tc)
root = tempname;
c = onCleanup(@() rmdir(root, 's'));
mkdir(root);
T = table({'sub-A1'; 'sub-A2'; 'sub-A3'; 'sub-B1'; 'sub-B2'}, {'A'; 'A'; 'A'; 'B'; 'B'}, ...
    'VariableNames', {'participant_id', 'site'});
seecat.io.write_tsv(T, fullfile(root, 'participants.tsv'));
m = struct('mean_fd', {0.1, 0.6, 0.1, 0.3, 0.1}, 'max_fd', 0.5, 'max_translation', {1, 1, 4, 1, 1}, ...
    'max_rotation', 1, 'low_data', 0, 'coverage', {0.98, 0.98, 0.98, 0.98, 0.8}, 'coverage_inferior', 0.9, ...
    'tsnr_median', 50, 'bold_tsnr', {60, 61, 59, 62, 10}, 't1_cnr', 3, 't1_file', ...
    {'sub-A1_T1w.nii', 'sub-A2_T1w.nii', 'sub-A3_T1w.nii', 'sub-B1_T1w.nii', 'sub-B2_T1w.nii'});
for i = 1:5
    d = fullfile(root, T.participant_id{i});
    mkdir(d);
    seecat.util.write_json(fullfile(d, [T.participant_id{i} '_task-rest_desc-qc_metrics.json']), m(i));
end
seecat.qc.group_report(root, 'prep', table());
X = seecat.qc.exclusion_list(root);
ex = @(id) X.exclude(strcmp(X.id, id));
tc.verifyEqual(ex('sub-A1_task-rest'), 0);
tc.verifyEqual(ex('sub-A2_task-rest'), 1);                 % mean FD 0.6
tc.verifyEqual(ex('sub-A3_task-rest'), 1);                 % translation 4 mm
tc.verifyEqual(ex('sub-B1_task-rest'), 0);                 % mean FD 0.3: a warning only
tc.verifyEqual(ex('sub-B2_task-rest'), 1);                 % coverage 0.8
tc.verifySubstring(X.warnings{strcmp(X.id, 'sub-B1_task-rest')}, 'mean FD > 0.25');
tc.verifyEqual(nnz(strcmp(X.kind, 'T1w')), 5);
tc.verifyEqual(X.site{strcmp(X.id, 'sub-B2_task-rest')}, 'B');
% the user keeps A2 and drops A1; a new report keeps both decisions
seecat.qc.exclusion_list(root, 'set', {'sub-A1_task-rest', 'sub-A2_task-rest'}, [true false], {'artefact', 'checked'});
seecat.qc.group_report(root, 'prep', table());
X = seecat.qc.exclusion_list(root);
tc.verifyEqual(X.exclude(strcmp(X.id, 'sub-A1_task-rest')), 1);
tc.verifyEqual(X.exclude(strcmp(X.id, 'sub-A2_task-rest')), 0);
tc.verifyEqual(X.decision{strcmp(X.id, 'sub-A1_task-rest')}, 'user');
tc.verifyEqual(X.note{strcmp(X.id, 'sub-A1_task-rest')}, 'artefact');
tc.verifyEqual(sort(seecat.qc.exclusions(root)), sort({'sub-A1_task-rest'; 'sub-A3_task-rest'; 'sub-B2_task-rest'}));
tc.verifyTrue(exist(fullfile(root, 'reports', 'prep_qc.html'), 'file') == 2);
end

function testLaterStepsLeaveExcludedRunsOut(tc)
root = tempname;
c = onCleanup(@() rmdir(root, 's'));
in = fullfile(root, 'derivatives', 'seecat');
M = [-3 0 0 9; 0 3 0 -9; 0 0 3 -9; 0 0 0 1];
for s = 1:4
    sub = sprintf('%02d', s);
    d = fullfile(in, ['sub-' sub], 'func');
    mkdir(d);
    stem = fullfile(d, ['sub-' sub '_task-rest']);
    seecat.io.write_nii(randn(6, 6, 6, 30), struct('dim', [6 6 6], 'mat', M), [stem '_space-IXI549Space_res-3_desc-denoised_bold.nii.gz']);
    seecat.io.write_nii(uint8(ones(6, 6, 6)), struct('dim', [6 6 6], 'mat', M), [stem '_space-IXI549Space_res-3_desc-brain_mask.nii.gz'], 'DataType', 'uint8');
    seecat.io.write_tsv(table(rand(30, 1), zeros(30, 1), 'VariableNames', {'framewise_displacement', 'censor'}), ...
        [stem '_desc-confounds_timeseries.tsv']);
    seecat.io.write_nii(randn(6, 6, 6) + 5, struct('dim', [6 6 6], 'mat', M), [stem '_space-IXI549Space_res-3_desc-A_stat-z_connectivity.nii.gz']);
end
mkdir(fullfile(in, 'reports'));
X = table({'sub-02_task-rest'; 'sub-03_task-rest'}, {'bold'; 'bold'}, [1; 0], {'mean FD > 0.5 mm'; ''}, {''; ''}, ...
    {'auto'; 'auto'}, {''; ''}, 'VariableNames', {'id', 'kind', 'exclude', 'reasons', 'warnings', 'decision', 'note'});
seecat.io.write_tsv(X, fullfile(in, 'reports', 'qc_exclusions.tsv'));
cfg = seecat.config('fc');
cfg.input_dir = in;
cfg.seeds = struct('name', 'S', 'center', [0 0 0], 'radius', 4);
[units, cfg2] = seecat.fc.plan(cfg);
tc.verifyEqual(numel(units), 3);
tc.verifyEqual(cfg2.qc_excluded, {'sub-02_task-rest'});
cfg.qc_exclusions = false;
tc.verifyEqual(numel(seecat.fc.plan(cfg)), 4);
P = table(strcat('sub-', {'01'; '02'; '03'; '04'}), {'a'; 'a'; 'b'; 'b'}, 'VariableNames', {'participant_id', 'site'});
seecat.io.write_tsv(P, fullfile(in, 'participants.tsv'));
[maps, dropped] = seecat.bids.select_maps(in, struct('desc', 'A', 'stat', 'z'), {}, '', {'site'});
tc.verifyEqual(height(maps), 3);
tc.verifySubstring(strjoin(dropped, ' '), 'sub-02_task-rest: excluded by QC');
s = seecat.config('stat');
s.name = 'x';
s.input_dir = in;
s.maps = struct('desc', 'A', 'stat', 'z');
s.mask = 'brain';
u = seecat.stat.plan(seecat.config(s));
tc.verifyEqual(height(u.maps), 3);
end

function compare(tc, Q, R)
for f = fieldnames(R)'
    k = f{1};
    tc.assertTrue(isfield(Q, k), ['missing ' k]);
    tol = 1e-6 * max(1, abs(R.(k)));
    if startsWith(k, 'dvars')
        tol = 1e-4 * max(1, abs(R.(k)));            % nipype computes in float32
    end
    tc.verifyEqual(Q.(k), R.(k), 'AbsTol', tol, k);
end
end
