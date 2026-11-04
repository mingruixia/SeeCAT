function ctx = step_iqm(ctx, opt, log)
% MRIQC-style image quality metrics of the raw data (seecat.qc.iqm_bold,
% seecat.qc.iqm_anat), from what preprocessing already made:
%   BOLD  the run after dummy-scan removal, without slice timing, resliced
%         with the realignment (MRIQC's head-motion-corrected series); the
%         brain mask is GM + WM + CSF > 0.5 of the segmentation on the
%         mean EPI grid; FD from the confounds.
%   T1w   the coregistered T1w (raw intensities), its bias-corrected image,
%         the native GM/WM/CSF maps; inu = raw / corrected; head mask =
%         intensity above 10 % of the 98th percentile, closed, holes filled,
%         joined with the brain; rot = voxels that are exactly 0 (outside
%         the field of view or defaced); air = outside the head dilated by
%         3 voxels, not rot. Only with a T1w (normalise.method 'segment').
% Sets ctx.iqm: bold_* and t1_* fields (and t1_file); also brain-mask
% volumes: t1_tiv_ml, t1_gm_ml, t1_wm_ml, t1_csf_ml.
Q = struct();
f = ctx.files;
seecat.util.spm_run([]);

% ---- BOLD
V = spm_vol(f.bold);                              % realigned: its headers hold the motion
Vin = spm_vol(f.bold_input);
tmp = fullfile(ctx.work_dir, 'iqm_hmc_src.nii');
copyfile(f.bold_input, tmp, 'f');
N = nifti(tmp);
mats = cat(3, V.mat);
N.mat = mats(:, :, 1);
N.extras = struct('mat', mats);
create(N);
P = spm_vol(tmp);
spm_reslice(P, struct('which', 2, 'mean', false, 'interp', 4, 'wrap', [0 0 0], 'mask', 0, 'prefix', 'r'));
hmc = fullfile(ctx.work_dir, 'riqm_hmc_src.nii');
[Y, Vh] = seecat.io.read_nii(hmc, 'Class', 'single');
delete(tmp);
delete(hmc);
ref = Vh(1);
brain = zeros(ref.dim);
for k = 1:3
    brain = brain + seecat.io.read_nii(f.(sprintf('c%d', k)), 'Ref', ref, 'Interp', 1);
end
mask = brain > 0.5;
T = seecat.io.read_tsv(f.confounds);
vox = sqrt(sum(ref.mat(1:3, 1:3) .^ 2));
B = seecat.qc.iqm_bold(Y, mask, T.framewise_displacement, vox, ctx.dummy_scans);
clear Y
for k = fieldnames(B)'
    Q.(['bold_' k{1}]) = B.(k{1});
end
log('iqm: BOLD tSNR %.1f, SNR %.1f, DVARS std %.2f, AOR %.4f', B.tsnr, B.snr, B.dvars_std, B.aor);
clear Vin

% ---- T1w
if ~isempty(f.t1w)
    [raw, Vt] = seecat.io.read_nii(f.t1w, 'Class', 'single');
    raw = double(raw(:, :, :, 1));
    m = double(seecat.io.read_nii(f.biascorr, 'Class', 'single'));
    rd = @(k) double(seecat.io.read_nii(f.(sprintf('c%d', k)), 'Class', 'single'));
    pv = {rd(3), rd(1), rd(2)};                   % CSF, GM, WM (MRIQC's order)
    inu = ones(size(raw));
    ok = m > 0 & raw > 0;
    inu(ok) = raw(ok) ./ m(ok);
    rot = raw == 0;
    pos = raw(raw > 0);
    thr = 0.1 * prctile98(pos);
    head = raw > thr | (pv{1} + pv{2} + pv{3}) > 0.5;
    head = seecat.qc.iqm_morph(head, 'close', 2);
    head = largestComponent(head);
    head = fillHoles(head);
    air = ~seecat.qc.iqm_morph(head, 'dilate', 3) & ~rot;
    voxT = sqrt(sum(Vt(1).mat(1:3, 1:3) .^ 2));
    A = seecat.qc.iqm_anat(m, inu, pv, head, air, rot, voxT);
    for k = fieldnames(A)'
        Q.(['t1_' k{1}]) = A.(k{1});
    end
    v = prod(voxT) / 1000;                        % mL per voxel
    Q.t1_csf_ml = sum(pv{1}(:)) * v;
    Q.t1_gm_ml = sum(pv{2}(:)) * v;
    Q.t1_wm_ml = sum(pv{3}(:)) * v;
    Q.t1_tiv_ml = Q.t1_csf_ml + Q.t1_gm_ml + Q.t1_wm_ml;
    [~, n, e] = fileparts(f.t1w_src);
    Q.t1_file = [n e];
    log('iqm: T1w CNR %.2f, CJV %.3f, SNR %.1f, TIV %.0f mL', A.cnr, A.cjv, A.snr_total, Q.t1_tiv_ml);
end
ctx.iqm = Q;
end

function q = prctile98(x)
x = sort(x(:));
q = x(max(1, round(0.98 * numel(x))));
end

function m = largestComponent(m)
[L, n] = spm_bwlabel(double(m), 26);
if n > 1
    c = accumarray(L(L > 0), 1);
    [~, k] = max(c);
    m = L == k;
end
end

function m = fillHoles(m)
% Background components that do not touch the volume's faces are holes
[L, n] = spm_bwlabel(double(~m), 6);
edge = unique([reshape(L([1 end], :, :), [], 1); reshape(L(:, [1 end], :), [], 1); reshape(L(:, :, [1 end]), [], 1)]);
holes = setdiff(1:n, edge);
m(ismember(L, holes)) = true;
end
