function compare_reml_spm(out)
% COMPARE_REML_SPM  seecat.stat.reml + glm against SPM's one-way within-subject
% ANOVA (dependence, unequal variance) on ds000030: three maps per subject
% (PCC zFC, mPFC zFC, positive binary degree z) as three conditions.
%   compare_reml_spm('C:/tmp/remlcheck')
if exist(out, 'dir'), rmdir(out, 's'); end
mkdir(out);
in = 'D:/data/SeeCAT_e2e/ds000030/seecat';
kinds = {'desc-PCC_stat-z', 'desc-mPFC_stat-z', 'desc-degPosBinR0p2_stat-z'};
F = dir(fullfile(in, 'sub-*', 'func', '*_desc-PCC_stat-z_connectivity.nii.gz'));
subs = regexp({F.name}', '^(sub-[^_]+)', 'tokens', 'once'); subs = [subs{:}]';
nii = {};
I = [];
for s = 1:numel(subs)
    for c = 1:3
        f = dir(fullfile(in, subs{s}, 'func', [subs{s} '*_' kinds{c} '_connectivity.nii.gz']));
        g = gunzip(fullfile(f.folder, f.name), fullfile(out, 'maps', sprintf('%s_%d', subs{s}, c)));
        nii{end+1, 1} = g{1}; %#ok<AGROW>
        I(end+1, :) = [s c]; %#ok<AGROW>
    end
end
[Y, V] = seecat.io.read_nii(nii);
gm = seecat.io.read_nii('D:/verysync/dropbox/Works/Claude_Project/SeeCAT/SeeCAT/templates/tpl-IXI549Space_res-3_label-GM_mask.nii', 'Ref', V(1)) > 0;
mask = gm & all(Y ~= 0 & isfinite(Y), 4);
seecat.io.write_nii(uint8(mask), V(1), fullfile(out, 'mask.nii'), 'DataType', 'uint8');
Ym = reshape(Y, [], numel(nii))'; Ym = Ym(:, mask(:));
% SPM: one-way within-subject ANOVA
d = fullfile(out, 'spm'); mkdir(d);
j.spm.stats.factorial_design.dir = {d};
for s = 1:numel(subs)
    j.spm.stats.factorial_design.des.anovaw.fsubject(s).scans = strcat(nii(I(:, 1) == s), ',1');
    j.spm.stats.factorial_design.des.anovaw.fsubject(s).conds = [1 2 3];
end
j.spm.stats.factorial_design.des.anovaw.dept = 1;
j.spm.stats.factorial_design.des.anovaw.variance = 1;
j.spm.stats.factorial_design.des.anovaw.gmsca = 0;
j.spm.stats.factorial_design.des.anovaw.ancova = 0;
j.spm.stats.factorial_design.masking.tm.tm_none = 1;
j.spm.stats.factorial_design.masking.im = 0;
j.spm.stats.factorial_design.masking.em = {fullfile(out, 'mask.nii,1')};
j.spm.stats.factorial_design.globalc.g_omit = 1;
j.spm.stats.factorial_design.globalm.gmsca.gmsca_no = 1;
j.spm.stats.factorial_design.globalm.glonorm = 1;
k.spm.stats.fmri_est.spmmat = {fullfile(d, 'SPM.mat')};
k.spm.stats.fmri_est.method.Classical = 1;
seecat.util.spm_run({j, k});
load(fullfile(d, 'SPM.mat'), 'SPM');
X = SPM.xX.X;
iC = SPM.xX.iH;                                   % condition columns
c = struct('spm', []);
w = zeros(2, size(X, 2)); w(1, iC(1:2)) = [1 -1]; w(2, iC(2:3)) = [1 -1];
cc.spm.stats.con.spmmat = {fullfile(d, 'SPM.mat')};
cc.spm.stats.con.consess{1}.fcon = struct('name', 'cond', 'weights', w, 'sessrep', 'none');
seecat.util.spm_run(cc);
load(fullfile(d, 'SPM.mat'), 'SPM');
% SeeCAT on SPM's design and scan order
[~, ord] = ismember(SPM.xY.P, strcat(nii, ',1'));
if any(ord == 0), [~, ord] = ismember(strrep(SPM.xY.P, ',1', ''), nii); end
Ys = Ym(ord, :);
Is = I(ord, :);
[Vr, info] = seecat.stat.reml(Ys, X, Is, [false true], [true false], SPM.xX.iB);
fprintf('ReML voxels: SeeCAT %d | components %d\n', info.voxels, info.components);
fprintf('V max|diff| %.2e (max |V| %.3f)\n', max(abs(Vr(:) - full(SPM.xVi.V(:)))), max(abs(full(SPM.xVi.V(:)))));
G = seecat.stat.glm(Ys, X, struct('name', 'cond', 'type', 'F', 'weights', w), struct('V', Vr));
Fs = seecat.io.read_nii(fullfile(d, 'spmF_0001.nii'));
fprintf('df: SeeCAT [%.4f %.4f], SPM [%.4f %.4f]\n', G.con(1).df, SPM.xCon(1).eidf, SPM.xX.erdf);
fprintf('F max rel|diff| %.2e (max F %.2f)\n', max(abs(Fs(mask) - G.con(1).stat(:)) ./ max(1, abs(Fs(mask)))), max(Fs(mask)));
S = seecat.stat.smoothness(G, mask, V(1));
fprintf('FWHM SeeCAT %s, SPM %s\n', mat2str(S.FWHM, 8), mat2str(SPM.xVol.FWHM, 8));
