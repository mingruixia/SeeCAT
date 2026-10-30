function [cfg, spec] = defaults()
% Test-only pipeline for seecat.run: three units, two steps each.
[cfg, spec] = seecat.util.common_defaults();
cfg.pipeline = 'demo';
cfg.value = 1;
cfg.fail_units = {};       % these units fail in step 2
v = seecat.util.validators;
spec = [spec; {
    'pipeline',   @(x) isequal(x, 'demo'), '''demo'''
    'value',      @isnumeric,              'a number'
    'fail_units', @iscellstr,              'a cell array of unit ids'
    }];
end
