function record_output(manifest, output_dir, file)
% RECORD_OUTPUT  Note a derivative in the unit's output manifest.
%   seecat.util.record_output(unit.manifest, cfg.output_dir, file)
%
% Call it just before writing FILE (an absolute path under OUTPUT_DIR), so
% a partly written file is listed too. seecat.run deletes every listed file
% when the unit runs again or fails, so a failed unit never leaves
% derivatives behind, from this run or an earlier one. FILE may not be one
% of the unit's inputs (seecat.util.protected_inputs): writing over an
% input is refused before anything is written or listed.

root = seecat.util.canonical_path(output_dir);
[f, k] = seecat.util.canonical_path(file);
if ~startsWith(lower(f), lower([root filesep]))
    error('SeeCAT:output', 'Output %s is not under the output folder %s.', file, output_dir);
end
if ismember(k, seecat.util.protected_inputs())
    error('SeeCAT:output', ['Output %s is one of this unit''s input files; it was left as it is. ' ...
        'Choose another output folder.'], f);
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
