function [cfg, spec] = defaults()
% DEFAULTS  Default configuration of seed-based functional connectivity.
%   [cfg, spec] = seecat.fc.defaults()
%
% Use seecat.config('fc'). Input is a SeeCAT derivatives folder (from the
% prep or fmriprep pipeline). For each run, each seed's mean series (voxels
% with signal) is correlated with every voxel of the subject brain mask,
% on the frames kept after censoring. Seeds are a struct array with a name
% (letters and digits) and either center (mm) + radius (mm), or file (a
% mask image):
%   cfg.seeds = struct('name', {'PCC', 'mPFC'}, 'center', {[0 -53 26], [0 52 -6]}, 'radius', 6);
% Spheres and masks mix; a mask row leaves center and radius empty:
%   cfg.seeds = struct('name', {'PCC', 'Hippo'}, 'center', {[0 -53 26], []}, ...
%       'radius', {6, []}, 'file', {'', 'D:/masks/hippocampus_L.nii'});

[cfg, spec] = seecat.util.common_defaults();
cfg = catstruct(struct('pipeline', 'fc', 'input_dir', ''), cfg);
cfg.input = 'denoised';      % desc of the input series, e.g. 'denoised' or 'denoisedSm6'
cfg.space = '';              % needed only when several spaces are present
cfg.res = '';                % res label, needed only when there are several
cfg.seeds = struct('name', {}, 'center', {}, 'radius', {}, 'file', {});
cfg.group_mask = false;      % only voxels in the brain mask of every run

cfg.qc_exclusions = true;         % leave out runs excluded in reports/qc_exclusions.tsv
v = seecat.util.validators;
spec = [
    {
    'pipeline',  @(x) isequal(x, 'fc'),                          '''fc'''
    'input_dir', @(x) v.text(x) && exist(x, 'dir') == 7,         'an existing SeeCAT derivatives folder'
    'input',     @(x) v.text(x) && ~isempty(regexp(x, '^[a-zA-Z0-9]+$', 'once')), 'a desc label, e.g. denoised'
    'space',     v.text,                                          'empty or a space label'
    'res',       v.text,                                          'empty or a res label'
    'seeds',     @validSeeds,                                     'a non-empty struct array of seeds: name + center + radius, or name + file'
    'group_mask', v.flag,                                         'true or false'
    'qc_exclusions', v.flag, 'true or false'
    }
    spec];
end

function ok = validSeeds(s)
ok = isstruct(s) && ~isempty(s) && isfield(s, 'name');
if ~ok
    return
end
for i = 1:numel(s)
    sphere = isfield(s, 'center') && isnumeric(s(i).center) && numel(s(i).center) == 3 && ...
        isfield(s, 'radius') && isnumeric(s(i).radius) && isscalar(s(i).radius) && s(i).radius > 0;
    file = isfield(s, 'file') && ischar(s(i).file) && exist(s(i).file, 'file') == 2;
    ok = ok && ischar(s(i).name) && ~isempty(regexp(s(i).name, '^[a-zA-Z0-9]+$', 'once')) && (sphere || file);
end
ok = ok && numel(unique(lower({s.name}))) == numel(s);   % file names: case is ignored on Windows
end

function s = catstruct(a, b)
s = a;
for f = fieldnames(b)'
    s.(f{1}) = b.(f{1});
end
end
