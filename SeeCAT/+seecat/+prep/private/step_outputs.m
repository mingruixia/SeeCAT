function ctx = step_outputs(ctx, opt, log)
% Write the final derivatives (.nii.gz with JSON sidecars) into output_dir,
% named by seecat.bids.deriv_name (Doc/design/batch-api.md, section 6).
% Anatomical derivatives are written by one unit per T1w (unit.write_anat),
% so parallel units never write the same file.

space = {'space', 'IXI549Space', 'res', seecat.util.number_label(opt.voxel_size)};
bold = ctx.files.bold_src;
src = bidsUri(bold, opt.bids_dir);
boldMeta = struct('RepetitionTime', ctx.tr, 'SkullStripped', false, 'Sources', {{src}});
if isfield(opt.meta, 'TaskName')
    boldMeta.TaskName = opt.meta.TaskName;
end
put = @(file, rel, meta) seecat.util.publish_output(file, rel, meta, ...
    struct('output_dir', opt.output_dir, 'work_dir', ctx.work_dir, 'manifest', opt.manifest));

put(ctx.files.wbold, name(bold, space{:}, 'desc', 'preproc'), boldMeta);
put(ctx.files.mask_brain, name(bold, space{:}, 'desc', 'brain', 'suffix', 'mask'), ...
    struct('Type', 'Brain', 'Sources', {{src}}));
put(ctx.files.confounds, name(bold, 'desc', 'confounds', 'suffix', 'timeseries', 'ext', '.tsv'), ctx.confounds_meta);
seecat.steps.publish_denoised(ctx, bold, space, boldMeta, opt);

xfmMeta = struct('Sources', {{src}}, 'Software', spm('Ver'));
if ~isempty(ctx.files.t1w)
    if opt.write_anat
        t1 = ctx.files.t1w_src;
        anat = struct('Sources', {{bidsUri(t1, opt.bids_dir)}});
        put(ctx.files.biascorr, name(t1, 'datatype', 'anat', 'desc', 'preproc', 'suffix', 'T1w'), anat);
        labels = {'GM', 'WM', 'CSF'};
        for k = 1:3
            put(ctx.files.(sprintf('c%d', k)), ...
                name(t1, 'datatype', 'anat', 'label', labels{k}, 'suffix', 'probseg'), anat);
        end
        anat.Software = spm('Ver');
        put(ctx.files.deform, name(t1, 'datatype', 'anat', 'from', 'T1w', 'to', 'IXI549Space', ...
            'mode', 'image', 'suffix', 'xfm'), anat);
    end
else
    put(ctx.files.deform, name(bold, 'from', 'boldref', 'to', 'IXI549Space', 'mode', 'image', 'suffix', 'xfm'), xfmMeta);
end
log('outputs: written to %s', opt.output_dir);
end

function rel = name(src, varargin)
rel = seecat.bids.deriv_name(src, varargin{:});
end

function u = bidsUri(f, root)
rel = strrep(f(numel(root) + 2:end), '\', '/');
u = ['bids:raw:' rel];
end
