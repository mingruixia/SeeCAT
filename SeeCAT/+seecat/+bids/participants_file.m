function f = participants_file(root)
% PARTICIPANTS_FILE  participants.tsv that belongs to a derivatives folder.
%   f = seecat.bids.participants_file(derivatives_dir)
% The derivatives' own, the dataset's two levels up (bids/derivatives/x),
% or that of the dataset named in dataset_description.json
% (SourceDatasets); '' when there is none.
cand = {fullfile(root, 'participants.tsv'), fullfile(fileparts(fileparts(root)), 'participants.tsv')};
d = fullfile(root, 'dataset_description.json');
if exist(d, 'file')
    j = jsondecode(fileread(d));
    if isfield(j, 'SourceDatasets')
        s = j.SourceDatasets;
        if iscell(s), s = s{1}; end
        if isfield(s, 'URL') && startsWith(s.URL, 'file://')
            src = s.URL(8:end);
            cand = [cand, {fullfile(src, 'participants.tsv'), fullfile(fileparts(fileparts(src)), 'participants.tsv')}];
        end
    end
end
f = '';
for c = cand
    if exist(c{1}, 'file')
        f = c{1};
        return
    end
end
end
