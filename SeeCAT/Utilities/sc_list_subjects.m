function names = sc_list_subjects(folder)
% SC_LIST_SUBJECTS  Names of subject sub-folders in FOLDER.
% Only directories are returned; hidden entries (., .., .DS_Store, .git ...)
% and plain files are skipped. Result is a column cell array, sorted.

names = cell(0, 1);
if ~exist(folder, 'dir')
    return
end
l = dir(folder);
l = l([l.isdir]);
l = l(~startsWith({l.name}, '.'));
names = sort({l.name})';
end
