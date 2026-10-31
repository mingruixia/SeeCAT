function [cfg, spec] = defaults()
% DEFAULTS  Default configuration of group statistics.
%   [cfg, spec] = seecat.stat.defaults()
%
% Use seecat.config('stat'). Design: Doc/design/stat.md. Example:
%   cfg.name = 'PCCzFC_SCHZvsCTL';
%   cfg.input_dir = '.../derivatives/seecat';
%   cfg.maps = struct('desc', 'PCC', 'stat', 'z', 'suffix', 'connectivity');
%   cfg.design = 'two_sample';  cfg.factor = 'diagnosis';  cfg.levels = {'CONTROL', 'SCHZ'};
%   cfg.covariates = {'age', 'gender'};

[cfg, spec] = seecat.util.common_defaults();
cfg = catstruct(struct('pipeline', 'stat', 'name', '', 'input_dir', ''), cfg);
cfg.maps = struct();               % entity selector of the per-subject maps (desc, stat, suffix, space, ...)
cfg.participants = '';             % participants.tsv; default: found from input_dir
cfg.design = 'one_sample';         % one_sample two_sample paired anova1 anova1_rm regression custom
cfg.factor = '';                   % between: participants column; within (paired, anova1_rm): an entity, e.g. 'ses' or 'desc'
cfg.levels = {};                   % levels of factor, in order (empty: as found)
cfg.regressors = {};               % regression: participants columns, one model (S8)
cfg.covariates = {};               % participants columns; numeric centred, text -> centred dummies
cfg.image_covariates = {};         % cell array of map selectors (structs like maps), fitted voxel-wise
cfg.design_tsv = '';               % custom: TSV with a 'path' column and the design columns
cfg.contrasts = struct('name', {}, 'type', {}, 'weights', {});   % empty: the design's defaults
cfg.variance = 'auto';             % 'auto' (unequal for anova1_rm), 'equal' or 'unequal' (S6)
cfg.mask = 'gm';                   % 'gm', 'brain' or a mask file; plus non-zero in every map (S4)
cfg.inference = {'cluster_fwe'};   % any of cluster_fwe, voxel_fwe, voxel_fdr; {} = maps only
cfg.cdt_p = 0.001;                 % cluster-forming threshold (uncorrected p)
cfg.alpha = 0.05;                  % FWE / FDR level
cfg.two_tailed = true;             % T contrasts tested at alpha/2 (the default pairs cover both sides)

v = seecat.util.validators;
designs = {'one_sample', 'two_sample', 'paired', 'anova1', 'anova1_rm', 'regression', 'custom'};
spec = [
    {
    'pipeline',          @(x) isequal(x, 'stat'),                          '''stat'''
    'name',              @(x) v.text(x) && ~isempty(regexp(x, '^[a-zA-Z0-9]+$', 'once')), 'a name of letters and digits'
    'input_dir',         @(x) v.text(x) && (isempty(x) || exist(x, 'dir') == 7), 'empty (custom design) or an existing derivatives folder'
    'maps',              @(x) isstruct(x) && isscalar(x),                   'a struct of entity selectors'
    'participants',      @(x) v.text(x) && (isempty(x) || exist(x, 'file') == 2), 'empty or a participants.tsv file'
    'design',            v.oneof(designs),                                  strjoin(designs, ', ')
    'factor',            v.text,                                            'a participants column or an entity'
    'levels',            @(x) iscellstr(x),                                 'a cell array of levels' %#ok<ISCLSTR>
    'regressors',        @(x) iscellstr(x),                                 'a cell array of participants columns' %#ok<ISCLSTR>
    'covariates',        @(x) iscellstr(x),                                 'a cell array of participants columns' %#ok<ISCLSTR>
    'image_covariates',  @(x) iscell(x) && all(cellfun(@(s) isstruct(s) && isscalar(s), x)), 'a cell array of map selectors'
    'design_tsv',        @(x) v.text(x) && (isempty(x) || exist(x, 'file') == 2), 'empty or a design TSV file'
    'contrasts',         @(x) isstruct(x) && (isempty(x) || all(isfield(x, {'name', 'type', 'weights'}))), 'a struct array with name, type, weights'
    'variance',          v.oneof({'auto', 'equal', 'unequal'}),             '''auto'', ''equal'' or ''unequal'''
    'mask',              @(x) v.text(x) && (any(strcmp(x, {'gm', 'brain'})) || exist(x, 'file') == 2), '''gm'', ''brain'' or a mask file'
    'inference',         @(x) iscellstr(x) && all(ismember(x, {'cluster_fwe', 'voxel_fwe', 'voxel_fdr'})), 'a subset of cluster_fwe, voxel_fwe, voxel_fdr' %#ok<ISCLSTR>
    'cdt_p',             @(x) isnumeric(x) && isscalar(x) && x > 0 && x < 1, 'a p value'
    'alpha',             @(x) isnumeric(x) && isscalar(x) && x > 0 && x < 1, 'a level in (0, 1)'
    'two_tailed',        v.flag,                                            'true or false'
    }
    spec];
end

function s = catstruct(a, b)
s = a;
for f = fieldnames(b)'
    s.(f{1}) = b.(f{1});
end
end
