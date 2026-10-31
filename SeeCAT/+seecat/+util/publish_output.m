function publish_output(src, rel, meta, opt)
% PUBLISH_OUTPUT  Put one derivative (and its JSON sidecar) in output_dir.
%   seecat.util.publish_output(src, rel, meta, opt)
%
% REL is the path under opt.output_dir (from seecat.bids.deriv_name). A
% .nii source is compressed in opt.work_dir first (so parallel units never
% share a temporary name); .nii.gz, .tsv and other files are copied. META,
% when not empty, is written next to it as .json. Both files are recorded
% in opt.manifest (seecat.util.record_output) before they are written.
% OPT fields: output_dir, work_dir, manifest.

dst = fullfile(opt.output_dir, rel);
json = regexprep(dst, '(\.nii\.gz|\.nii|\.tsv)$', '.json');
seecat.util.record_output(opt.manifest, opt.output_dir, dst);
if ~isempty(meta)
    seecat.util.record_output(opt.manifest, opt.output_dir, json);
end
d = fileparts(dst);
if ~exist(d, 'dir')
    mkdir(d);
end
if endsWith(src, '.nii') && endsWith(dst, '.nii.gz')
    tmp = fullfile(opt.work_dir, 'gz');
    if ~exist(tmp, 'dir')
        mkdir(tmp);
    end
    g = gzip(src, tmp);
    copyfile(g{1}, dst, 'f');
    delete(g{1});
else
    copyfile(src, dst, 'f');
end
if ~isempty(meta)
    seecat.util.write_json(json, meta);
end
end
