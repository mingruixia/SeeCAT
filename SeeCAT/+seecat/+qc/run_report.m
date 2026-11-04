function M = run_report(R)
% RUN_REPORT  QC metrics, figures and an HTML page for one BOLD run.
%   M = seecat.qc.run_report(R)
%
% R fields (optional ones may be missing or empty):
%   id, sub        run stem (e.g. sub-01_task-rest) and subject label
%   output_dir, work_dir, manifest   where to write (seecat.util.publish_output)
%   pipeline       'prep' or 'fmriprep' (shown in the page)
%   tr             seconds
%   bold           preprocessed (normalised, not denoised) series
%   first_frame    frames before it are skipped (fMRIPrep non-steady-state)
%   denoised       denoised series (optional)
%   mask           brain mask
%   wm, csf        nuisance masks (optional; prep)
%   tissue         {GM, WM, CSF} probability maps on the BOLD grid (optional)
%   confounds      confounds TSV (FD, motion, censor)
%   summary        struct of extra summary values (e.g. qc from the run)
%   iqm            struct of MRIQC metrics (bold_*, t1_*; prep with qc.iqm)
% Writes sub-<sub>/figures/<id>_desc-{carpet,registration,tissue}.png,
% sub-<sub>/<id>_desc-qc_report.html and <id>_desc-qc_metrics.json. M are
% the metrics: tSNR, DVARS and FD-DVARS correlations before/after
% denoising, largest translation (mm) and rotation (degrees), coverage
% (share of the template brain inside the field of view, also for its top,
% z > 50 mm, and bottom, z < -30 mm: cerebellum and temporal poles), plus
% R.summary; the JSON also holds R.iqm.

pub = struct('output_dir', R.output_dir, 'work_dir', R.work_dir, 'manifest', R.manifest);
fig = fullfile(R.work_dir, 'qcfig');
if ~exist(fig, 'dir')
    mkdir(fig);
end
rel = ['sub-' R.sub];
first = 1;
if isfield(R, 'first_frame') && ~isempty(R.first_frame)
    first = R.first_frame;
end
T = seecat.io.read_tsv(R.confounds);
[Y, V] = seecat.io.read_nii(R.bold, 'Class', 'single');
Y = Y(:, :, :, first:end);
hdr = V(1);
valid = all(Y ~= 0 & isfinite(Y), 4);              % inside the field of view in every frame
mask = logical(seecat.io.read_nii(R.mask, 'Ref', hdr)) & valid;
cov = coverage(valid, hdr);
meanImg = mean(Y, 4);
Y = reshape(Y, [], size(Y, 4))';
Yp = double(Y(:, mask(:)));
clear Y
nT = size(Yp, 1);
fd = T.framewise_displacement;
censor = zeros(nT, 1);
if ismember('censor', T.Properties.VariableNames)
    censor = T.censor;
end

M = struct();
mot = {'trans_x', 'trans_y', 'trans_z', 'rot_x', 'rot_y', 'rot_z'};
if all(ismember(mot, T.Properties.VariableNames))
    M.max_translation = max(abs(T{first:end, mot(1:3)}), [], 'all');
    M.max_rotation = max(abs(T{first:end, mot(4:6)}), [], 'all') * 180 / pi;
end
M.coverage = cov.total;
M.coverage_superior = cov.superior;
M.coverage_inferior = cov.inferior;
mu = mean(Yp, 1);
M.tsnr_median = median(mu ./ std(Yp, 0, 1));
dv = dvars(Yp);
M.fd_dvars_r_preproc = corrOk(fd(2:end), dv(2:end));
M.dvars_median_preproc = median(dv(2:end), 'omitnan');
groups = ones(nnz(mask), 1);
if isfield(R, 'tissue') && ~isempty(R.tissue)
    P = zeros(nnz(mask), 3);
    for k = 1:3
        p = seecat.io.read_nii(R.tissue{k}, 'Ref', hdr, 'Interp', 1);
        P(:, k) = p(mask);
    end
    [~, groups] = max(P, [], 2);
end
imgs = {carpetRows(Yp, groups, censor == 0)};
captions = {'before denoising'};
dvd = nan(nT, 1);
if isfield(R, 'denoised') && ~isempty(R.denoised)
    Yd = seecat.io.read_nii(R.denoised, 'Class', 'single');
    Yd = reshape(Yd, [], size(Yd, 4))';
    Yd = double(Yd(:, mask(:)));
    dvd = dvars(Yd);
    kept = censor == 0;
    kept(1) = false;
    M.fd_dvars_r_denoised = corrOk(fd(kept), dvd(kept));       % censored frames excluded
    M.dvars_median_denoised = median(dvd(2:end), 'omitnan');
    imgs{end+1} = carpetRows(Yd, groups, censor == 0);
    captions{end+1} = 'after denoising';
    clear Yd
