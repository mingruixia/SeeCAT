function N = nodes(cfg)
% NODES  The nodes of the gradient analysis, the same for every run.
%   N = seecat.gradient.nodes(cfg)
%
% cfg.nodes = 'voxels': a grid of cfg.node_size mm in MNI space over SPM's
% bounding box [-90 -126 -72; 90 90 108]; a grid cell is a node when at
% least half of it lies in cfg.mask ('gm': SeeCAT's grey-matter mask,
% 'brain': its brain mask, or a mask file; sampled at 27 points per cell).
% cfg.nodes = 'atlas': every label > 0 of the integer image cfg.atlas.
%
% N fields: kind, dim, mat (the grid the maps are written on), index
% (linear indices of the nodes in that grid; voxels) or labels and vol
% (atlas), n (number of nodes), tag (for file names, e.g. 'Vox4'), mask_file
% (the mask or atlas image: with cfg.mask_mode = 'given', its voxels > 0 are the
% voxels the nodes average).

here = fileparts(fileparts(fileparts(mfilename('fullpath'))));       % SeeCAT/
switch cfg.nodes
    case 'voxels'
        vs = cfg.node_size;
        bb = [-90 -126 -72; 90 90 108];
        dim = floor((bb(2, :) - bb(1, :)) / vs) + 1;
        mat = [diag([vs vs vs]), (bb(1, :) - vs)'; 0 0 0 1];
        switch cfg.mask
            case 'gm'
                f = fullfile(here, 'templates', 'tpl-IXI549Space_res-2_label-GM_mask.nii');
            case 'brain'
                f = fullfile(here, 'templates', 'tpl-IXI549Space_res-2_desc-brain_mask.nii');
            otherwise
                f = cfg.mask;
        end
        [M, Vm] = seecat.io.read_nii(f);
        M = M(:, :, :, 1) > 0;
        [i, j, k] = ndgrid(1:dim(1), 1:dim(2), 1:dim(3));
        c = mat(1:3, :) * [i(:) j(:) k(:) ones(numel(i), 1)]';          % cell centres, mm
        [a, b, e] = ndgrid([-1 0 1] / 3 * vs);
        inside = zeros(1, size(c, 2));
        for q = 1:27
            p = Vm.mat \ [c + [a(q); b(q); e(q)]; ones(1, size(c, 2))];
            p = round(p(1:3, :));
            in = all(p >= 1 & p <= size(M, 1:3)', 1);
            hit = false(1, size(c, 2));
            hit(in) = M(sub2ind(size(M), p(1, in), p(2, in), p(3, in)));
            inside = inside + hit;
        end
        N.kind = 'voxels';
        N.mask_file = f;
        N.dim = dim;
        N.mat = mat;
        N.index = find(inside >= 13.5)';
        N.n = numel(N.index);
        N.tag = ['Vox' seecat.util.number_label(vs)];
    case 'atlas'
        [A, Va] = seecat.io.read_nii(cfg.atlas);
        A = round(A(:, :, :, 1));
        N.kind = 'atlas';
        N.mask_file = cfg.atlas;
        N.dim = Va.dim(1:3);
        N.mat = Va.mat;
        N.vol = A;
        N.labels = unique(A(A > 0));
        N.n = numel(N.labels);
        [~, base] = fileparts(regexprep(cfg.atlas, '\.gz$', ''));
        base = regexprep(base, '[^a-zA-Z0-9]', '');
        N.tag = ['Atlas' base(1:min(end, 20))];
        if numel(base) > 20                  % two long names with one beginning stay apart
            h = seecat.util.hash(base);
            N.tag = [N.tag h(1:6)];
        end
    otherwise
        error('SeeCAT:gradient', 'Unknown nodes "%s".', cfg.nodes);
end
if N.n < 20
    error('SeeCAT:gradient', 'Only %d nodes; check the mask or atlas.', N.n);
end
end
