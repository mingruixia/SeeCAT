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
        vol = tissueVolumes(ctx.files);             % mL, from the native maps
        for k = 1:3
            m = anat;
            m.VolumeML = vol(k);
            if k == 1
                m.TissueVolumesML = struct('GM', vol(1), 'WM', vol(2), 'CSF', vol(3), 'TIV', sum(vol));
            end
            put(ctx.files.(sprintf('c%d', k)), ...
                name(t1, 'datatype', 'anat', 'label', labels{k}, 'suffix', 'probseg'), m);
        end
        if isfield(ctx.files, 'vbm1')               % VBM maps, normalised (and smoothed)
            desc = 'warped';
            if opt.vbm.modulated, desc = 'modulated'; end
            for k = 1:3
                f = ctx.files.(sprintf('vbm%d', k));
                Vv = spm_vol(f);
                res = seecat.util.number_label(round(mean(sqrt(sum(Vv.mat(1:3, 1:3) .^ 2))), 2));
                m = anat;
                m.Description = sprintf('%s %s probability in IXI549Space (SPM segmentation)', desc, labels{k});
                m.Modulated = opt.vbm.modulated;
                m.TIV_ML = sum(vol);
                sp = {'datatype', 'anat', 'space', 'IXI549Space', 'res', res, 'label', labels{k}, 'suffix', 'probseg'};
                put(f, name(t1, sp{:}, 'desc', desc), m);
                if any(opt.vbm.fwhm > 0)
                    fs = fullfile(ctx.work_dir, sprintf('s%s_%d.nii', desc, k));
                    spm_smooth(f, fs, opt.vbm.fwhm);
                    m.SmoothingFWHM = opt.vbm.fwhm;
                    put(fs, name(t1, sp{:}, 'desc', [desc 'Sm' seecat.util.number_label(opt.vbm.fwhm)]), m);
                end
            end
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

function v = tissueVolumes(files)
% GM, WM, CSF in mL: sum of the native probability maps times the voxel volume
v = zeros(1, 3);
for k = 1:3
    [p, V] = seecat.io.read_nii(files.(sprintf('c%d', k)));
    v(k) = sum(double(p(:))) * abs(det(V(1).mat(1:3, 1:3))) / 1000;
end
end
