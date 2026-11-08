function [cfg, spec] = defaults()
% DEFAULTS  Default configuration of connectivity gradients.
%   [cfg, spec] = seecat.gradient.defaults()
%
% Use seecat.config('gradient'). Input is a SeeCAT derivatives folder. For
% each run, the node series (voxels of a coarser grid, or atlas parcels;
% censored frames left out) give a connectivity matrix, whose diffusion map
% embedding gives the gradients (seecat.gradient.embed; Margulies et al.
% 2016, BrainSpace defaults). The gradients of all runs are then aligned
% (seecat.gradient.align) so that component k means the same in every run.

[cfg, spec] = seecat.util.common_defaults();
cfg = catstruct(struct('pipeline', 'gradient', 'input_dir', ''), cfg);
cfg.input = 'denoised';          % desc of the input series
cfg.space = '';
cfg.res = '';                % res label, needed only when there are several
cfg.nodes = 'voxels';            % 'voxels' (a grid of node_size mm) or 'atlas'
cfg.node_size = 4;               % mm, voxels only
cfg.mask = 'gm';                 % voxels only: 'gm', 'brain' or a mask file
cfg.group_mask = false;          % only voxels in the brain mask of every run
cfg.mask_only = false;           % the voxels of the mask (or atlas) as given, no brain mask
cfg.atlas = '';                  % atlas only: integer label image (MNI)
cfg.n_components = 10;           % computed (and aligned)
cfg.n_maps = 3;                  % written per run
cfg.sparsity = 0.9;              % share of each row set to 0
cfg.kernel = 'normalized_angle'; % 'normalized_angle', 'cosine' or 'none'
cfg.alpha = 0.5;                 % diffusion map anisotropy
cfg.align = 'group';             % 'group' (to the group-mean matrix), 'procrustes' or 'none'

cfg.qc_exclusions = true;         % leave out runs excluded in reports/qc_exclusions.tsv
v = seecat.util.validators;
spec = [
    {
    'pipeline',     @(x) isequal(x, 'gradient'),                  '''gradient'''
    'input_dir',    @(x) v.text(x) && exist(x, 'dir') == 7,       'an existing SeeCAT derivatives folder'
    'input',        @(x) v.text(x) && ~isempty(regexp(x, '^[a-zA-Z0-9]+$', 'once')), 'a desc label, e.g. denoised'
    'space',        v.text,                                        'empty or a space label'
    'res',          v.text,                                        'empty or a res label'
    'nodes',        v.oneof({'voxels', 'atlas'}),                  '''voxels'' or ''atlas'''
    'node_size',    @(x) isnumeric(x) && isscalar(x) && x >= 2 && x <= 12, 'a voxel size in mm, 2 to 12'
    'mask',         @(x) v.text(x) && (any(strcmp(x, {'gm', 'brain'})) || exist(x, 'file') == 2), '''gm'', ''brain'' or a mask file'
    'group_mask',   v.flag,                                        'true or false'
    'mask_only',    v.flag,                                        'true or false'
    'atlas',        @(x) v.text(x) && (isempty(x) || exist(x, 'file') == 2), 'empty or an atlas image'
    'n_components', @(x) v.count(x) && x >= 2 && x <= 50,         'an integer from 2 to 50'
    'n_maps',       @(x) v.count(x) && x >= 1,                     'a positive integer'
    'sparsity',     @(x) isnumeric(x) && isscalar(x) && x >= 0 && x < 1, 'a share in [0, 1)'
    'kernel',       v.oneof({'normalized_angle', 'cosine', 'none'}), '''normalized_angle'', ''cosine'' or ''none'''
    'alpha',        @(x) isnumeric(x) && isscalar(x) && x >= 0 && x <= 1, 'a number in [0, 1]'
    'align',        v.oneof({'group', 'procrustes', 'none'}),      '''group'', ''procrustes'' or ''none'''
    'qc_exclusions', v.flag, 'true or false'
    }
    spec];
end

function s = catstruct(a, b)
s = a;
for f = fieldnames(b)'
    s.(f{1}) = b.(f{1});
end
end
