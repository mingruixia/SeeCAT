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
cfg.task       = '';      % empty = the only task present
cfg.runs       = {};
cfg.n_workers  = 0;       % 0 = serial; 'auto' = as many as the computer allows
cfg.overwrite  = false;
cfg.keep_work  = false;

v = seecat.util.validators;
spec = {
    'output_dir', v.text,    'a folder name'
    'work_dir',   v.text,    'a folder name'
    'subjects',   v.labels,  'a cell array of labels without "sub-"'
    'sessions',   v.labels,  'a cell array of labels without "ses-"'
    'task',       v.text,    'a task label'
    'runs',       v.labels,  'a cell array of run labels'
    'n_workers',  @(x) v.count(x) || (ischar(x) && strcmpi(x, 'auto')), 'a non-negative integer or ''auto'''
    'overwrite',  v.flag,    'true or false'
    'keep_work',  v.flag,    'true or false'
    };
end
