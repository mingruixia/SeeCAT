function T = group_report(output_dir, pipeline, summary, qc)
% GROUP_REPORT  Group QC page, a table of every run, and the exclusion list.
%   T = seecat.qc.group_report(output_dir, 'prep', summary, cfg.qc)
%
% Reads every sub-*/*_desc-qc_metrics.json under OUTPUT_DIR (written by
% seecat.qc.run_report) and writes, in OUTPUT_DIR/reports:
%   <pipeline>_qc.tsv    one row per run: motion, coverage, tSNR, IQMs, site
%   <pipeline>_qc.html   the table, the IQM distributions, the suggestions
%   qc_exclusions.tsv    one row per BOLD run (and per T1w with IQMs):
%                        id, kind, exclude (1/0), reasons, warnings,
%                        decision ('auto' or 'user'), note
% Exclusion is suggested (exclude = 1, decision auto) when a run breaks a
% rule of QC (seecat.util.qc_defaults): largest translation or rotation,
% mean FD, too little data after censoring, coverage of the template
% brain below the minimum, or a brain-mask Dice with the template below
% QC.min_brain_dice (failed normalisation). Warnings, which do not exclude: mean FD above
% 0.25 mm (Parkes et al. 2018, lenient), coverage of the bottom of the brain
% below 80 %, a registration measure (seecat.qc.registration) that is an
% outlier, and IQMs whose robust z (median, MAD) within the run's site
% (participants.tsv column "site", with at least 5 runs there; otherwise
% the whole dataset) is beyond QC.iqm_z in the bad direction. T1w rows
% carry only warnings. Rows whose decision is 'user' (changed on the QC
% reports page) keep their exclude value and note when the list is made
% again. Seed FC, Degree, Gradients, Harmonize and Statistics leave out
% what is excluded (see seecat.qc.exclusions).

if nargin < 4 || isempty(qc)
    qc = seecat.util.qc_defaults(struct(), false);
    qc = qc.qc;
end
F = dir(fullfile(output_dir, 'sub-*', '*_desc-qc_metrics.json'));
ids = regexprep({F.name}', '_desc-qc_metrics\.json$', '');
J = cell(numel(F), 1);
for i = 1:numel(F)
    J{i} = jsondecode(fileread(fullfile(F(i).folder, F(i).name)));
end
T = table(ids, 'VariableNames', {'run'});
T.site = siteOf(output_dir, ids);
names = {};
for i = 1:numel(J)
    names = union(names, fieldnames(J{i}), 'stable');
end
for c = names(:)'
    if strcmp(c{1}, 't1_file')
        continue
    end
    v = nan(height(T), 1);
    for i = 1:numel(J)
        if isfield(J{i}, c{1}) && isnumeric(J{i}.(c{1})) && isscalar(J{i}.(c{1}))
            v(i) = double(J{i}.(c{1}));
        elseif isfield(J{i}, c{1}) && islogical(J{i}.(c{1}))
            v(i) = double(J{i}.(c{1}));
        end
    end
    if any(isfinite(v)) || ismember(c{1}, {'mean_fd', 'max_fd', 'tsnr_median'})
        T.(c{1}) = v;
    end
end
T.t1_file = repmat({''}, height(T), 1);
for i = 1:numel(J)
    if isfield(J{i}, 't1_file'), T.t1_file{i} = J{i}.t1_file; end
end

% ---- rules, warnings
reasons = repmat({{}}, height(T), 1);
warns = repmat({{}}, height(T), 1);
rule = @(col, bad, txt) addIf(T, col, bad, txt);
[reasons, ~] = apply(reasons, rule('max_translation', @(x) x > qc.max_translation, ...
    sprintf('translation > %g mm', qc.max_translation)));
[reasons, ~] = apply(reasons, rule('max_rotation', @(x) x > qc.max_rotation, ...
    sprintf('rotation > %g deg', qc.max_rotation)));
[reasons, ~] = apply(reasons, rule('mean_fd', @(x) x > qc.max_mean_fd, sprintf('mean FD > %g mm', qc.max_mean_fd)));
[reasons, ~] = apply(reasons, rule('low_data', @(x) x == 1, 'too little data after censoring'));
[reasons, ~] = apply(reasons, rule('coverage', @(x) x < qc.min_coverage, ...
    sprintf('coverage < %.0f%%', 100 * qc.min_coverage)));
[warns, ~] = apply(warns, rule('mean_fd', @(x) x > 0.25 & x <= qc.max_mean_fd, 'mean FD > 0.25 mm'));
[warns, ~] = apply(warns, rule('coverage_inferior', @(x) x < 0.8, 'bottom of the brain cut (< 80%)'));
boldIqm = {'bold_tsnr', -1; 'bold_snr', -1; 'bold_fber', -1; 'bold_efc', 1; 'bold_gsr_x', 1; 'bold_gsr_y', 1; ...
    'bold_dvars_std', 1; 'bold_aor', 1; 'bold_aqi', 1; 'bold_gcor', 1};
z = robustZ(T, boldIqm, qc.iqm_z);
for k = 1:size(boldIqm, 1)
    hit = z(:, k);
    for i = find(hit)'
        warns{i}{end+1} = sprintf('%s outlier', strrep(boldIqm{k, 1}, 'bold_', ''));
    end
end

regIqm = {'reg_brain_dice', -1; 'reg_gm_corr', -1; 'reg_epi_t1_dice', -1};
zr = robustZ(T, regIqm, qc.iqm_z);
for k = 1:size(regIqm, 1)
    for i = find(zr(:, k))'
        warns{i}{end+1} = sprintf('registration: %s outlier', strrep(regIqm{k, 1}, 'reg_', ''));
    end
end
if ismember('reg_brain_dice', T.Properties.VariableNames)
    [reasons, ~] = apply(reasons, rule('reg_brain_dice', @(x) x < qc.min_brain_dice, ...
        sprintf('brain Dice with template < %.2f (failed normalisation)', qc.min_brain_dice)));
end

% T1w rows: one per T1w file, IQMs from its first run
t1Iqm = {'t1_cnr', -1; 't1_cjv', 1; 't1_snr_total', -1; 't1_snrd_total', -1; 't1_efc', 1; 't1_fber', -1; ...
    't1_inu_range', 1};
[t1s, first] = unique(T.t1_file, 'stable');
keep = ~cellfun(@isempty, t1s);
t1s = t1s(keep);
first = first(keep);
A = T(first, :);
t1warn = repmat({{}}, numel(t1s), 1);
quantized = 0;
if ~isempty(t1s) && ismember('t1_cnr', T.Properties.VariableNames)
    % FBER and Dietrich SNR rest on the background air; when its MAD is <= 1
    % (MRIQC's own limit) the air holds a few integer levels (clipped or
    % quantised on export) and these two are not comparable, so they do not
    % count as outliers
    B = A;
    if ismember('t1_summary_bg_mad', B.Properties.VariableNames)
        q = B.t1_summary_bg_mad <= 1;
        quantized = nnz(q);
        for c = {'t1_fber', 't1_snrd_total'}
            if ismember(c{1}, B.Properties.VariableNames)
                B.(c{1})(q) = NaN;
            end
        end
    end
    zA = robustZ(B, t1Iqm, qc.iqm_z);
    for k = 1:size(t1Iqm, 1)
        for i = find(zA(:, k))'
            t1warn{i}{end+1} = sprintf('%s outlier', strrep(t1Iqm{k, 1}, 't1_', ''));
        end
    end
end
T.exclude_suggested = cellfun(@(r) ~isempty(r), reasons);
T.reasons = cellfun(@(r) strjoin(r, '; '), reasons, 'UniformOutput', false);
T.warnings = cellfun(@(r) strjoin(r, '; '), warns, 'UniformOutput', false);

d = fullfile(output_dir, 'reports');
if ~exist(d, 'dir')
    mkdir(d);
end
seecat.io.write_tsv(T, fullfile(d, [pipeline '_qc.tsv']));

% ---- exclusion list (user decisions kept)
X = table([T.run; regexprep(t1s, '\.nii(\.gz)?$', '')], ...
    [repmat({'bold'}, height(T), 1); repmat({'T1w'}, numel(t1s), 1)], ...
    [double(T.exclude_suggested); zeros(numel(t1s), 1)], ...
    [T.reasons; repmat({''}, numel(t1s), 1)], ...
    [T.warnings; cellfun(@(r) strjoin(r, '; '), t1warn, 'UniformOutput', false)], ...
    repmat({'auto'}, height(T) + numel(t1s), 1), repmat({''}, height(T) + numel(t1s), 1), ...
    'VariableNames', {'id', 'kind', 'exclude', 'reasons', 'warnings', 'decision', 'note'});
xf = fullfile(d, 'qc_exclusions.tsv');
if exist(xf, 'file')
    old = seecat.io.read_tsv(xf);
    if all(ismember({'id', 'exclude', 'decision', 'note'}, old.Properties.VariableNames))
        old.note = cellstr(string(old.note));
        old.note(strcmp(old.note, 'n/a')) = {''};
        for i = find(strcmp(cellstr(string(old.decision)), 'user'))'
            k = find(strcmp(X.id, old.id{i}), 1);
            if ~isempty(k)
                X.exclude(k) = old.exclude(i);
                X.decision{k} = 'user';
                X.note{k} = old.note{i};
            end
        end
    end
end
seecat.io.write_tsv(X, xf);

% ---- page
failed = {};
if nargin > 2 && ~isempty(summary) && ismember('status', summary.Properties.VariableNames)
    k = strcmp(summary.status, 'failed');
    failed = strcat(summary.unit(k), {': '}, summary.message(k));   % {': '} keeps the space
end
html = page(T, X, A, t1s, [regIqm; boldIqm], t1Iqm, failed, pipeline, qc, quantized);
fid = fopen(fullfile(d, [pipeline '_qc.html']), 'w', 'n', 'UTF-8');
fwrite(fid, html, 'char');
fclose(fid);
end

function site = siteOf(output_dir, ids)
site = repmat({''}, numel(ids), 1);
f = seecat.bids.participants_file(output_dir);
if isempty(f), return, end
try
    P = seecat.io.read_tsv(f);
catch
    return
end
if ~ismember('site', P.Properties.VariableNames), return, end
sub = regexp(ids, '^sub-[a-zA-Z0-9]+', 'match', 'once');
[in, row] = ismember(sub, P.participant_id);
s = cellstr(string(P.site));
site(in) = s(row(in));
end

function out = addIf(T, col, bad, txt)
out = struct('hit', false(height(T), 1), 'txt', txt);
if ismember(col, T.Properties.VariableNames)
    v = T.(col);
    out.hit = bad(v) & isfinite(v);
end
end

function [list, hit] = apply(list, r)
hit = r.hit;
for i = find(hit)'
    list{i}{end+1} = r.txt;
end
end

function Z = robustZ(T, iqm, lim)
% Outliers in the bad direction, within site when the site has >= 5 runs
Z = false(height(T), size(iqm, 1));
site = T.site;
groups = unique(site);
for k = 1:size(iqm, 1)
    c = iqm{k, 1};
    if ~ismember(c, T.Properties.VariableNames), continue, end
    v = T.(c);
    for g = groups(:)'
        in = strcmp(site, g{1});
        if nnz(in) < 5
            in = true(height(T), 1);
        end
        x = v(in);
        mdn = median(x, 'omitnan');
        mad = 1.4826 * median(abs(x - mdn), 'omitnan');
        if ~(mad > 0), continue, end
        zz = iqm{k, 2} * (v - mdn) / mad;
        here = strcmp(site, g{1});
        Z(here, k) = Z(here, k) | (zz(here) > lim);
    end
end
end

function html = page(T, X, A, t1s, boldIqm, t1Iqm, failed, pipeline, qc, quantized)
num = @(c, i, f) fmt(T, c, i, f);
rows = '';
for i = 1:height(T)
    sub = regexp(T.run{i}, '^sub-[a-zA-Z0-9]+', 'match', 'once');
    k = find(strcmp(X.id, T.run{i}), 1);
    ex = X.exclude(k) == 1;
    cls = '';
    if ex
        cls = ' class="excl"';
    elseif ~isempty(T.warnings{i})
        cls = ' class="warn"';
    end
    decision = 'keep';
    if ex, decision = 'EXCLUDE'; end
    if strcmp(X.decision{k}, 'user'), decision = [decision ' (by user)']; end
    rows = [rows sprintf(['<tr%s><td><a href="../%s/%s_desc-qc_report.html">%s</a></td><td>%s</td>' ...
        '<td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td><b>%s</b> %s</td><td>%s</td></tr>'], ...
        cls, sub, T.run{i}, T.run{i}, T.site{i}, num('mean_fd', i, '%.3f'), num('max_translation', i, '%.2f'), ...
        num('max_rotation', i, '%.2f'), num('coverage', i, '%.2f'), num('reg_brain_dice', i, '%.3f'), ...
        num('reg_gm_corr', i, '%.3f'), num('minutes_kept', i, '%.1f'), ...
        num('tsnr_median', i, '%.1f'), num('fd_dvars_r_denoised', i, '%.2f'), decision, T.reasons{i}, T.warnings{i})]; %#ok<AGROW>
end
fails = '';
if ~isempty(failed)
    fails = ['<h2>Failed</h2><ul><li>' strjoin(failed, '</li><li>') '</li></ul>'];
end
plots = '';
if height(T) > 1
    plots = seecat.qc.svg_lines(1:height(T), sort(T.mean_fd)', struct('ylabel', 'mean FD (mm)', ...
        'hline', 0.25, 'height', 140, 'names', {{'runs, sorted by mean FD'}}));
end
iqmPlots = '';
for k = 1:size(boldIqm, 1)
    c = boldIqm{k, 1};
    if ismember(c, T.Properties.VariableNames)
        iqmPlots = [iqmPlots strip(T.(c), T.site, T.run, c, boldIqm{k, 2}, qc.iqm_z)]; %#ok<AGROW>
    end
end
t1Plots = '';
if ~isempty(t1s)
    for k = 1:size(t1Iqm, 1)
        c = t1Iqm{k, 1};
        if ismember(c, A.Properties.VariableNames)
            t1Plots = [t1Plots strip(A.(c), A.site, t1s, c, t1Iqm{k, 2}, qc.iqm_z)]; %#ok<AGROW>
        end
    end
    qnote = '';
    if quantized > 0
        qnote = sprintf([' %d of %d T1w images have an almost empty background (air MAD &le; 1, e.g. clipped ' ...
            'or quantised on export): their fber and snrd are not comparable and are not used for warnings.'], ...
            quantized, numel(t1s));
    end
    t1Plots = ['<h2>T1w quality (MRIQC IQMs)</h2><p class="note">One dot per T1w image; red: beyond the ' ...
        'warning limit within its site. Arrows show the good direction.' qnote '</p><div class="grid">' t1Plots '</div>'];
end
if ~isempty(iqmPlots)
    iqmPlots = ['<h2>Registration and BOLD quality</h2><p class="note">reg_*: registration measures ' ...
        '(brain mask Dice with the template, normalised GM vs SPM''s TPM, Dice of the EPI''s own brain with the ' ...
        'T1w brain); the others are MRIQC IQMs. One dot per run, coloured by site; red ' ...
        'outline: robust z beyond ' sprintf('%g', qc.iqm_z) ' within its site in the bad direction (a warning, ' ...
        'not an exclusion). Hover a dot for the run.</p><div class="grid">' iqmPlots '</div>'];
end
rules = sprintf(['Suggested for exclusion when: largest translation &gt; %g mm, largest rotation &gt; %g&deg;, ' ...
    'mean FD &gt; %g mm, too little data after censoring, less than %.0f%% of the template brain in the field ' ...
    'of view, or a brain mask Dice with the template below %.2f. Change any decision on the QC reports page of SeeCAT; later steps (Seed FC, Degree, Gradients, ' ...
    'Harmonize, Statistics) leave excluded runs out.'], qc.max_translation, qc.max_rotation, qc.max_mean_fd, ...
    100 * qc.min_coverage, qc.min_brain_dice);
nEx = nnz(X.exclude == 1 & strcmp(X.kind, 'bold'));
css = ['<style>:root{--bg:#fff;--fg:#1d2433;--mute:#5d6678;--line:#d9dde5;--warn:#fff4dc;--excl:#fdecea;--ref:#c0392b;--shade:#f2c4c4}' ...
    '@media (prefers-color-scheme:dark){:root{--bg:#14171f;--fg:#e4e7ee;--mute:#9aa3b5;--line:#343a48;--warn:#43381d;--excl:#4a2323;--ref:#ff7b6b;--shade:#5a2a2a}}' ...
    'body{background:var(--bg);color:var(--fg);font:15px/1.5 system-ui,sans-serif;max-width:1200px;margin:24px auto;padding:0 16px}' ...
    'table{border-collapse:collapse;width:100%}th,td{padding:4px 8px;border-bottom:1px solid var(--line);text-align:left;font-variant-numeric:tabular-nums}' ...
    'th{color:var(--mute);font-weight:500}tr.warn{background:var(--warn)}tr.excl{background:var(--excl)}a{color:inherit}td:first-child{white-space:nowrap}' ...
    '.wrap{overflow-x:auto}.note{color:var(--mute);font-size:13px}.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(260px,1fr));gap:8px 16px}' ...
    '.chart .axis{stroke:var(--mute)}.chart .tick,.chart .label{fill:var(--mute);font-size:11px}.chart .legend{font-size:11px}' ...
    '.chart .ref{stroke:var(--ref);stroke-dasharray:4 3}.strip text{fill:var(--mute);font-size:11px}.strip .bad{stroke:var(--ref);stroke-width:2}</style>'];
html = ['<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">' ...
    '<title>' pipeline ' QC</title>' css '</head><body><h1>QC: ' pipeline '</h1>' ...
    sprintf('<p class="note">SeeCAT %s, %d run(s), %d excluded. %s</p>', seecat.version(), height(T), nEx, rules) plots ...
    '<div class="wrap"><table><tr><th>run</th><th>site</th><th>mean FD</th><th>max trans (mm)</th><th>max rot (&deg;)</th>' ...
    '<th>coverage</th><th>brain Dice</th><th>GM r (TPM)</th><th>minutes kept</th><th>tSNR</th><th>r(FD, DVARS) after</th><th>decision, reasons</th><th>warnings</th></tr>' ...
    rows '</table></div>' iqmPlots t1Plots fails '</body></html>'];
end

function s = fmt(T, c, i, f)
s = '';
if ismember(c, T.Properties.VariableNames) && isfinite(T.(c)(i))
    s = sprintf(f, T.(c)(i));
end
end

function s = strip(v, site, ids, name, dirn, lim)
% A small SVG strip plot: one dot per value, x jittered by site
W = 260; H = 150; L = 44; B = 22;
ok = isfinite(v);
if nnz(ok) == 0, s = ''; return, end
[g, ~, gi] = unique(site);
lo = min(v(ok)); hi = max(v(ok));
if hi == lo, hi = lo + 1; end
y = @(x) H - B - (x - lo) / (hi - lo) * (H - B - 10);
pal = {'#3b6fd8', '#d8873b', '#3ba06f', '#9b59b6', '#c0392b', '#16a2b8'};
dots = '';
mdn = zeros(size(v));
mad = zeros(size(v));
for k = 1:numel(g)
    in = gi == k;
    m = median(v(in & ok));
    mdn(in) = m;
    mad(in) = 1.4826 * median(abs(v(in & ok) - m));
end
for i = find(ok)'
    k = gi(i);
    cx = L + (k - 0.5) / numel(g) * (W - L - 6) + (mod(i * 7919, 23) - 11) * 0.9;
    bad = mad(i) > 0 && dirn * (v(i) - mdn(i)) / mad(i) > lim;
    cls = '';
    if bad, cls = ' class="bad"'; end
    dots = [dots sprintf('<circle cx="%.1f" cy="%.1f" r="3.5" fill="%s" fill-opacity="0.75"%s><title>%s: %.4g</title></circle>', ...
        cx, y(v(i)), pal{1 + mod(k - 1, numel(pal))}, cls, ids{i}, v(i))]; %#ok<AGROW>
end
labels = '';
for k = 1:numel(g)
    lab = g{k};
    if isempty(lab), lab = 'all'; end
    labels = [labels sprintf('<text x="%.1f" y="%d" text-anchor="middle">%s</text>', L + (k - 0.5) / numel(g) * (W - L - 6), H - 6, lab)]; %#ok<AGROW>
end
arrow = '&uarr; better';
if dirn > 0, arrow = '&darr; better'; end
s = sprintf(['<svg class="strip" viewBox="0 0 %d %d" role="img" aria-label="%s"><text x="0" y="12">%s (%s)</text>' ...
    '<text x="%d" y="%.1f" text-anchor="end">%.3g</text><text x="%d" y="%.1f" text-anchor="end">%.3g</text>' ...
    '<line x1="%d" y1="16" x2="%d" y2="%d" stroke="currentColor" stroke-opacity="0.3"/>%s%s</svg>'], ...
    W, H, name, name, arrow, L - 4, y(hi) + 4, hi, L - 4, y(lo), lo, L, L, H - B, labels, dots);
end
