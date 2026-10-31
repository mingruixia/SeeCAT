classdef Model < handle
% MODEL  State and logic of the SeeCAT viewer, without graphics.
%   m = seecat.view.Model();
%   m.addLayer('..._stat-t_statmap.nii.gz');     % underlay chosen by its space (G5)
%   m.setThreshold(1, struct('mode', 'p', 'value', 0.001, 'correction', 'cluster_fwe'));
%   rgb = m.slice('axial');                       % RGB image at the cursor
%   T = m.clusters(1);                            % SPM-style table with atlas labels
%
% Display grid: axis-aligned, at the underlay's voxel size, so slices are
% plain array cuts (neurological or radiological). Statistics are always
% computed on each layer's own grid with seecat.stat.inference, so the
% viewer and the stat pipeline agree; the result is only sampled onto the
% display grid for drawing.

    properties
        cursor = [0 0 0]                 % mm
        radiological = false             % false: left on the left (G6)
        underlay = struct()              % name, file, img (display grid)
        layers = struct('name', {}, 'file', {}, 'data', {}, 'hdr', {}, 'stat', {}, ...
            'threshold', {}, 'colormap', {}, 'alpha', {}, 'visible', {}, 'frame', {}, ...
            'shown', {}, 'index', {}, 'result', {})
        grid = struct()                  % dim, mat (display grid, axis aligned)
        atlases = struct([])
    end

    methods
        function m = Model(underlay)
            if nargin < 1
                underlay = 'ch2';
            end
            m.setUnderlay(underlay);
        end

        %% Underlay and layers --------------------------------------------
        function setUnderlay(m, which_)
            % 'ch2', 'ch2better', 'mni2009c', 'avg152T1', 'single_subj_T1', or a file
            files = underlayFiles();
            if isfield(files, which_)
                f = files.(which_);
                name = which_;
            else
                f = which_;
                [~, name] = fileparts(regexprep(f, '\.gz$', ''));
            end
            [vol, V] = seecat.io.read_nii(f, 'Volumes', 1);
            m.grid = axisGrid(V(1));
            m.underlay = struct('name', name, 'file', f, 'img', resample(vol, V(1), m.grid, 1));
            for i = 1:numel(m.layers)
                m.layers(i).index = nearestIndex(m.layers(i).hdr, m.grid);
                m.refresh(i);
            end
        end

        function i = addLayer(m, file)
            [Y, V] = seecat.io.read_nii(file, 'Class', 'single');
            hdr = V(1);
            [~, name] = fileparts(regexprep(file, '\.nii(\.gz)?$', ''));
            if isempty(m.layers)
                sp = regexp(name, 'space-([a-zA-Z0-9]+)', 'tokens', 'once');
                if ~isempty(sp) && strcmp(sp{1}, 'MNI152NLin2009cAsym')
                    m.setUnderlay('mni2009c');
                end
            end
            L.name = name;
            L.file = file;
            L.data = Y;
            L.hdr = hdr;
            L.stat = statInfo(file, hdr, Y(:, :, :, 1));
            L.threshold = struct('mode', 'stat', 'value', defaultThreshold(L.stat, Y), 'sign', 'both', ...
                'k', 0, 'correction', 'none', 'alpha', 0.05, 'cdt_p', 0.001);
            L.colormap = 'auto';
            L.alpha = 1;
            L.visible = true;
            L.frame = 1;
            L.shown = [];
            L.index = nearestIndex(hdr, m.grid);
            L.result = struct();
            m.layers(end+1) = L;
            i = numel(m.layers);
            m.refresh(i);
            if i == 1                                 % start at the strongest shown voxel
                sh = m.layers(i).shown;
                [~, k] = max(abs(sh(:)));
                if ~isempty(k) && sh(k) ~= 0
                    [a, b, c] = ind2sub(size(sh), k);
                    m.cursor = (hdr.mat(1:3, :) * [a; b; c; 1])';
                end
            end
        end

        function removeLayer(m, i)
            m.layers(i) = [];
        end

        function setThreshold(m, i, t)
            for f = fieldnames(t)'
                m.layers(i).threshold.(f{1}) = t.(f{1});
            end
            m.refresh(i);
        end

        function setFrame(m, i, k)
            m.layers(i).frame = max(1, min(k, size(m.layers(i).data, 4)));
            m.refresh(i);
        end

        %% Thresholding ----------------------------------------------------
        function refresh(m, i)
            % Apply layer i's threshold on its own grid
            L = m.layers(i);
            y = double(L.data(:, :, :, L.frame));
            t = L.threshold;
            s = L.stat;
            mask = y ~= 0 & isfinite(y);
            keep = false(size(y));
            R = struct('height', [], 'extent', t.k, 'tables', {{}});
            signs = {};
            if any(strcmp(t.sign, {'pos', 'both'})), signs{end+1} = 1; end
            if any(strcmp(t.sign, {'neg', 'both'})), signs{end+1} = -1; end
            for sg = signs
                v = sg{1} * y;
                if isempty(s.type) || strcmp(t.correction, 'none')
                    u = t.value;
                    if strcmp(t.mode, 'p') && ~isempty(s.type)
                        p = t.value;
                        if strcmp(t.sign, 'both') && s.type ~= 'F'
                            p = p / 2;
                        end
                        u = spm_u(p, s.df, s.type);
                    end
                    kv = v >= u & mask;
                    lab = label18(kv);
                    if t.k > 1
                        sz = accumarray(lab(lab > 0), 1);
                        kv = kv & ismember(lab, find(sz >= t.k));
                    end
                    tab = table();
                else
                    alpha = t.alpha;
                    if strcmp(t.sign, 'both') && s.type ~= 'F'
                        alpha = alpha / 2;
                    end
                    c = statStruct(v(mask), s);
                    I = seecat.stat.inference(c, mask, L.hdr, s.S, struct('method', t.correction, ...
                        'alpha', alpha, 'cdt_p', t.cdt_p));
                    u = I.height;
                    kv = I.label > 0;
                    if t.k > 1
                        sz = accumarray(I.label(I.label > 0), 1);
                        kv = kv & ismember(I.label, find(sz >= t.k));
                    end
                    tab = I.table;
                    tab.peak_stat = sg{1} * tab.peak_stat;
                end
                keep = keep | kv;
                R.height(end+1) = sg{1} * u;
                R.tables{end+1} = tab;
            end
            shown = zeros(size(y));
            shown(keep) = y(keep);
            m.layers(i).shown = shown;
            m.layers(i).result = R;
        end

        function T = clusters(m, i)
            % Clusters of layer i (SPM-style rows) with atlas labels at each peak
            L = m.layers(i);
            y = L.shown;
            T = table();
            lab = label18(y ~= 0);
            n = max(lab(:));
            rows = {};
            for c = 1:n
                in = find(lab == c);
                [~, k] = max(abs(y(in)));
                [a, b, d] = ind2sub(size(y), in(k));
                mm = L.hdr.mat(1:3, :) * [a; b; d; 1];
                rows(end+1, :) = {c, numel(in), y(in(k)), mm(1), mm(2), mm(3), m.labelAt(mm')}; %#ok<AGROW>
            end
            if ~isempty(rows)
                T = cell2table(rows, 'VariableNames', {'cluster', 'voxels', 'peak', 'x', 'y', 'z', 'label'});
                T = sortrows(T, 'voxels', 'descend');
            end
        end

        %% Cursor, values and labels ----------------------------------------
        function v = valuesAt(m, mm)
            if nargin < 2, mm = m.cursor; end
            v = nan(1, numel(m.layers));
            for i = 1:numel(m.layers)
                L = m.layers(i);
                vox = round(L.hdr.mat \ [mm(:); 1]);
                if all(vox(1:3)' >= 1 & vox(1:3)' <= size(L.data, 1:3))
                    v(i) = L.data(vox(1), vox(2), vox(3), L.frame);
                end
            end
        end

        function s = labelAt(m, mm)
            % Label of each available atlas at MM ('' outside every atlas)
            if isempty(m.atlases)
                m.atlases = seecat.view.atlases();
            end
            parts = {};
            for a = m.atlases(:)'
                vox = round(a.mat \ [mm(:); 1]);
                if all(vox(1:3)' >= 1 & vox(1:3)' <= size(a.vol, 1:3))
                    k = a.vol(vox(1), vox(2), vox(3));
                    if k > 0 && isKey(a.names, k)
                        parts{end+1} = sprintf('%s: %s', a.name, a.names(k)); %#ok<AGROW>
                    end
                end
            end
            s = strjoin(parts, '; ');
        end

        function ts = timeSeries(m, i, mm)
            if nargin < 3, mm = m.cursor; end
            L = m.layers(i);
            vox = round(L.hdr.mat \ [mm(:); 1]);
            ts = squeeze(L.data(vox(1), vox(2), vox(3), :));
        end

        %% Images -------------------------------------------------------------
        function [rgb, pos] = slice(m, view, mm)
            % RGB image of 'axial', 'coronal' or 'sagittal' through MM (default
            % the cursor), and the cursor's pixel position [col row]
            if nargin < 3, mm = m.cursor; end
            v = round(m.grid.mat \ [mm(:); 1]);
            v = max(1, min(v(1:3)', m.grid.dim));
            base = cut(m.underlay.img, view, v);
            lim = robustLimits(m.underlay.img);
            g = min(max((base - lim(1)) / max(diff(lim), eps), 0), 1);
            rgb = repmat(g, 1, 1, 3);
            for i = 1:numel(m.layers)
                L = m.layers(i);
                if ~L.visible || isempty(L.shown), continue, end
                d = zeros(m.grid.dim);
                ok = L.index > 0;
                d(ok) = L.shown(L.index(ok));
                s = cut(d, view, v);
                rgb = overlay(rgb, s, L);
            end
            [r, c] = cutPos(view, v, m.grid.dim);
            pos = [c r];
            if m.radiological && ~strcmp(view, 'sagittal')
                rgb = flip(rgb, 2);
                pos(1) = size(rgb, 2) - pos(1) + 1;
            end
        end

        function mm = mmAt(m, view, pos)
            % World coordinate of pixel POS = [col row] of SLICE(VIEW): the inverse of slice
            v = round(m.grid.mat \ [m.cursor(:); 1]);
            v = v(1:3)';
            d = m.grid.dim;
            c = round(pos(1));
            r = round(pos(2));
            if m.radiological && ~strcmp(view, 'sagittal')
                c = d(1) - c + 1;
            end
            switch view
                case 'axial'
                    v(1) = c; v(2) = d(2) - r + 1;
                case 'coronal'
                    v(1) = c; v(3) = d(3) - r + 1;
                case 'sagittal'
                    v(2) = c; v(3) = d(3) - r + 1;
            end
            v = max(1, min(v, d));
            mm = (m.grid.mat(1:3, :) * [v(:); 1])';
        end

        function rgb = montage(m, view, n)
            % N slices of VIEW spread over the brain, in one image
            if nargin < 3, n = 8; end
            dimIdx = struct('sagittal', 1, 'coronal', 2, 'axial', 3).(view);
            nz = find(any(any(m.underlay.img > 0, otherDims(dimIdx, 1)), otherDims(dimIdx, 2)));
            pos = round(linspace(nz(1) + 0.2 * numel(nz), nz(end) - 0.15 * numel(nz), n));
            tiles = cell(1, n);
            for k = 1:n
                v = round(m.grid.mat \ [m.cursor(:); 1]);
                v(dimIdx) = pos(k);
                mm = m.grid.mat(1:3, :) * [v(1:3); 1];
                tiles{k} = m.slice(view, mm');
            end
            rgb = cat(2, tiles{:});
        end

        function saveShown(m, i, file)
            % The thresholded map of layer i, on its own grid
            seecat.io.write_nii(m.layers(i).shown, m.layers(i).hdr, file);
        end
    end
end

%% ---- local functions -------------------------------------------------------

function f = underlayFiles()
here = fileparts(fileparts(fileparts(mfilename('fullpath'))));
t = fullfile(here, 'templates');
f = struct('ch2', pick(t, 'ch2'), 'ch2better', pick(t, 'ch2better'), ...
    'mni2009c', pick(t, 'mni_icbm152_t1_tal_nlin_asym_09c'), ...
    'avg152T1', fullfile(spm('dir'), 'canonical', 'avg152T1.nii'), ...
    'single_subj_T1', fullfile(spm('dir'), 'canonical', 'single_subj_T1.nii'));
end

function p = pick(d, n)
p = fullfile(d, [n '.nii.gz']);
if ~exist(p, 'file')
    p = fullfile(d, [n '.nii']);
end
end

function G = axisGrid(V)
% Axis-aligned grid covering V, at V's voxel size
vox = sqrt(sum(V.mat(1:3, 1:3) .^ 2));
c = [1 1 1; V.dim];
corners = zeros(3, 8);
k = 0;
for a = 1:2, for b = 1:2, for d = 1:2
    k = k + 1;
    corners(:, k) = V.mat(1:3, :) * [c(a, 1); c(b, 2); c(d, 3); 1];
end, end, end
lo = min(corners, [], 2)';
hi = max(corners, [], 2)';
G.dim = round((hi - lo) ./ vox) + 1;
G.mat = [diag(vox), lo' - vox'; 0 0 0 1];
end

function img = resample(vol, V, G, interp)
[i, j, k] = ndgrid(1:G.dim(1), 1:G.dim(2), 1:G.dim(3));
src = V.mat \ G.mat * [i(:) j(:) k(:) ones(numel(i), 1)]';
img = reshape(spm_sample_vol(double(vol), src(1, :), src(2, :), src(3, :), interp), G.dim);
img(~isfinite(img)) = 0;
end

function idx = nearestIndex(V, G)
% Linear index into V's volume for each display voxel (0 = outside)
[i, j, k] = ndgrid(1:G.dim(1), 1:G.dim(2), 1:G.dim(3));
src = round(V.mat \ G.mat * [i(:) j(:) k(:) ones(numel(i), 1)]');
ok = all(src(1:3, :) >= 1 & src(1:3, :) <= V.dim(:), 1);
idx = zeros(G.dim, 'uint32');
idx(ok) = sub2ind(V.dim, src(1, ok), src(2, ok), src(3, ok));
end

function s = statInfo(file, hdr, y)
% Statistic type, df and smoothness from the JSON sidecar (SeeCAT stat) or
% the 1.0 header string; empty type for maps without a statistic
s = struct('type', '', 'df', [], 'S', struct());
j = regexprep(file, '\.nii(\.gz)?$', '.json');
if exist(j, 'file')
    J = jsondecode(fileread(j));
    if isfield(J, 'Statistic') && any(strcmp(J.Statistic, {'T', 'F'}))
        s.type = J.Statistic;
        s.df = J.DegreesOfFreedom(:)';
        if s.type == 'T', s.df = [1 s.df(end)]; end
        if isfield(J, 'Resels') && isfield(J, 'FWHMvoxels')
            s.S = struct('R', J.Resels(:)', 'FWHM', J.FWHMvoxels(:)', ...
                'V2R', 1 / prod(J.FWHMvoxels), 'nVox', J.SearchVoxels);
        end
        return
    end
end
d = hdr.descrip;
% (the df list is captured whole: MATLAB drops unmatched optional tokens)
t = regexp(d, 'CAT\{([TF])_\[([\d.,]+)\]\}\{dLh_[\d.]+\}\{FWHMx_([\d.]+)FWHMy_([\d.]+)FWHMz_([\d.]+)mm\}', 'tokens', 'once');
if isempty(t)
    return
end
s.type = t{1};
df = str2double(strsplit(t{2}, ','));
if s.type == 'T'
    s.df = [1 df(1)];
else
    s.df = df(1:2);
end
vox = sqrt(sum(hdr.mat(1:3, 1:3) .^ 2));
fw = [str2double(t{3}) str2double(t{4}) str2double(t{5})] ./ vox;
mask = y ~= 0 & isfinite(y);
s.S = struct('R', spm_resels_vol(double(mask), fw)', 'FWHM', fw, 'V2R', 1 / prod(fw), 'nVox', nnz(mask));
end

function u = defaultThreshold(s, Y)
if isempty(s.type)
    y = abs(double(Y(Y ~= 0 & isfinite(Y))));
    u = 0;
    if ~isempty(y)
        y = sort(y);
        u = y(round(0.5 * numel(y)));
    end
else
    u = spm_u(0.001, s.df, s.type);
end
end

function c = statStruct(v, s)
v = v(:)';
if s.type == 'T'
    p = spm_Tcdf(-v, s.df(2));
else
    p = 1 - spm_Fcdf(v, s.df);
end
c = struct('type', lower(s.type), 'df', s.df, 'stat', v, 'p', max(p, realmin));
end

function lab = label18(b)
[lab, ~] = spm_bwlabel(double(b), 18);
end

function s = cut(vol, view, v)
% 2D slice: superior/anterior up, world +x to the right
switch view
    case 'axial'
        s = rot90(vol(:, :, v(3)));
    case 'coronal'
        s = rot90(squeeze(vol(:, v(2), :)));
    case 'sagittal'
        s = rot90(squeeze(vol(v(1), :, :)));
end
end

function [r, c] = cutPos(view, v, dim)
switch view
    case 'axial'
        r = dim(2) - v(2) + 1; c = v(1);
    case 'coronal'
        r = dim(3) - v(3) + 1; c = v(1);
    case 'sagittal'
        r = dim(3) - v(3) + 1; c = v(2);
end
end

function lim = robustLimits(img)
v = sort(img(img > 0));
if isempty(v)
    lim = [0 1];
else
    lim = [0 v(round(0.995 * numel(v)))];
end
end

function d = otherDims(ax, k)
o = setdiff(1:3, ax);
d = o(k);
end

function rgb = overlay(rgb, s, L)
pos = s > 0;
neg = s < 0;
if ~any(pos(:)) && ~any(neg(:))
    return
end
hi = max(abs(s(:)));
lo = min(abs(s(s ~= 0)));
t = (abs(s) - lo) / max(hi - lo, eps);
cmap = L.colormap;
parts = {pos, neg};
for side = 1:2
    mk = parts{side};
    if ~any(mk(:)), continue, end
    if strcmp(cmap, 'auto')
        if side == 1
            col = cat(3, ones(size(t)), t, zeros(size(t)));          % positive: red -> yellow
        else
            col = cat(3, zeros(size(t)), t, ones(size(t)));          % negative: blue -> cyan
        end
    else
        cm = feval(cmap, 256);
        k = max(1, min(256, round(t * 255) + 1));
        col = reshape(cm(k, :), [size(t) 3]);
    end
    a = L.alpha;
    for ch = 1:3
        x = rgb(:, :, ch);
        cc = col(:, :, ch);
        x(mk) = (1 - a) * x(mk) + a * cc(mk);
        rgb(:, :, ch) = x;
    end
end
end
