function [cfg, spec] = defaults()
% DEFAULTS  Default configuration of multi-site harmonisation.
%   [cfg, spec] = seecat.config('harmonize')
%
% Input: per-subject maps in a SeeCAT derivatives folder (from Seed FC,
% Degree or Gradients), chosen by entities as in Statistics, and the site
% of each subject from participants.tsv. Output: the same maps harmonised,
% next to them, with the desc label extended by cfg.label (desc-PCC ->
% desc-PCCComBat), ready for Statistics. Example:
%   cfg = seecat.config('harmonize');
%   cfg.input_dir = '.../derivatives/seecat';
%   cfg.maps = struct('desc', 'PCC', 'stat', 'z');
%   cfg.site = 'site';  cfg.covariates = {'diagnosis', 'sex'};  cfg.nonlinear = {'age'};

[cfg, spec] = seecat.util.common_defaults();
cfg = catstruct(struct('pipeline', 'harmonize', 'input_dir', ''), cfg);
cfg.maps = struct();               % entity selector, as in Statistics
cfg.participants = '';             % participants.tsv; default: found from input_dir
cfg.site = 'site';                 % participants.tsv column with the site (scanner) of each subject
cfg.method = 'combat';             % combat combat_nonparam combat_noeb combat_mean combat_gam covbat lm
cfg.covariates = {};               % columns whose effects are kept (numbers: linear; text: categories)
cfg.nonlinear = {};                % numeric columns kept as smooth (spline) effects, e.g. age
cfg.spline_df = 3;                 % degrees of freedom of each spline
cfg.ref_site = '';                 % a site left unchanged (others mapped onto it); '' = none
cfg.covbat_var = 0.95;             % covbat: share of variance of the harmonised components
cfg.mask = 'gm';                   % voxels harmonised: 'gm', 'brain' or a mask file (and non-zero in every map)
cfg.label = 'ComBat';              % appended to the desc label of the outputs

v = seecat.util.validators;
methods = {'combat', 'combat_nonparam', 'combat_noeb', 'combat_mean', 'combat_gam', 'covbat', 'lm'};
spec = [
    {
    'pipeline',     @(x) isequal(x, 'harmonize'),                  '''harmonize'''
    'input_dir',    @(x) v.text(x) && exist(x, 'dir') == 7,        'an existing SeeCAT derivatives folder'
    'maps',         @(x) isstruct(x) && isscalar(x) && ~isempty(fieldnames(x)), 'a struct of entity selectors (e.g. desc and stat)'
    'participants', @(x) v.text(x) && (isempty(x) || exist(x, 'file') == 2), 'empty or a participants.tsv file'
    'site',         @(x) v.text(x) && ~isempty(x),                  'a participants.tsv column'
    'method',       v.oneof(methods),                               strjoin(methods, ', ')
    'covariates',   @(x) iscellstr(x),                              'a cell array of participants columns' %#ok<ISCLSTR>
    'nonlinear',    @(x) iscellstr(x),                              'a cell array of numeric participants columns' %#ok<ISCLSTR>
    'spline_df',    @(x) v.count(x) && x >= 1 && x <= 10,           'an integer from 1 to 10'
    'ref_site',     v.text,                                         'empty or a site'
    'covbat_var',   @(x) isnumeric(x) && isscalar(x) && x > 0 && x <= 1, 'a share in (0, 1]'
    'mask',         @(x) v.text(x) && (any(strcmp(x, {'gm', 'brain'})) || exist(x, 'file') == 2), '''gm'', ''brain'' or a mask file'
    'label',        @(x) v.text(x) && ~isempty(regexp(x, '^[a-zA-Z0-9]+$', 'once')), 'letters and digits'
    }
    spec];
end

function s = catstruct(a, b)
s = a;
for f = fieldnames(b)'
    s.(f{1}) = b.(f{1});
end
end