end
carpetFile = fullfile(fig, [R.id '_desc-carpet.png']);
imwrite(cat(1, imgs{:}), carpetFile);

gm = templateGM(hdr);
ov = struct('mask', {gm, mask}, 'color', {[1 0.25 0.25], [1 0.85 0.2]}, 'style', 'edge', 'alpha', 1);
regFile = fullfile(fig, [R.id '_desc-registration.png']);
imwrite(seecat.qc.slices(meanImg, hdr, ov), regFile);
files = {carpetFile, regFile};
tissueFile = '';
if isfield(R, 'wm') && ~isempty(R.wm)
    wm = seecat.io.read_nii(R.wm, 'Ref', hdr) > 0;
    csf = seecat.io.read_nii(R.csf, 'Ref', hdr) > 0;
    ov = struct('mask', {wm, csf}, 'color', {[0.2 0.5 1], [0.1 0.9 0.5]}, 'style', 'fill', 'alpha', 0.6);
    tissueFile = fullfile(fig, [R.id '_desc-tissue.png']);
    imwrite(seecat.qc.slices(meanImg, hdr, ov), tissueFile);
    files{end+1} = tissueFile;
    M.wm_voxels = nnz(wm & mask);
    M.csf_voxels = nnz(csf & mask);
end
for f = files
    [~, n, e] = fileparts(f{1});
    seecat.util.publish_output(f{1}, fullfile(rel, 'figures', [n e]), [], pub);
end
if isfield(R, 'summary')
    S = R.summary;
    for f = fieldnames(M)'
        S.(f{1}) = M.(f{1});
    end
    M = S;                                     % run metrics first, then QC metrics
end

