function F = gui()
% GUI  Form description of group statistics.
f = @seecat.gui.field;
F = f('name', 'Analysis name', 'text', 'Input', 'help', 'Letters and digits; output in group/<name>/');
F(end+1) = f('input_dir', 'Derivatives folder', 'folder', 'Input');
F(end+1) = f('maps', 'Maps', 'maps', 'Input', 'help', 'Entities of the per-subject maps, e.g. desc=PCC, stat=z, suffix=connectivity');
F(end+1) = f('participants', 'participants.tsv', 'file', 'Input', 'advanced', true, 'help', 'Empty: found from the input');
F(end+1) = f('design', 'Design', 'choice', 'Model', 'choices', ...
    {'one_sample', 'two_sample', 'paired', 'anova1', 'anova1_rm', 'regression', 'custom'});
F(end+1) = f('factor', 'Factor', 'text', 'Model', 'help', 'Between: a participants column; within: an entity (ses, desc)');
F(end+1) = f('levels', 'Levels', 'labels', 'Model', 'help', 'In order, comma separated; empty: as found');
F(end+1) = f('regressors', 'Regressors', 'labels', 'Model', 'help', 'regression: participants columns (one model)');
F(end+1) = f('covariates', 'Covariates', 'labels', 'Model', 'help', 'participants columns');
F(end+1) = f('design_tsv', 'Design TSV', 'file', 'Model', 'advanced', true, 'help', 'custom design: path column + design columns');
F(end+1) = f('contrasts', 'Contrasts', 'contrasts', 'Model', 'advanced', true, 'help', 'Empty: the design''s defaults');
F(end+1) = f('variance', 'Variance', 'choice', 'Model', 'choices', {'auto', 'equal', 'unequal'}, 'advanced', true);
F(end+1) = f('mask', 'Mask', 'mask', 'Inference', 'help', sprintf([ ...
    'The voxels tested. Grey matter (gm): SeeCAT''s grey-matter mask; Whole brain (brain): no extra ' ...
    'mask; Mask file: your own NIfTI image in MNI space (voxels > 0). In every case only ' ...
    'voxels that are non-zero in every subject''s map are kept.']));
F(end+1) = f('inference', 'Correction', 'multi', 'Inference', 'choices', {'cluster_fwe', 'voxel_fwe', 'voxel_fdr'});
F(end+1) = f('cdt_p', 'Cluster-forming p', 'number', 'Inference');
F(end+1) = f('alpha', 'Alpha', 'number', 'Inference');
F(end+1) = f('two_tailed', 'Two-tailed (alpha/2 per T contrast)', 'flag', 'Inference');
F = [F, seecat.gui.common(false)];
F(end+1) = f('subjects', 'Subjects', 'labels', 'Input', 'advanced', true);
end
