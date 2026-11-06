function kind = source_kind(src)
% SOURCE_KIND  'nifti' or 'dicom': what a folder to import holds.
%   kind = seecat.bids.source_kind('D:/export')
%
% 'nifti' when there are NIfTI images (.nii, .nii.gz, or Analyze .img with
% .hdr) below the folder, outside derivatives and hidden folders; 'dicom'
% otherwise (seecat.bids.from_dicom then reports a folder without DICOM
% files). A folder with both is imported from its NIfTI images.

if ~exist(src, 'dir')
    error('SeeCAT:bids', 'Folder not found: %s', src);
end
D = dir(fullfile(src, '**', '*.*'));
D = D(~[D.isdir]);
low = lower(strrep(cellfun(@(f, n) fullfile(f, n), {D.folder}, {D.name}, 'UniformOutput', false), '\', '/'));
low = cellfun(@(p) p(numel(src) + 1:end), low, 'UniformOutput', false);
skip = ~cellfun(@isempty, regexp(low, '/(derivatives|\.[^/]*)/', 'once'));
img = endsWith(low, '.nii') | endsWith(low, '.nii.gz') | endsWith(low, '.hdr');
if any(img & ~skip)
    kind = 'nifti';
else
    kind = 'dicom';
end
end
