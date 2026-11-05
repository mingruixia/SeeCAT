function T = exclusion_list(folder, action, ids, exclude, notes)
% EXCLUSION_LIST  Read or change reports/qc_exclusions.tsv of a derivatives folder.
%   T = seecat.qc.exclusion_list(folder)            % the list, with run metrics
%   seecat.qc.exclusion_list(folder, 'set', ids, exclude, notes)
%
% Reading joins each row with the metrics of reports/prep_qc.tsv or
% fmriprep_qc.tsv (site, mean_fd, max_translation, max_rotation, coverage,
% tsnr_median, bold_tsnr, t1_cnr, ...). Setting changes the exclude value
% (true/false) and note of the rows IDS; a row whose value changes, or
% that gets a note, is marked decision = 'user', so the group report keeps
% it when it is made again.
f = fullfile(folder, 'reports', 'qc_exclusions.tsv');
if ~exist(f, 'file')
    error('SeeCAT:qc', 'No reports/qc_exclusions.tsv in %s; run Preprocessing or fMRIPrep denoising first.', folder);
end
X = seecat.io.read_tsv(f);
for c = {'reasons', 'warnings', 'decision', 'note'}
    v = cellstr(string(X.(c{1})));
    v(strcmp(v, 'n/a') | strcmp(v, 'NaN') | strcmp(v, '<missing>')) = {''};
    X.(c{1}) = v;
end
X.id = cellstr(string(X.id));
X.kind = cellstr(string(X.kind));
if nargin > 1 && strcmp(action, 'set')
    ids = cellstr(ids);
    for i = 1:numel(ids)
        k = find(strcmp(X.id, ids{i}), 1);
        if isempty(k), continue, end
        newEx = double(logical(exclude(i)));
        newNote = char(notes{i});
        if newEx ~= X.exclude(k) || ~strcmp(newNote, X.note{k})
            X.exclude(k) = newEx;
            X.note{k} = newNote;
            X.decision{k} = 'user';
        end
    end
    seecat.io.write_tsv(X, f);
    T = X;
    return
end
T = X;
q = [dir(fullfile(folder, 'reports', 'prep_qc.tsv')); dir(fullfile(folder, 'reports', 'fmriprep_qc.tsv'))];
cols = {'site', 'mean_fd', 'max_translation', 'max_rotation', 'coverage', 'reg_brain_dice', 'reg_gm_corr', ...
    'reg_epi_t1_dice', 'minutes_kept', 'tsnr_median', ...
    'bold_tsnr', 'bold_dvars_std', 't1_cnr', 't1_cjv'};
for c = cols
    if strcmp(c{1}, 'site')
        T.(c{1}) = repmat({''}, height(T), 1);
    else
        T.(c{1}) = nan(height(T), 1);
    end
end
for i = 1:numel(q)
    Q = seecat.io.read_tsv(fullfile(q(i).folder, q(i).name));
    [in, row] = ismember(T.id, cellstr(string(Q.run)));
    t1 = ismember('t1_file', Q.Properties.VariableNames);
    for c = cols
        if ~ismember(c{1}, Q.Properties.VariableNames), continue, end
        v = Q.(c{1});
        if strcmp(c{1}, 'site')
            v = cellstr(string(v));
            v(strcmp(v, 'n/a') | strcmp(v, '<missing>')) = {''};
        end
        T.(c{1})(in) = v(row(in));
        if t1 && startsWith(c{1}, 't1_')            % T1w rows: from the first run of that T1w
            stems = regexprep(cellstr(string(Q.t1_file)), '\.nii(\.gz)?$', '');
            [inT, rowT] = ismember(T.id, stems);
            T.(c{1})(inT) = v(rowT(inT));
        end
    end
    if t1 && ismember('site', Q.Properties.VariableNames)
        stems = regexprep(cellstr(string(Q.t1_file)), '\.nii(\.gz)?$', '');
        [inT, rowT] = ismember(T.id, stems);
        s = cellstr(string(Q.site));
        T.site(inT) = s(rowT(inT));
    end
end
end
