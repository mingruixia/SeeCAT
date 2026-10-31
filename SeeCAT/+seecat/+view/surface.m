function out = surface(m, i, png)
% SURFACE  Show layer i of a viewer model on the cortex in BrainNet Viewer 2.0.
%   seecat.view.surface(model, i)            % opens the BrainNet desktop app
%   out = seecat.view.surface(model, i, 'figure.png')   % renders with BrainNetRender
%
% Writes, next to the layer's file, <name>_surface.nii (the layer as the
% viewer shows it: thresholded, clusters filtered) and
% <name>_surface.scene.json: BrainNet's ICBM152 smoothed surface with that
% map projected onto it (threshold mode 'none', since the map is already
% thresholded; trilinear projection, so vertex values are interpolated and
% can lie below the threshold near cluster edges: read statistics from the
% viewer and the cluster table, not from surface colours). The scene
% reproduces the figure later. (Nearest-voxel projection keeps exact values
% but leaves 3 mm clusters patchy on the smoothed mesh.) Needs BrainNet Viewer 2.0 on the MATLAB path.

w = which('BrainNetViewer');
if isempty(w)
    error('SeeCAT:brainnet', 'BrainNet Viewer 2.0 is not on the MATLAB path (https://www.nitrc.org/projects/bnv/).');
end
root = fileparts(w);
src = fullfile(root, 'src', 'matlab', 'BrainNetViewer');
template = fullfile(root, 'docs', 'tutorials', 'assets', 'scenes', 'tutorial08-pcc-four-view.scene.json');
mesh = fullfile(src, 'Data', 'SurfTemplate', 'BrainMesh_ICBM152_smoothed.nv');
if ~exist(template, 'file') || ~exist(mesh, 'file')
    error('SeeCAT:brainnet', 'This BrainNet Viewer installation lacks the 2.0 scene template or the ICBM152 mesh.');
end
L = m.layers(i);
d = fileparts(L.file);
base = regexprep(L.name, '_statmap$|_bold$', '');
map = fullfile(d, [base '_surface.nii']);
seecat.io.write_nii(L.shown, L.hdr, map);

S = jsondecode(fileread(template));
S.name = ['SeeCAT: ' L.name];
S.coordinate_space = 'MNI';
S.redistribution_status = 'user-data';
S.inputs.surface.local_path = mesh;
S.inputs.surface.relative_path = 'Data/SurfTemplate/BrainMesh_ICBM152_smoothed.nv';
S.inputs.volume = struct('role', 'volume', 'relative_path', [base '_surface.nii'], 'local_path', map, ...
    'sha256', sha256(map), 'coordinate_space', 'MNI (SeeCAT)', 'source_uri', '', ...
    'redistribution_status', 'user-data', 'metadata', struct('source', L.file, ...
    'threshold', L.threshold, 'software', ['SeeCAT ' seecat.version()], ...
    'note', 'Thresholded in SeeCAT; surface values are trilinear interpolations of this map.'));
v = S.options.visualization_settings.volume;
v.threshold_mode = 'none';
v.map_algorithm = 5;                       % trilinear (BrainNet's default for statistics)
v.statistical_threshold = 0;
v.cluster_size = 0;
v.display_mode = 'both';
v.colormap = 'jet';
pos = L.shown(L.shown > 0);
neg = L.shown(L.shown < 0);
if isempty(neg)
    v.display_mode = 'positive';
    v.colormap = 'hot';
elseif isempty(pos)
    v.display_mode = 'negative';
end
S.options.visualization_settings.volume = v;
if isfield(S, 'metadata')
    S = rmfield(S, 'metadata');            % the template's camera/session belong to its own data
end
scene = fullfile(d, [base '_surface.scene.json']);
seecat.util.write_json(scene, S);
out = struct('map', map, 'scene', scene, 'png', '');

if nargin > 2 && ~isempty(png)
    BrainNetRender(scene, png, 'DataRoot', src, 'ComputeBackend', 'cpu', 'Overwrite', true);
    out.png = png;
else
    addpath(src);
    BrainNetViewer('Scene', brainnet.io.readScene(scene));
end
end

function h = sha256(f)
md = java.security.MessageDigest.getInstance('SHA-256');
fid = fopen(f, 'r');
md.update(fread(fid, Inf, '*uint8'));
fclose(fid);
h = lower(reshape(dec2hex(typecast(md.digest(), 'uint8'))', 1, []));
end
