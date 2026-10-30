function write_description(output_dir, source_dir)
% WRITE_DESCRIPTION  dataset_description.json of the SeeCAT derivatives.
%   seecat.bids.write_description(output_dir, bids_dir)
%
% Written once; an existing file is left alone so that several pipelines
% can share one derivatives folder.

f = fullfile(output_dir, 'dataset_description.json');
if exist(f, 'file')
    return
end
d.Name = 'SeeCAT outputs';
d.BIDSVersion = '1.10.0';
d.DatasetType = 'derivative';
g.Name = 'SeeCAT';
g.Version = seecat.version();
d.GeneratedBy = {g};
if nargin > 1 && ~isempty(source_dir)
    d.SourceDatasets = {struct('URL', ['file://' strrep(source_dir, '\', '/')])};
end
seecat.util.write_json(f, d);
end
