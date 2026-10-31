function run_legacy_baseline(stage, varargin)
% RUN_LEGACY_BASELINE  Drive the legacy SeeCAT 1.0 GUIs headlessly to produce
% reference outputs on public test data (OpenNeuro ds000030 subset).
%
%   run_legacy_baseline('prep')   % preprocessing, T1-segment route, scrubbing on
%   run_legacy_baseline('fc')     % seed FC (PCC sphere) on FunImgARWSDCF
%   run_legacy_baseline('voxdeg') % voxel-wise degree on FunImgARWSDCF
%   run_legacy_baseline('stat')   % two-sample t-test CONTROL vs SCHZ on zFC
%
% Name-value options:
%   'WorkDir'  legacy-layout working directory (default D:/data/SeeCAT_baseline/ds000030)
%   'Parallel' 0/1 (default 1)
%
% The legacy code is driven through its own GUIDE callbacks so that the
% baseline reflects exactly what a user clicking RUN would get.

p = inputParser;
p.addParameter('WorkDir', 'D:/data/SeeCAT_baseline/ds000030');
p.addParameter('Parallel', 1);
p.addParameter('SliceOrder', 1);   % index into SliceTiming_popupmenu
% Code under test. Default: the untouched legacy export, so baselines are not
% affected by work-in-progress edits in the repository.
p.addParameter('CodeDir', 'D:/data/SeeCAT_baseline/legacy_code/SeeCAT');
p.parse(varargin{:});
opt = p.Results;

seecatRoot = opt.CodeDir;
addpath(genpath(seecatRoot));
spmDir = 'D:/verysync/dropbox/SciTools/MatlabToolbox/spm';
addpath(spmDir);
spm('defaults', 'fmri');
spm_jobman('initcfg');

oldDir = pwd;
cleanup = onCleanup(@() cd(oldDir));
cd(opt.WorkDir);
subs = list_subjects(fullfile(opt.WorkDir, 'FunImg'));

