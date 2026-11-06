function src = make_nifti_demo(root, subjectFolder)
% MAKE_NIFTI_DEMO  A small synthetic NIfTI export, as scanner platforms write it.
%   make_nifti_demo('D:/data/test_seecat/nifti_demo', 'sub173_testname')
%
% One visit folder with series folders by kind (localizer, field_map,
% functional, anatomy_t1w), each image with a dcm2niix-style sidecar:
% localizers, two gradient-echo field map sets (magnitude echoes and a phase
% series), single-band references before rest and Alchemy, task runs, and a
% T1w written twice (ND and distortion-corrected). Images are tiny int16
% volumes (volume k holds the value k). The sidecars carry a made-up
% PatientName and birth date, to check that they stay out of BIDS.
% Used by tests/unit/test_nifti.m and the manual's screenshots. Needs SPM.
visit = fullfile(root, subjectFolder, '2026-10-13T11_09_18');
uid = '1.2.3.4.5';
base = struct('PatientName', 'Test^Person', 'PatientID', 'sub173', 'PatientBirthDate', '2008-04-10', ...
    'PatientSex', 'M', 'StudyInstanceUID', uid, 'Manufacturer', 'Siemens');
t = 0;
    function s(folder, num, desc, suffix, dim, nv, extra)
        t = t + 1;
        m = base;
        m.SeriesNumber = num;
        m.SeriesDescription = desc;
        m.ProtocolName = regexprep(desc, '_ND$', '');
        m.AcquisitionDateTime = sprintf('2026-10-13T11:%02d:00.000000', t);
        m.AcquisitionTime = sprintf('11:%02d:00.000000', t);
        for f = fieldnames(extra)'
            m.(f{1}) = extra.(f{1});
        end
        name = sprintf('%02d_%s', num, desc);
        file = fullfile(visit, folder, name, [name suffix '.nii.gz']);
        if nv > 1
            img4d(file, dim, nv);
        else
            img3d(file, dim, num);
        end
        sidecar(file, m);
    end
epi = struct('ScanningSequence', 'EP', 'MRAcquisitionType', '2D', 'ImageType', {{'ORIGINAL'; 'PRIMARY'; 'M'; 'ND'; 'MOSAIC'}}, ...
    'RepetitionTime', 0.75, 'SliceTiming', [0; 0.25; 0.5; 0.1], 'EchoTime', 0.03, 'PhaseEncodingDirection', 'j');
gre = @(e, te, type) struct('ScanningSequence', 'GR', 'MRAcquisitionType', '2D', 'ImageType', {type}, ...
    'EchoNumber', e, 'EchoTime', te, 'RepetitionTime', 0.589);
loc = struct('ScanningSequence', 'GR', 'MRAcquisitionType', '2D', 'ImageType', {{'ORIGINAL'; 'PRIMARY'; 'M'}});
s('localizer', 1, 'localizer1', '_i00001', [8 8 1], 1, loc);
s('localizer', 1, 'localizer1', '_i00002', [8 8 1], 1, loc);
s('field_map', 3, 'CCBD_BOLD_PA_fieldmap1', '_e1', [6 6 4], 1, gre(1, 0.00492, {'ORIGINAL'; 'PRIMARY'; 'M'; 'ND'}));
s('field_map', 3, 'CCBD_BOLD_PA_fieldmap1', '_e2', [6 6 4], 1, gre(2, 0.00738, {'ORIGINAL'; 'PRIMARY'; 'M'; 'ND'}));
s('field_map', 4, 'CCBD_BOLD_PA_fieldmap1', '_e2_ph', [6 6 4], 1, gre(2, 0.00738, {'ORIGINAL'; 'PRIMARY'; 'P'; 'ND'; 'PHASE'}));
s('functional', 5, 'CCBD_BOLD_PA_SB1', '', [6 6 4], 1, setfield(epi, 'RepetitionTime', 4)); %#ok<SFLD>
s('functional', 6, 'CCBD_BOLD_PA_REST1', '', [6 6 4], 20, epi);
s('functional', 7, 'Math_AI_trust1', '', [6 6 4], 20, epi);
s('functional', 8, 'Math_AI_trust2', '', [6 6 4], 20, epi);
s('field_map', 13, 'CCBD_BOLD_PA_fieldmap1', '_e1', [6 6 4], 1, gre(1, 0.00492, {'ORIGINAL'; 'PRIMARY'; 'M'; 'ND'}));
s('field_map', 13, 'CCBD_BOLD_PA_fieldmap1', '_e2', [6 6 4], 1, gre(2, 0.00738, {'ORIGINAL'; 'PRIMARY'; 'M'; 'ND'}));
s('field_map', 14, 'CCBD_BOLD_PA_fieldmap1', '_e2_ph', [6 6 4], 1, gre(2, 0.00738, {'ORIGINAL'; 'PRIMARY'; 'P'; 'ND'; 'PHASE'}));
s('functional', 15, 'CCBD_BOLD_PA_SB1', '', [6 6 4], 1, setfield(epi, 'RepetitionTime', 4)); %#ok<SFLD>
s('functional', 16, 'Alchemy', '', [6 6 4], 20, epi);
t1 = struct('ScanningSequence', 'GR\IR', 'MRAcquisitionType', '3D', 'RepetitionTime', 2.3, 'EchoTime', 0.002);
nd = t1;
nd.ImageType = {'ORIGINAL'; 'PRIMARY'; 'M'; 'ND'; 'NORM'};
dis = t1;
dis.ImageType = {'ORIGINAL'; 'PRIMARY'; 'M'; 'NORM'; 'DIS3D'; 'DIS2D'};
t = 30;
s('anatomy_t1w', 17, 'CCBD_T1ISO_MPR_ND', '', [8 8 8], 1, nd);
t = 30;
s('anatomy_t1w', 18, 'CCBD_T1ISO_MPR', '', [8 8 8], 1, dis);
s('functional', 19, 'IGT1', '', [6 6 4], 20, epi);
s('functional', 20, 'IGT2', '', [6 6 4], 20, epi);
src = root;
end

function img3d(file, dim, value)
img(file, dim, 1, value);
end

function img4d(file, dim, nv)
img(file, dim, nv, []);
end

function img(file, dim, nv, value)
% A small int16 image; volume k holds the value k (or VALUE for 3D)
[d, name, ext] = fileparts(file);
if ~exist(d, 'dir')
    mkdir(d);
end
gz = strcmp(ext, '.gz');
if gz
    file = fullfile(d, name);                    % write the .nii, then compress
end
analyze = endsWith(file, '.img');
vox = 3;
if prod(dim) >= 1e6
    vox = 1;
end
for k = 1:nv
    V = struct('fname', file, 'dim', dim, 'dt', [spm_type('int16') 0], 'mat', diag([vox vox vox 1]), ...
        'pinfo', [1; 0; 0], 'n', [k 1], 'descrip', 'test');
    if analyze
        V.dt = [spm_type('int16') 0];
    end
    if k == 1
        V = spm_create_vol(V);
    else
        V = spm_create_vol(V);
    end
    v = k;
    if ~isempty(value)
        v = value;
    end
    spm_write_vol(V, v * ones(dim));
end
if gz
    gzip(file, d);
    delete(file);
end
end

function sidecar(niiFile, m)
f = regexprep(niiFile, '(\.nii\.gz|\.nii)$', '.json');
seecat.util.write_json(f, m);
end

