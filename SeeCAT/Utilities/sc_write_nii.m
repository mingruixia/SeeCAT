function V = sc_write_nii(Y, ref, fname, varargin)
% SC_WRITE_NII  Write a 3D or 4D array as NIfTI on the grid of a reference.
%   sc_write_nii(Y, ref, 'out.nii')
%   sc_write_nii(Y, ref, 'out.nii.gz', 'Descrip', 'T map', 'DataType', 'int16')
%   V = sc_write_nii(...)
%
% Y is in stored voxel order (as returned by sc_read_nii). REF is an spm_vol
% header or a file name; only its affine is used (the first volume's for 4D).
% The size of Y must match REF's dimensions in x, y and z.
%
% Options:
%   'Descrip'   header description, at most 80 characters (default '').
%   'DataType'  'float32' (default), 'float64', 'int32', 'int16' or 'uint8'.
%               Integer types are rounded and clipped, with a warning when
%               values are clipped; NaN becomes 0. No scaling is used.
%
% Missing folders are created. A name ending in .nii.gz is written and then
% compressed. V is the spm_vol header of the written .nii file, or empty
% for .nii.gz.

p = inputParser;
p.addParameter('Descrip', '', @(x) ischar(x) || isstring(x));
p.addParameter('DataType', 'float32', @(x) any(strcmpi(x, {'float32', 'float64', 'int32', 'int16', 'uint8'})));
p.parse(varargin{:});
opt = p.Results;

if ischar(ref) || isstring(ref)
    ref = sc_read_header(char(ref));
end
ref = ref(1);

dim = size(Y);
dim(end+1:4) = 1;
if numel(dim) > 4
    error('SeeCAT:write', 'Only 3D and 4D arrays can be written.');
end
if ~isequal(dim(1:3), ref.dim(1:3))
    error('SeeCAT:write', 'Data size [%s] does not match the reference grid [%s].', ...
        num2str(dim(1:3)), num2str(ref.dim(1:3)));
end
if dim(4) == 1
    dim = dim(1:3);
end

fname = char(fname);
gz = endsWith(fname, '.gz', 'IgnoreCase', true);
if gz
    fname = fname(1:end-3);
end
[d, ~, ext] = fileparts(fname);
if ~strcmpi(ext, '.nii')
    error('SeeCAT:write', 'Output name must end in .nii or .nii.gz: %s', fname);
end
if ~isempty(d) && ~exist(d, 'dir')
    mkdir(d);
end

dtype = lower(char(opt.DataType));
if startsWith(dtype, 'float')
    Y = cast(Y, strrep(strrep(dtype, 'float32', 'single'), 'float64', 'double'));
else
    Y(isnan(Y)) = 0;
    lim = double([intmin(dtype) intmax(dtype)]);
    if any(Y(:) < lim(1) | Y(:) > lim(2))
        warning('SeeCAT:write', 'Values outside the %s range were clipped in %s.', dtype, fname);
    end
    Y = cast(min(max(round(double(Y)), lim(1)), lim(2)), dtype);
end

if spm_platform('bigend')
    endian = 'BE';
else
    endian = 'LE';
end
if exist(fname, 'file')
    delete(fname);    % avoid file_array writing into a stale, larger file
end
N = nifti;
N.dat = file_array(fname, dim, [upper(dtype) '-' endian], 352, 1, 0);
N.mat = ref.mat;
N.mat0 = ref.mat;
N.descrip = char(opt.Descrip);
create(N);
if numel(dim) == 3
    N.dat(:, :, :) = Y;
else
    N.dat(:, :, :, :) = Y;
end

if gz
    gzip(fname);
    delete(fname);
    V = [];
else
    V = spm_vol(fname);
end
end

function h = sc_read_header(f)
if endsWith(f, '.gz', 'IgnoreCase', true)
    [~, h] = sc_read_nii(f, 'Volumes', 1);
else
    h = spm_vol(f);
end
end
