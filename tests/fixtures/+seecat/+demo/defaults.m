function [cfg, spec] = defaults()
% Test-only pipeline for seecat.run: three units, two steps each.
[cfg, spec] = seecat.util.common_defaults();
cfg.pipeline = 'demo';
cfg.value = 1;
cfg.fail_units = {};       % these units fail in step 2
cfg.fail_after_output = {};  % these units fail after writing their derivative
cfg.input_file = '';       % a file every unit names as its input (resume tests)
v = seecat.util.validators;
spec = [spec; {
    'pipeline',   @(x) isequal(x, 'demo'), '''demo'''
    'value',      @isnumeric,              'a number'
    'fail_units', @iscellstr,              'a cell array of unit ids'
    'fail_after_output', @iscellstr,       'a cell array of unit ids'
    'input_file', @ischar,                 'a file name or empty'
    }];
end
