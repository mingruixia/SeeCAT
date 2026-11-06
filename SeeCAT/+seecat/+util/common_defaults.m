function [cfg, spec] = common_defaults()
% COMMON_DEFAULTS  Fields shared by every per-subject pipeline.
%   [cfg, spec] = seecat.util.common_defaults()
%
% SPEC is an n x 3 cell array {field path, validator, expected}; see
% seecat.check_config.

cfg.output_dir = '';      % default: <bids_dir>/derivatives/seecat
cfg.work_dir   = '';      % default: <output_dir>/../seecat_work
cfg.subjects   = {};      % labels without "sub-"; empty = all
cfg.sessions   = {};
cfg.task       = '';      % a label or several ({'rest', 'nback'}); empty: see the pipeline
cfg.runs       = {};
cfg.n_workers  = 'auto';  % as many as memory and cores allow; 0 = serial
cfg.overwrite  = false;
cfg.keep_work  = false;

v = seecat.util.validators;
spec = {
    'output_dir', v.text,    'a folder name'
    'work_dir',   v.text,    'a folder name'
    'subjects',   v.labels,  'a cell array of labels without "sub-"'
    'sessions',   v.labels,  'a cell array of labels without "ses-"'
    'task',       @(x) v.text(x) || v.labels(x), 'a task label or a cell array of task labels'
    'runs',       v.labels,  'a cell array of run labels'
    'n_workers',  @(x) v.count(x) || (ischar(x) && strcmpi(x, 'auto')), 'a non-negative integer or ''auto'''
    'overwrite',  v.flag,    'true or false'
    'keep_work',  v.flag,    'true or false'
    };
end
