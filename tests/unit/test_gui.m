function tests = test_gui
% Tests for the GUI's form descriptions and value conversion (headless; the
% windows themselves are checked by tests/gui/smoke.m on a desktop).
%   results = runtests('tests/unit/test_gui.m')
tests = functiontests(localfunctions);
end

function setupOnce(~)
addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'SeeCAT'));
end

function testEveryOptionIsInTheForm(tc)
% Options deliberately left to config files (not in the window)
batchOnly = struct('prep', {{}}, 'fmriprep', {{}}, 'fc', {{}}, 'degree', {{}}, 'gradient', {{}}, ...
    'harmonize', {{'sessions', 'task', 'runs', 'n_workers'}}, ...
    'stat', {{'sessions', 'task', 'runs', 'image_covariates'}});
for p = fieldnames(batchOnly)'
    cfg = seecat.config(p{1});
    opts = setdiff(leaves(cfg, ''), [{'pipeline'}, batchOnly.(p{1})]);
    F = feval(['seecat.' p{1} '.gui']);
    paths = {F.path};
    tc.verifyEmpty(setdiff(opts, paths), sprintf('%s: options missing from the form', p{1}));
    tc.verifyEmpty(setdiff(paths, leaves(cfg, '')), sprintf('%s: form entries that are not options', p{1}));
    tc.verifyEqual(numel(unique(paths)), numel(paths), sprintf('%s: duplicate form entries', p{1}));
end
end

function testPageFunctionsDoNotReuseWindowVariables(tc)
% Nested functions share the variables of the launcher: a page that assigns
% a name the window already uses replaces it (the QC page once replaced the
% toolbar's Save button, and leaving that page broke every other page).
f = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'SeeCAT', '+seecat', '+gui', 'launcher.m');
L = splitlines(fileread(f));
last = find(strcmp(L, 'end'), 1);                     % end of the launcher function itself
L = L(1:last);
top = {};
nested = struct('name', {}, 'vars', {});
for i = 2:numel(L)
    s = L{i};
    t = regexp(s, '^    function\s+(?:\[?[\w, ~]*\]?\s*=\s*)?(\w+)\(', 'tokens', 'once');
    if ~isempty(t)
        nested(end+1) = struct('name', t{1}, 'vars', {{}}); %#ok<AGROW>
        continue
    end
    a = regexp(s, '^(\s*)(\w+)\s*=[^=]', 'tokens', 'once');
    if isempty(a), continue, end
    if isempty(a{1})
        top{end+1} = a{2}; %#ok<AGROW>
    elseif numel(a{1}) >= 8 && ~isempty(nested)
        nested(end).vars{end+1} = a{2};
    end
end
for k = 1:numel(nested)
    clash = intersect(nested(k).vars, top);
    tc.verifyEmpty(clash, sprintf('%s assigns window variable(s): %s', nested(k).name, strjoin(clash, ', ')));
end
end

function testParseAndFormatRoundTrip(tc)
cases = {
    [0.01 0.1],                 'range'
    [-90 -126 -72; 90 90 108],  'text'
    [0 75 Inf],                 'text'
    {'01', '02'},               'labels'
    'auto',                     'text'
    6,                          'number'
    };
for i = 1:size(cases, 1)
    v = cases{i, 1};
    s = seecat.gui.format(v, cases{i, 2});
    tc.verifyEqual(seecat.gui.parse(s, cases{i, 2}, v), v, s);
end
tc.verifyEqual(seecat.gui.parse('3', 'text', 'auto'), 3);          % keyword option given a number
tc.verifyEqual(seecat.gui.parse('', 'range', [0.01 0.1]), []);     % empty band = no filter
m = seecat.gui.parse('desc=PCC, stat=z, suffix=connectivity', 'maps', struct());
tc.verifyEqual(m, struct('desc', 'PCC', 'stat', 'z', 'suffix', 'connectivity'));
tc.verifyEqual(seecat.gui.format(m, 'maps'), 'desc=PCC, stat=z, suffix=connectivity');
tc.verifyError(@() seecat.gui.parse('abc', 'number', 6), 'SeeCAT:gui');
end

function testMatlabScreenIsAMonitor(tc)
% The main window opens on one of the screens, quickly.
tic;
r = seecat.gui.matlab_screen();
tc.verifyLessThan(toc, 2);
tc.verifyTrue(ismember(r, get(groot, 'MonitorPositions'), 'rows'));
end

function p = leaves(s, prefix)
p = {};
for f = fieldnames(s)'
    v = s.(f{1});
    if isstruct(v) && isscalar(v) && ~isempty(fieldnames(v)) && ~strcmp(f{1}, 'maps')
        p = [p, leaves(v, [prefix f{1} '.'])]; %#ok<AGROW>
    else
        p{end+1} = [prefix f{1}]; %#ok<AGROW>
    end
end
end