switch lower(stage)
    case 'prep'
        h = SeeCAT_PrepfMRI;
        set(h, 'Visible', 'off');
        H = guidata(h);
        set(H.WorkDir_edit, 'String', opt.WorkDir);
        set(H.StartFolder_edit, 'String', 'FunImg');
        set(H.SubList_listbox, 'String', subs, 'Value', 1);
        set(H.TR_edit, 'String', '2');
        set(H.DICOMtoNIFTI_checkbox, 'Value', 0);
        set(H.RemoveTPS_checkbox, 'Value', 1);
        set(H.RemoveTPS_edit, 'String', '5');
        set(H.SliceTiming_checkbox, 'Value', 1);
        set(H.SliceTiming_popupmenu, 'Value', opt.SliceOrder);
        set(H.Realign_checkbox, 'Value', 1);
        set(H.Normalize_checkbox, 'Value', 1);
        set(H.Normalize_popupmenu, 'Value', 2);          % T1 Segment
        set(H.Normalize_edit, 'String', '3 3 3');
        set(H.Smooth_checkbox, 'Value', 1);
        set(H.Smooth_edit, 'String', '6 6 6');
        set(H.Detrend_checkbox, 'Value', 1);
        set(H.Regress_checkbox, 'Value', 1);
        set(H.RegHM_checkbox, 'Value', 1);
        set(H.RegHM_popupmenu, 'Value', 2);              % Friston-24
        set(H.RegWM_checkbox, 'Value', 1);
        set(H.RegCSF_checkbox, 'Value', 1);
        set(H.RegGS_checkbox, 'Value', 0);
        set(H.Filter_checkbox, 'Value', 1);
        set(H.FilterLow_edit, 'String', '0.01');
        set(H.FilterHigh_edit, 'String', '0.1');
        set(H.Scrubbing_checkbox, 'Value', 1);
        set(H.ScrubbingThr_edit, 'String', '0.5');
        set(H.ScrubbingBefore_edit, 'String', '1');
        set(H.ScrubbingAfter_edit, 'String', '2');
        set(H.Scrubbing_popupmenu, 'Value', 3);          % Linear
        set(H.Parallel_checkbox, 'Value', opt.Parallel);
        SeeCAT_PrepfMRI('Run_pushbutton_Callback', H.Run_pushbutton, [], H);
        delete(h);

    case 'fc'
        h = SeeCAT_FuncConnect;
        set(h, 'Visible', 'off');
        H = guidata(h);
        set(H.WorkDir_edit, 'String', opt.WorkDir);
        set(H.StartFolder_edit, 'String', 'FunImgARWSDCF');
        set(H.Seed_listbox, 'String', {'Sphere: 0  -53   26   6'; 'Sphere: 0   52   -6   6'}, 'Value', 1);
        set(H.Mask_edit, 'String', gmMask(seecatRoot));
        set(H.Parallel_checkbox, 'Value', opt.Parallel);
        SeeCAT_FuncConnect('Run_pushbutton_Callback', H.Run_pushbutton, [], H);
        delete(h);

    case 'voxdeg'
        h = SeeCAT_VoxDeg;
        set(h, 'Visible', 'off');
        H = guidata(h);
        set(H.WorkDir_edit, 'String', opt.WorkDir);
        set(H.StartFolder_edit, 'String', 'FunImgARWSDCF');
        set(H.Mask_edit, 'String', gmMask(seecatRoot));
        set(H.Threshold_edit, 'String', '0.2');
        set(H.Local_checkbox, 'Value', 0);
        set(H.Positive_checkbox, 'Value', 1);
        set(H.Absolute_checkbox, 'Value', 0);
        set(H.Negative_checkbox, 'Value', 0);
        set(H.Degree_checkbox, 'Value', 1);
        set(H.Strength_checkbox, 'Value', 1);
        set(H.Distance_checkbox, 'Value', 0);
        set(H.Normalize_checkbox, 'Value', 1);
        set(H.Smooth_checkbox, 'Value', 0);
        set(H.Parallel_checkbox, 'Value', opt.Parallel);
        SeeCAT_VoxDeg('Run_pushbutton_Callback', H.Run_pushbutton, [], H);
        delete(h);

    case 'stat'
        % Two-sample t-test on zFC of seed 01, CONTROL (sub-1xxxx) vs SCHZ (sub-5xxxx).
        % The Stat GUI keeps its file lists in handles; call its compute path
        % through a minimal handles struct.
        fcDir = fullfile(opt.WorkDir, 'Results', 'FC_FunImgARWSDCF', 'zFC_Seed01');
        f = dir(fullfile(fcDir, '*.nii'));
        names = fullfile(fcDir, {f.name})';
        g1 = names(contains(names, 'sub-1'));
        g2 = names(contains(names, 'sub-5'));
        outDir = fullfile(opt.WorkDir, 'Results', 'Stat');
        if ~exist(outDir, 'dir'), mkdir(outDir); end
        h = SeeCAT_Stat;
        set(h, 'Visible', 'off');
        H = guidata(h);
        set(H.TypeListbox, 'Value', 2);
        SeeCAT_Stat('TypeListbox_Callback', H.TypeListbox, [], H);
        H = guidata(h);
        H.SampleCells = {g1; g2};
        set(H.SampleListbox, 'String', {'G1'; 'G2'});
        set(H.MaskEntry, 'String', gmMask(seecatRoot));
        set(H.OutputDirEntry, 'String', outDir);
        set(H.PrefixEntry, 'String', 'T2_zFCSeed01_CONvsSCHZ');
        guidata(h, H);
        SeeCAT_Stat('ComputeButton_Callback', H.ComputeButton, [], H);
        delete(h);

    otherwise
        error('Unknown stage %s', stage);
end
end

function subs = list_subjects(d)
l = dir(d);
l = l([l.isdir] & ~startsWith({l.name}, '.'));
subs = {l.name}';
end

function f = gmMask(root)
% SeeCAT 1.0's grey-matter mask; the repository has the TPM-based one since
% the DPABI masks were removed (seecat.util.make_templates)
f = fullfile(root, 'templates', 'GreyMask_02_61x73x61.nii');
if ~exist(f, 'file')
    f = fullfile(root, 'templates', 'tpl-IXI549Space_res-3_label-GM_mask.nii');
end
end
