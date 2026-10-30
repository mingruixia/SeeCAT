function sc_seed_fc_subject(DataFile, SubName, hdr_ref, mask_ind, seed_ind, OutDir)
% SC_SEED_FC_SUBJECT  Seed-based FC maps for one subject.
%   DataFile  4D NIfTI on the grid of HDR_REF
%   mask_ind  1 x nVox logical, voxels to compute
%   seed_ind  cell of 1 x nVox logical seed masks
% Writes FC_SeedNN/FC_SeedNN_<SubName>.nii (r) and zFC_SeedNN/... (Fisher z)
% under OutDir. Zero-variance voxels get 0; r is clipped so z stays finite.
Nii = nifti(DataFile);
dims = Nii.dat.dim;
if numel(dims) < 4 || ~isequal(dims(1:3), hdr_ref.dim(1:3)) || max(abs(Nii.mat(:)-hdr_ref.mat(:))) > 1e-4
    error('SeeCAT:FC:grid','%s is not 4D or is on a different voxel grid than %s.',DataFile,hdr_ref.fname);
end
nT = dims(4);
volCourse = reshape(double(Nii.dat),[prod(dims(1:3)),nT])';
nSeed = numel(seed_ind);
seedCourse = zeros(nT,nSeed);
for j = 1:nSeed
    % average only voxels that carry signal (inside the brain in this subject)
    sv = volCourse(:,seed_ind{j});
    sv = sv(:,std(sv,0,1)>0 & all(isfinite(sv),1));
    if isempty(sv)
        warning('SeeCAT:FC:emptySeed','Seed %d has no voxels with signal in %s; its maps are set to 0.',j,SubName);
        continue
    end
    seedCourse(:,j) = mean(sv,2);
end
maskCourse = volCourse(:,mask_ind);
r = ZScoreCols(seedCourse)' * ZScoreCols(maskCourse) ./ (nT-1);
r(~isfinite(r)) = 0;                                  % zero-variance voxels or seeds
r = min(max(r,-1+eps('single')),1-eps('single'));     % keep Fisher z finite
z = atanh(r);
for j = 1:nSeed
    SeedTag = sprintf('%02d',j);
    hdr_fc = hdr_ref;
    hdr_fc.n = [1 1];
    hdr_fc.dt(1) = 16;
    hdr_fc.pinfo = [1;0;0];
    hdr_fc.fname = [OutDir,filesep,'FC_Seed',SeedTag,filesep,'FC_Seed',SeedTag,'_',SubName,'.nii'];
    vol_fc = zeros(hdr_fc.dim);
    vol_fc(mask_ind) = r(j,:);
    spm_write_vol(hdr_fc,vol_fc);
    hdr_fc.fname = [OutDir,filesep,'zFC_Seed',SeedTag,filesep,'zFC_Seed',SeedTag,'_',SubName,'.nii'];
    vol_fc(mask_ind) = z(j,:);
    spm_write_vol(hdr_fc,vol_fc);
end


function X = ZScoreCols(X)
X = X - mean(X,1);
X = X ./ std(X,0,1);
