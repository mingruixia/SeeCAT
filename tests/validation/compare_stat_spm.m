function compare_stat_spm(out)
% COMPARE_STAT_SPM  seecat.stat core against SPM on a two-sample t-test with a
% covariate: ds000030 PCC zFC, CONTROL vs SCHZ, age. OUT: a scratch folder.
%   compare_stat_spm('C:/tmp/statcheck')
if exist(out, 'dir'), rmdir(out, 's'); end
mkdir(out);
in = 'D:/data/SeeCAT_e2e/ds000030/seecat';
P = seecat.io.read_tsv('D:/data/SeeCAT_testdata/ds000030/participants.tsv');
F = dir(fullfile(in, 'sub-*', 'func', '*_desc-PCC_stat-z_connectivity.nii.gz'));
files = fullfile({F.folder}, {F.name})';
subs = regexp({F.name}', '^(sub-[^_]+)', 'tokens', 'once'); subs = [subs{:}]';
[~, ip] = ismember(subs, P.participant_id);
grp = double(strcmp(P.diagnosis(ip), 'SCHZ')) + 1;
age = P.age(ip);
% unpack for SPM, analysis mask = GM & non-zero in every map
nii = cell(numel(files), 1);
for i = 1:numel(files)
    g = gunzip(files{i}, fullfile(out, 'maps')); nii{i} = g{1};
end
[Y, V] = seecat.io.read_nii(nii);
gm = seecat.io.read_nii('D:/verysync/dropbox/Works/Claude_Project/SeeCAT/SeeCAT/templates/tpl-IXI549Space_res-3_label-GM_mask.nii', 'Ref', V(1)) > 0;
mask = gm & all(Y ~= 0 & isfinite(Y), 4);
seecat.io.write_nii(uint8(mask), V(1), fullfile(out, 'mask.nii'), 'DataType', 'uint8');
Ym = reshape(Y, [], numel(files))'; Ym = Ym(:, mask(:));
% SeeCAT
X = [grp == 1, grp == 2, age - mean(age)];
con = struct('name', 'CONgtSCHZ', 'type', 't', 'weights', [1 -1 0]);
G = seecat.stat.glm(Ym, double(X), con);
S = seecat.stat.smoothness(G, mask, V(1));
I = seecat.stat.inference(G.con(1), mask, V(1), S, struct('method', 'cluster_fwe', 'alpha', 0.05, 'cdt_p', 0.01));
% SPM
d = fullfile(out, 'spm');
mkdir(d);
j.spm.stats.factorial_design.dir = {d};
j.spm.stats.factorial_design.des.t2.scans1 = strcat(nii(grp == 1), ',1');
j.spm.stats.factorial_design.des.t2.scans2 = strcat(nii(grp == 2), ',1');
j.spm.stats.factorial_design.des.t2.dept = 0;
j.spm.stats.factorial_design.des.t2.variance = 0;    % equal
j.spm.stats.factorial_design.des.t2.gmsca = 0;
j.spm.stats.factorial_design.des.t2.ancova = 0;
order = [find(grp == 1); find(grp == 2)];
j.spm.stats.factorial_design.cov = struct('c', age(order), 'cname', 'age', 'iCFI', 1, 'iCC', 1);
j.spm.stats.factorial_design.masking.tm.tm_none = 1;
j.spm.stats.factorial_design.masking.im = 0;
j.spm.stats.factorial_design.masking.em = {fullfile(out, 'mask.nii,1')};
j.spm.stats.factorial_design.globalc.g_omit = 1;
j.spm.stats.factorial_design.globalm.gmsca.gmsca_no = 1;
j.spm.stats.factorial_design.globalm.glonorm = 1;
k.spm.stats.fmri_est.spmmat = {fullfile(d, 'SPM.mat')};
k.spm.stats.fmri_est.method.Classical = 1;
c.spm.stats.con.spmmat = {fullfile(d, 'SPM.mat')};
c.spm.stats.con.consess{1}.tcon = struct('name', 'CONgtSCHZ', 'weights', [1 -1 0], 'sessrep', 'none');
seecat.util.spm_run({j, k, c});
load(fullfile(d, 'SPM.mat'), 'SPM');
Ts = seecat.io.read_nii(fullfile(d, 'spmT_0001.nii'));
fprintf('voxels: SeeCAT %d, SPM %d\n', nnz(mask), SPM.xVol.S);
fprintf('T max|diff| %.2e (max |T| %.2f)\n', max(abs(Ts(mask) - G.con(1).stat(:))), max(abs(Ts(mask))));
for b = 1:3
    B = seecat.io.read_nii(fullfile(d, sprintf('beta_%04d.nii', b)));
    fprintf('beta %d max rel|diff| %.2e\n', b, max(abs(B(mask) - G.beta(b, :)')) / max(abs(B(mask))));
end
fprintf('df: SeeCAT %.4f, SPM %.4f\n', G.erdf, SPM.xX.erdf);
fprintf('FWHM SeeCAT %s, SPM %s\n', mat2str(S.FWHM, 8), mat2str(SPM.xVol.FWHM, 8));
fprintf('R    SeeCAT %s, SPM %s\n', mat2str(S.R, 8), mat2str(SPM.xVol.R, 8));
xSPM = struct('swd', d, 'Ic', 1, 'u', 0.01, 'Im', [], 'thresDesc', 'none', 'title', '', 'k', 0, 'Mc', 0);
[~, xSPM] = spm_getSPM(xSPM);
TabDat = spm_list('Table', xSPM);
fprintf('height: SeeCAT %.4f, SPM %.4f\n', I.height, xSPM.u);
disp('SPM table (cluster: k, p FWE, p unc | peak T, Z, p FWE, xyz):');
for r = 1:size(TabDat.dat, 1)
    t = TabDat.dat(r, :);
    fprintf('  %6s %8s %8s | %7.3f %6.3f %8.4f  %s\n', num2str(t{5}), num2str(t{3}, 4), num2str(t{6}, 4), t{9}, t{10}, t{7}, mat2str(t{12}', 3));
end
Tb = I.table;
nr = min(size(TabDat.dat, 1), height(Tb));
fprintf('table rows: SeeCAT %d, SPM %d\n', height(Tb), size(TabDat.dat, 1));
d = zeros(nr, 6);
for r = 1:nr
    t = TabDat.dat(r, :);
    d(r, :) = abs([t{9} - Tb.peak_stat(r), t{10} - Tb.peak_z(r), t{7} - Tb.p_peak_fwe(r), ...
        max(abs(t{12}' - [Tb.x(r) Tb.y(r) Tb.z(r)])), nanDiff(t{5}, Tb.voxels(r)), nanDiff(t{3}, Tb.p_cluster_fwe(r))]);
end
fprintf('max |diff| over rows: T %.2e, Z %.2e, p peak FWE %.2e, xyz %.2e, cluster k %.2e, p cluster FWE %.2e\n', max(d, [], 1));
end

function x = nanDiff(a, b)
if isempty(a), a = NaN; end
if isnan(a) && isnan(b)
    x = 0;
else
    x = a - b;
end
end
