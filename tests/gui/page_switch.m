function problems = page_switch(qcFolder)
% PAGE_SWITCH  Visit every page of the launcher from every other page and
% use each one a little; report what goes wrong (needs a desktop session).
%   problems = page_switch('.../derivatives/seecat')   % a folder with QC reports
%
% Each switch must not raise an error, must leave the page with content,
% and must show the Load/Save/advanced controls exactly on pipeline pages
% (their handles must stay valid: a page's own variable once replaced the
% toolbar's Save button). On a pipeline page the config must still read
% back; on each page some controls are used: info icons, the advanced box,
% the folder of the QC and Data check pages.
if nargin < 1, qcFolder = ''; end
app = SeeCAT();
c = onCleanup(@() delete(app.fig));
names = {'Import to BIDS', 'Preprocessing', 'fMRIPrep denoising', 'Seed FC', 'Degree', 'Gradients', ...
    'Harmonize', 'Statistics', 'Viewer', 'Data check', 'QC reports'};
pipes = {'', 'prep', 'fmriprep', 'fc', 'degree', 'gradient', 'harmonize', 'stat', '', '', ''};
problems = {};
n = 0;
for a = 1:numel(names)
    for b = 1:numel(names)
        if a == b, continue, end
        for step = {names{a}, names{b}}
            k = find(strcmp(names, step{1}));
            try
                app.select(step{1});
                drawnow;
                use(app, step{1}, qcFolder);
                problems = [problems, check(app, step{1}, ~isempty(pipes{k}))]; %#ok<AGROW>
            catch err
                problems{end+1} = sprintf('%s -> %s: %s', names{a}, step{1}, err.message); %#ok<AGROW>
            end
        end
        n = n + 1;
    end
end
problems = unique(problems, 'stable');
fprintf('%d page switches, %d problem(s)\n', n, numel(problems));
for i = 1:numel(problems)
    fprintf('  %s\n', problems{i});
end
end

function p = check(app, name, isPipe)
p = {};
fig = app.fig;
btn = @(t) findall(fig, 'Type', 'uibutton', 'Text', t);
for t = {'Load', 'Save'}
    h = btn(t{1});
    if isempty(h) || ~all(isvalid(h))
        p{end+1} = sprintf('%s: toolbar button %s missing', name, t{1}); %#ok<AGROW>
    elseif any(strcmp({h.Visible}, 'on')) ~= isPipe
        p{end+1} = sprintf('%s: toolbar button %s visible = %d', name, t{1}, any(strcmp({h.Visible}, 'on'))); %#ok<AGROW>
    end
end
if isPipe
    try
        app.config();
    catch err
        p{end+1} = sprintf('%s: config: %s', name, err.message);
    end
end
host = findall(fig, 'Type', 'uipanel');
if isempty(host)
    p{end+1} = sprintf('%s: no content', name);
end
end

function use(app, name, qcFolder)
fig = app.fig;
im = findall(fig, 'Type', 'uiimage', 'Tooltip', 'About this option');
for i = 1:min(3, numel(im))
    if ~isempty(im(i).ImageClickedFcn), im(i).ImageClickedFcn(im(i), []); end
end
adv = findall(fig, 'Type', 'uicheckbox', 'Text', 'Show advanced options');
if ~isempty(adv) && strcmp(adv(1).Visible, 'on')
    adv(1).Value = ~adv(1).Value;
    adv(1).ValueChangedFcn(adv(1), []);
    drawnow;
end
if ~isempty(qcFolder) && any(strcmp(name, {'QC reports', 'Data check'}))
    ed = findall(fig, 'Type', 'uieditfield');
    ed = ed(arrayfun(@(e) strcmp(e.Visible, 'on') && ~isempty(e.ValueChangedFcn), ed));
    if ~isempty(ed)
        ed(1).Value = qcFolder;
        ed(1).ValueChangedFcn(ed(1), []);
        drawnow;
    end
end
end
