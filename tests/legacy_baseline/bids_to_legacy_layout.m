function bids_to_legacy_layout(bidsDir, workDir, task)
% BIDS_TO_LEGACY_LAYOUT  Copy a BIDS dataset into the SeeCAT 1.0 folder layout
% (FunImg/<sub>/<file>.nii, T1Img/<sub>/<file>.nii) so the legacy pipeline can
% run on it. Images are gunzipped; the source dataset is not modified.
%
%   bids_to_legacy_layout('D:/data/SeeCAT_testdata/ds000030', ...
%                         'D:/data/SeeCAT_baseline/ds000030', 'rest')

subs = dir(fullfile(bidsDir, 'sub-*'));
subs = subs([subs.isdir]);
for i = 1:numel(subs)
    s = subs(i).name;
    bold = dir(fullfile(bidsDir, s, 'func', sprintf('%s_task-%s*_bold.nii.gz', s, task)));
    t1 = dir(fullfile(bidsDir, s, 'anat', sprintf('%s_T1w.nii.gz', s)));
    if isempty(bold) || isempty(t1)
        fprintf('skip %s (missing bold or T1w)\n', s);
        continue
    end
    funDir = fullfile(workDir, 'FunImg', s);
    t1Dir = fullfile(workDir, 'T1Img', s);
    if ~exist(funDir, 'dir'), mkdir(funDir); end
    if ~exist(t1Dir, 'dir'), mkdir(t1Dir); end
    if isempty(dir(fullfile(funDir, '*.nii')))
        gunzip(fullfile(bold(1).folder, bold(1).name), funDir);
    end
    if isempty(dir(fullfile(t1Dir, '*.nii')))
        gunzip(fullfile(t1(1).folder, t1(1).name), t1Dir);
    end
    fprintf('%s ready\n', s);
end
end
