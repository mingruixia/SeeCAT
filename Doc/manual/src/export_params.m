function export_params(out)
% EXPORT_PARAMS  Every form entry of every pipeline (label, batch field,
% default, section, help) as JSON, for the manual's parameter tables.
%   export_params('Doc/manual/src/params.json')
here = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(fullfile(here, 'SeeCAT'));
P = struct();
for p = {'prep', 'fmriprep', 'fc', 'degree', 'gradient', 'harmonize', 'stat'}
    F = feval(['seecat.' p{1} '.gui']);
    cfg = seecat.config(p{1});
    rows = struct('path', {}, 'label', {}, 'section', {}, 'advanced', {}, 'widget', {}, 'default', {}, 'help', {}, 'choices', {});
    for f = F
        v = cfg;
        for k = strsplit(f.path, '.')
            v = v.(k{1});
        end
        d = seecat.gui.format(v, f.widget);
        if isstruct(v) && isempty(fieldnames(v)), d = ''; end
        if isstruct(v) && ~isscalar(v), d = ''; end
        if islogical(v), d = char(string(v)); end
        ch = f.choices;
        if ~iscell(ch), ch = {}; end
        rows(end+1) = struct('path', f.path, 'label', f.label, 'section', f.section, 'advanced', f.advanced, ...
            'widget', f.widget, 'default', d, 'help', f.help, 'choices', {ch}); %#ok<AGROW>
    end
    P.(p{1}) = rows;
end
seecat.util.write_json(out, P);
end
