function v = validators()
% VALIDATORS  Value checks used in the config specs.
%   v = seecat.util.validators;  v.flag(true)  % -> true

v.flag    = @(x) isscalar(x) && (islogical(x) || (isnumeric(x) && any(x == [0 1])));
v.text    = @(x) ischar(x) && (isempty(x) || isrow(x));
v.labels  = @(x) iscellstr(x) && all(cellfun(@(s) ~isempty(s) && isempty(regexp(s, '[^A-Za-z0-9]', 'once')), x)); %#ok<ISCLSTR>
v.count   = @(x) isnumeric(x) && isscalar(x) && x >= 0 && x == round(x);
v.positive = @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x > 0;
v.nonneg  = @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x >= 0;
v.auto    = @(x) ischar(x) && strcmp(x, 'auto');
v.oneof   = @(opts) @(x) ischar(x) && any(strcmp(x, opts));
v.subset  = @(opts) @(x) iscellstr(x) && all(ismember(x, opts)); %#ok<ISCLSTR>
end
