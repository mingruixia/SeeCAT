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
batchOnly = struct('prep', {{}}, 'fmriprep', {{}}, 'fc', {{}}, 'degree', {{}}, ...
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
