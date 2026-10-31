function T = group_report(output_dir, pipeline, summary)
% GROUP_REPORT  One page with every run's QC metrics, and a TSV of them.
%   T = seecat.qc.group_report(output_dir, 'prep', summary)
%
% Reads every sub-*/*_desc-qc_metrics.json under OUTPUT_DIR (written by
% seecat.qc.run_report) and writes reports/<pipeline>_qc.html and
% reports/<pipeline>_qc.tsv. A run is flagged when its mean FD is above
% 0.25 mm (lenient cut-off, Parkes et al. 2018) or it has too little
% usable data (low_data). Failed units of SUMMARY (the seecat.run table)
% are listed too.

F = dir(fullfile(output_dir, 'sub-*', '*_desc-qc_metrics.json'));
cols = {'mean_fd', 'max_fd', 'n_flagged', 'n_frames', 'minutes_kept', 'low_data', ...
    'tsnr_median', 'fd_dvars_r_preproc', 'fd_dvars_r_denoised'};
ids = regexprep({F.name}', '_desc-qc_metrics\.json$', '');
T = table(ids, 'VariableNames', {'run'});
for c = cols
    T.(c{1}) = nan(height(T), 1);
end
for i = 1:numel(F)
    m = jsondecode(fileread(fullfile(F(i).folder, F(i).name)));
    for c = cols
        if isfield(m, c{1}) && ~isempty(m.(c{1}))
            T.(c{1})(i) = double(m.(c{1}));
        end
    end
end
T.flag = repmat({''}, height(T), 1);
T.flag(T.mean_fd > 0.25) = {'high FD'};
T.flag(T.low_data == 1) = strcat(T.flag(T.low_data == 1), {', little data'});
T.flag = regexprep(strtrim(T.flag), '^, ', '');
d = fullfile(output_dir, 'reports');
if ~exist(d, 'dir')
    mkdir(d);
end
seecat.io.write_tsv(T, fullfile(d, [pipeline '_qc.tsv']));

failed = {};
if nargin > 2 && ~isempty(summary) && ismember('status', summary.Properties.VariableNames)
    k = strcmp(summary.status, 'failed');
    failed = strcat(summary.unit(k), {': '}, summary.message(k));   % {': '} keeps the space
end
rows = '';
for i = 1:height(T)
    sub = regexp(T.run{i}, '^sub-[a-zA-Z0-9]+', 'match', 'once');
    cls = '';
    if ~isempty(T.flag{i})
        cls = ' class="warn"';
    end
    rows = [rows sprintf(['<tr%s><td><a href="../%s/%s_desc-qc_report.html">%s</a></td>' ...
        '<td>%.3f</td><td>%.2f</td><td>%d / %d</td><td>%.1f</td><td>%.1f</td><td>%.2f</td><td>%.2f</td><td>%s</td></tr>'], ...
        cls, sub, T.run{i}, T.run{i}, T.mean_fd(i), T.max_fd(i), T.n_flagged(i), T.n_frames(i), ...
        T.minutes_kept(i), T.tsnr_median(i), T.fd_dvars_r_preproc(i), T.fd_dvars_r_denoised(i), T.flag{i})]; %#ok<AGROW>
end
fails = '';
if ~isempty(failed)
    fails = ['<h2>Failed</h2><ul><li>' strjoin(failed, '</li><li>') '</li></ul>'];
end
fdPlot = '';
if height(T) > 1
    fdPlot = seecat.qc.svg_lines(1:height(T), sort(T.mean_fd)', struct('ylabel', 'mean FD (mm)', ...
        'hline', 0.25, 'height', 140, 'names', {{'runs, sorted by mean FD'}}));
end
css = ['<style>:root{--bg:#fff;--fg:#1d2433;--mute:#5d6678;--line:#d9dde5;--warn:#fdecea;--ref:#c0392b;--shade:#f2c4c4}' ...
    '@media (prefers-color-scheme:dark){:root{--bg:#14171f;--fg:#e4e7ee;--mute:#9aa3b5;--line:#343a48;--warn:#4a2323;--ref:#ff7b6b;--shade:#5a2a2a}}' ...
    'body{background:var(--bg);color:var(--fg);font:15px/1.5 system-ui,sans-serif;max-width:1100px;margin:24px auto;padding:0 16px}' ...
    'table{border-collapse:collapse;width:100%}th,td{padding:4px 8px;border-bottom:1px solid var(--line);text-align:left;font-variant-numeric:tabular-nums}' ...
    'th{color:var(--mute);font-weight:500}tr.warn{background:var(--warn)}a{color:inherit}td:first-child,td:last-child{white-space:nowrap}' ...
    '.wrap{overflow-x:auto}.note{color:var(--mute);font-size:13px}' ...
    '.chart .axis{stroke:var(--mute)}.chart .tick,.chart .label{fill:var(--mute);font-size:11px}.chart .legend{font-size:11px}' ...
    '.chart .ref{stroke:var(--ref);stroke-dasharray:4 3}</style>'];
html = ['<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">' ...
    '<title>' pipeline ' QC</title>' css '</head><body><h1>QC: ' pipeline '</h1>' ...
    sprintf('<p class="note">SeeCAT %s, %d run(s). Flags: high FD = mean FD above 0.25 mm; little data = less than the minimum minutes after censoring.</p>', ...
    seecat.version(), height(T)) fdPlot ...
    '<div class="wrap"><table><tr><th>run</th><th>mean FD</th><th>max FD</th><th>flagged frames</th><th>minutes kept</th>' ...
    '<th>tSNR</th><th>r(FD, DVARS) before</th><th>after</th><th>flag</th></tr>' rows '</table></div>' fails '</body></html>'];
fid = fopen(fullfile(d, [pipeline '_qc.html']), 'w', 'n', 'UTF-8');
fwrite(fid, html, 'char');
fclose(fid);
end
