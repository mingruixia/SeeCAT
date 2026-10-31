function R = runs(folder, series)
% RUNS  Volumes, TR and head motion of every BOLD run in a folder.
%   R = seecat.qc.runs('derivatives/seecat', 'preproc')
%
% FOLDER is a BIDS dataset or a derivatives folder (SeeCAT or fMRIPrep).
% SERIES picks the images: 'preproc' (*_desc-preproc_bold), 'denoised'
% (*_desc-denoised_bold), 'raw' (bold images without a desc entity) or
% 'all'. One row per image, in layout order:
%   run          file name without _bold.nii[.gz]
%   volumes, tr  from the header (tr in s; the JSON sidecar wins)
%   mean_fd, max_fd   framewise displacement (mm), from the run's confounds
%                     table (seecat.qc.motion); NaN without one
%   flagged      frames flagged for motion, and flagged_pct of the volumes
%   flag         mean_fd > 0.25 mm or flagged_pct > 20
%   file         full path
% Only headers and confounds tables are read, so a large dataset is quick.

if nargin < 2
    series = 'preproc';
end
L = seecat.bids.layout(folder);
F = seecat.bids.query(L, 'suffix', 'bold', 'ext', {'.nii', '.nii.gz'});
switch series
    case {'preproc', 'denoised'}
        keep = arrayfun(@(f) isfield(f.ent, 'desc') && strcmp(f.ent.desc, series), F);
    case 'raw'
        keep = arrayfun(@(f) ~isfield(f.ent, 'desc'), F);
    case 'all'
        keep = true(size(F));
    otherwise
        error('SeeCAT:qc', 'Unknown series "%s"; use preproc, denoised, raw or all.', series);
end
F = F(keep);
n = numel(F);
run = cell(n, 1);
file = cell(n, 1);
[volumes, tr, mean_fd, max_fd, flagged, flagged_pct] = deal(nan(n, 1));
for i = 1:n
    f = F(i);
    run{i} = regexprep(f.name, '_bold\.nii(\.gz)?$', '');
    file{i} = f.path;
    h = seecat.io.nii_info(f.path);
    volumes(i) = h.dim(4);
    tr(i) = h.tr;
    meta = seecat.bids.metadata(L, f);
    if isfield(meta, 'RepetitionTime')
        tr(i) = meta.RepetitionTime;
    end
    C = seecat.qc.motion(f.path, volumes(i));
    if ~isempty(C.file)
        mean_fd(i) = mean(C.fd, 'omitnan');
        max_fd(i) = max(C.fd, [], 'omitnan');
        flagged(i) = nnz(C.flagged);
        flagged_pct(i) = 100 * flagged(i) / volumes(i);
    end
end
flag = mean_fd > 0.25 | flagged_pct > 20;
R = table(run, volumes, tr, mean_fd, max_fd, flagged, flagged_pct, flag, file);
end
