function F = common(selection)
% COMMON  Form entries for the options every per-subject pipeline shares.
%   F = seecat.gui.common(true)    % with subject/session/task/run selection
F = seecat.gui.field('output_dir', 'Output folder', 'folder', 'Output', ...
    'help', 'Empty: the default next to the input (see the pipeline help)');
F(end+1) = seecat.gui.field('work_dir', 'Work folder', 'folder', 'Output', 'advanced', true, ...
    'help', 'Intermediate files; empty: next to the output folder');
if selection
    F(end+1) = seecat.gui.field('subjects', 'Subjects', 'labels', 'Selection', 'help', 'Labels without "sub-", comma separated; empty = all');
    F(end+1) = seecat.gui.field('sessions', 'Sessions', 'labels', 'Selection', 'advanced', true);
    F(end+1) = seecat.gui.field('task', 'Task', 'text', 'Selection', 'help', 'Empty: the only task present');
    F(end+1) = seecat.gui.field('runs', 'Runs', 'labels', 'Selection', 'advanced', true);
end
F(end+1) = seecat.gui.field('n_workers', 'Parallel workers', 'number', 'Run', 'help', '0 = serial');
F(end+1) = seecat.gui.field('overwrite', 'Overwrite finished units', 'flag', 'Run', 'advanced', true);
F(end+1) = seecat.gui.field('keep_work', 'Keep work files', 'flag', 'Run', 'advanced', true);
end
