function record_output(manifest, output_dir, file)
% RECORD_OUTPUT  Note a derivative in the unit's output manifest.
%   seecat.util.record_output(unit.manifest, cfg.output_dir, file)
%
% Call it just before writing FILE (an absolute path under OUTPUT_DIR), so
% a partly written file is listed too. seecat.run deletes every listed file
% when the unit runs again or fails, so a failed unit never leaves
% derivatives behind, from this run or an earlier one.

root = char(java.io.File(output_dir).getCanonicalPath());
f = char(java.io.File(file).getCanonicalPath());
if ~startsWith(lower(f), lower([root filesep]))
    error('SeeCAT:output', 'Output %s is not under the output folder %s.', file, output_dir);
end
d = fileparts(manifest);
if ~exist(d, 'dir')
    mkdir(d);
end
fid = fopen(manifest, 'a', 'n', 'UTF-8');
if fid < 0
    error('SeeCAT:output', 'Cannot write the output manifest %s.', manifest);
end
fprintf(fid, '%s\n', strrep(f(numel(root) + 2:end), '\', '/'));
fclose(fid);
end