% ---- page ----
t = (0:nT - 1) * R.tr;
fdp = svg(t, fd', struct('ylabel', 'FD (mm)', 'hline', thresholdOf(R), 'shade', censor' > 0, 'names', {{'FD'}}));
mot = {'trans_x', 'trans_y', 'trans_z', 'rot_x', 'rot_y', 'rot_z'};
mot(~ismember(mot, T.Properties.VariableNames)) = {''};
tr = svg(t, cols(T, mot(1:3)), struct('ylabel', 'mm', 'names', {{'trans x', 'trans y', 'trans z'}}));
rt = svg(t, cols(T, mot(4:6)) * 180 / pi, struct('ylabel', 'degrees', 'names', {{'rot x', 'rot y', 'rot z'}}));
dvp = svg(t, [dv'; dvd'], struct('ylabel', 'DVARS (%)', 'shade', censor' > 0, 'names', {{'before denoising', 'after denoising'}}));
html = page(R, M, fdp, tr, rt, dvp, [R.id '_desc-carpet.png'], captions, [R.id '_desc-registration.png'], tissueFile, cov);
h = fullfile(R.work_dir, [R.id '_desc-qc_report.html']);
fid = fopen(h, 'w', 'n', 'UTF-8');
fwrite(fid, html, 'char');
fclose(fid);
seecat.util.publish_output(h, fullfile(rel, [R.id '_desc-qc_report.html']), [], pub);
j = fullfile(R.work_dir, [R.id '_desc-qc_metrics.json']);
J = M;
if isfield(R, 'iqm') && ~isempty(R.iqm)
    for f = fieldnames(R.iqm)'
        J.(f{1}) = R.iqm.(f{1});
    end
end
seecat.util.write_json(j, J);
seecat.util.publish_output(j, fullfile(rel, [R.id '_desc-qc_metrics.json']), [], pub);
end

function d = dvars(Y)
% RMS over voxels of the frame-to-frame change, in percent of the median
% voxel mean (one scale for the whole brain, so edge voxels with small
% means do not dominate)
s = median(mean(Y, 1));
d = [NaN; sqrt(mean(diff(Y, 1, 1) .^ 2, 2)) / max(abs(s), eps) * 100];
end

function r = corrOk(a, b)
ok = isfinite(a) & isfinite(b);
r = NaN;
if nnz(ok) > 3
    c = corrcoef(a(ok), b(ok));
    r = c(1, 2);
end
end

function img = carpetRows(Y, groups, keep)
img = seecat.qc.carpet(Y, groups, struct('rows', 400, 'width', max(1, round(900 / size(Y, 1))), 'keep', keep));
img(end+1:end+6, :, :) = 1;                   % white gap between the two plots
end

function m = templateGM(hdr)
vox = mean(sqrt(sum(hdr.mat(1:3, 1:3) .^ 2)));
res = 3;
if abs(vox - 2) < abs(vox - 3)
    res = 2;
end
here = fileparts(fileparts(fileparts(mfilename('fullpath'))));
m = seecat.io.read_nii(fullfile(here, 'templates', sprintf('tpl-IXI549Space_res-%d_label-GM_mask.nii', res)), ...
    'Ref', hdr, 'Interp', 0) > 0;
end

function u = thresholdOf(R)
u = [];
if isfield(R, 'fd_threshold')
    u = R.fd_threshold;
end
end

function Y = cols(T, names)
Y = nan(numel(names), height(T));
for k = 1:numel(names)
    if ~isempty(names{k})
        Y(k, :) = T.(names{k})';
    end
end
end

function s = svg(t, Y, o)
s = seecat.qc.svg_lines(t, Y, o);
end

function c = coverage(valid, hdr)
% Share of the template brain mask inside the field of view
vox = mean(sqrt(sum(hdr.mat(1:3, 1:3) .^ 2)));
res = 3;
if abs(vox - 2) < abs(vox - 3)
    res = 2;
end
here = fileparts(fileparts(fileparts(mfilename('fullpath'))));
b = seecat.io.read_nii(fullfile(here, 'templates', sprintf('tpl-IXI549Space_res-%d_desc-brain_mask.nii', res)), ...
    'Ref', hdr, 'Interp', 0) > 0;
[i, j, k] = ndgrid(1:hdr.dim(1), 1:hdr.dim(2), 1:hdr.dim(3));
z = reshape(hdr.mat(3, :) * [i(:) j(:) k(:) ones(numel(i), 1)]', hdr.dim);
share = @(m) nnz(valid & m) / max(nnz(m), 1);
c.total = share(b);
c.superior = share(b & z > 50);
c.inferior = share(b & z < -30);
end

function html = page(R, M, fdp, tr, rt, dvp, carpet, captions, reg, tissue, cov)
rows = '';
for f = fieldnames(M)'
    v = M.(f{1});
    if islogical(v), v = double(v); end
    if isnumeric(v) && isscalar(v)
        txt = sprintf('%.4g', v);
    else
        txt = char(string(v));
    end
    rows = [rows sprintf('<tr><th>%s</th><td>%s</td></tr>', label(f{1}), txt)]; %#ok<AGROW>
end
tissueHtml = '';
if ~isempty(tissue)
    [~, n, e] = fileparts(tissue);
    tissueHtml = sprintf(['<h2>Nuisance masks</h2><p class="note">WM (blue) and CSF (green) masks used ' ...
        'for the tissue signals and aCompCor, on the mean BOLD.</p><img src="figures/%s%s" alt="WM and CSF masks">'], n, e);
end
order = 'Voxels of the brain mask';
if isfield(R, 'tissue') && ~isempty(R.tissue)
    order = 'Voxels ordered GM, WM, CSF';
end
css = ['<style>:root{--bg:#fff;--fg:#1d2433;--mute:#5d6678;--line:#d9dde5;--shade:#f2c4c4;--ref:#c0392b}' ...
    '@media (prefers-color-scheme:dark){:root{--bg:#14171f;--fg:#e4e7ee;--mute:#9aa3b5;--line:#343a48;--shade:#5a2a2a;--ref:#ff7b6b}}' ...
    'body{background:var(--bg);color:var(--fg);font:15px/1.5 system-ui,sans-serif;max-width:960px;margin:24px auto;padding:0 16px}' ...
    'h1{font-size:22px}h2{font-size:17px;margin-top:28px;border-bottom:1px solid var(--line)}' ...
    'table{border-collapse:collapse}th,td{padding:2px 12px 2px 0;text-align:left}th{color:var(--mute);font-weight:500}' ...
    'img{max-width:100%;image-rendering:pixelated;border:1px solid var(--line)}.note{color:var(--mute);font-size:13px}' ...
    '.chart .axis{stroke:var(--mute)}.chart .tick,.chart .label{fill:var(--mute);font-size:11px}' ...
    '.chart .legend{font-size:11px}.chart .shade{fill:var(--shade)}.chart .ref{stroke:var(--ref);stroke-dasharray:4 3}</style>'];
html = ['<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">' ...
    '<title>' R.id ' QC</title>' css '</head><body>' ...
    '<h1>' R.id '</h1><p class="note">SeeCAT ' seecat.version() ', ' R.pipeline ' pipeline. Shaded frames are censored.</p>' ...
    '<h2>Summary</h2><table>' rows '</table>' ...
    '<h2>Head motion</h2>' fdp tr rt ...
    '<h2>DVARS</h2><p class="note">Root mean square over voxels of the frame-to-frame change (% of the median voxel mean), ' ...
    'before and after denoising.</p>' dvp ...
    '<h2>Carpet plots</h2><p class="note">' order ' (Power 2017); ' strjoin(captions, ', then ') ...
    '. Each voxel detrended and z-scored on the kept frames; censored frames tinted red.</p><img src="figures/' carpet '" alt="carpet plots">' ...
    '<h2>Registration and coverage</h2><p class="note">Mean normalised BOLD; red: template GM outline, yellow: brain mask. ' ...
    'Rows: axial, coronal, sagittal; left on the left. ' ...
    sprintf('The field of view holds %.0f%% of the template brain (top, z &gt; 50 mm: %.0f%%; bottom, z &lt; -30 mm, cerebellum and temporal poles: %.0f%%).', ...
    100 * cov.total, 100 * cov.superior, 100 * cov.inferior) '</p><img src="figures/' reg '" alt="registration">' ...
    tissueHtml iqmHtml(R) '</body></html>'];
end

function t = label(k)
L = struct('dummy_scans', 'non-steady-state volumes dropped', 'n_frames', 'frames', ...
    'mean_fd', 'mean FD (mm)', 'max_fd', 'max FD (mm)', 'n_flagged', 'flagged frames', ...
    'minutes_kept', 'minutes kept', 'low_data', 'too little data (1 = yes)', ...
    'normalise_method', 'normalisation', 'tsnr_median', 'tSNR (median)', ...
    'fd_dvars_r_preproc', 'r(FD, DVARS) before denoising', 'dvars_median_preproc', 'DVARS median before (%)', ...
    'fd_dvars_r_denoised', 'r(FD, DVARS) after denoising (kept frames)', 'dvars_median_denoised', 'DVARS median after (%)', ...
    'wm_voxels', 'WM mask voxels', 'csf_voxels', 'CSF mask voxels', ...
    'max_translation', 'largest translation (mm)', 'max_rotation', 'largest rotation (degrees)', ...
    'coverage', 'template brain in the field of view', 'coverage_superior', '... its top (z > 50 mm)', ...
    'coverage_inferior', '... its bottom (z < -30 mm)');
if isfield(L, k)
    t = L.(k);
else
    t = strrep(k, '_', ' ');
end
end

function h = iqmHtml(R)
% The MRIQC metrics, BOLD then T1w, with a short meaning of the main ones
h = '';
if ~isfield(R, 'iqm') || isempty(R.iqm) || isempty(fieldnames(R.iqm))
    return
end
Q = R.iqm;
tip = struct('bold_tsnr', 'temporal SNR, higher is better', 'bold_snr', 'SNR of the mean EPI, higher is better', ...
    'bold_fber', 'foreground to background energy, higher is better', 'bold_efc', 'entropy focus (ghosting, blurring), lower is better', ...
    'bold_gsr_x', 'ghost to signal along x, lower is better', 'bold_gsr_y', 'ghost to signal along y (usual phase encoding), lower is better', ...
    'bold_dvars_std', 'standardised DVARS, near 1 is good', 'bold_aor', 'share of outlier voxels per volume (AFNI), lower is better', ...
    'bold_aqi', 'AFNI quality index, lower is better', 'bold_gcor', 'global correlation, lower is better', ...
    'bold_fd_mean', 'mean FD (mm)', 'bold_fd_perc', '% of frames with FD > 0.2 mm', 'bold_fwhm_avg', 'smoothness (voxels)', ...
    't1_cnr', 'GM-WM contrast to noise, higher is better', 't1_cjv', 'coefficient of joint variation of GM and WM, lower is better', ...
    't1_snr_total', 'SNR in the tissues, higher is better', 't1_snrd_total', 'Dietrich SNR (noise from air), higher is better', ...
    't1_efc', 'entropy focus (motion, ghosting), lower is better', 't1_fber', 'foreground to background energy, higher is better', ...
    't1_inu_range', 'spread of the bias field, lower is better', 't1_wm2max', 'WM median over the 99.95th percentile; about 0.6-0.8 is typical', ...
    't1_tiv_ml', 'total intracranial volume (GM + WM + CSF, mL)');
rows = '';
for f = fieldnames(Q)'
    k = f{1};
    if startsWith(k, {'bold_summary', 't1_summary'}), continue, end
    v = Q.(k);
    if isnumeric(v) && isscalar(v)
        txt = sprintf('%.4g', v);
    else
        txt = char(string(v));
    end
    note = '';
    if isfield(tip, k), note = tip.(k); end
    rows = [rows sprintf('<tr><th>%s</th><td>%s</td><td class="note">%s</td></tr>', k, txt, note)]; %#ok<AGROW>
end
h = ['<h2>Image quality metrics (MRIQC)</h2><p class="note">Computed on the raw data as MRIQC defines them ' ...
    '(bold_*: the run after dummy scans, head-motion corrected; t1_*: the T1w). Compare a run with the ' ...
    'others of its site in the group report: the values depend on the scanner and protocol.</p><table>' rows '</table>'];
end

