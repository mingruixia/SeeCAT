function T = compare_interp(work_dir, tr, out_file, extra)
% COMPARE_INTERP  Spline vs spectral gap fill on real data, by held-out frames.
%   T = compare_interp('D:/data/SeeCAT_e2e/ds000030/work/prep', 2, 'interp.tsv')
%   T = compare_interp(dir_b, 0.75, 'b.tsv', {dir_a, 2})   % also use dataset a's patterns
%
% Real data have no ground truth for censored frames, so good frames are
% censored on purpose. For each subject and each real censor pattern H
% from another subject (of this dataset, and of the datasets in EXTRA as
% {work_dir, tr} pairs), mapped onto this TR by time in seconds and
% restricted to frames this subject kept:
%   reference  E0 = seecat.denoise.clean with the subject's own flags B
%   test       E1 = clean with B | H
% both with the same interpolation method. Measures:
%   contam   median over voxels of RMS(E1 - E0) / RMS(E0) on frames good in
%            both: how much the gaps leak into the data that analyses use
%            (censor mode). Lower is better.
%   fc_dz    mean |Fisher z| change of the PCC seed map on those frames.
%   fill     the same ratio on the held-out frames H (interp_keep mode).
% Uses each unit's work folder from seecat.prep (keep_work = true) and the
% default denoising options.

cfg = seecat.config('prep');
d = cfg.denoise;
rng(7);
units = dir(fullfile(work_dir, 'sub-*'));
data = struct('Y', {}, 'R', {}, 'bad', {}, 'tr', {}, 'id', {});
for i = 1:numel(units)
    u = fullfile(units(i).folder, units(i).name);
    w = dir(fullfile(u, 'wmc_*.nii'));
    [Y, V] = seecat.io.read_nii(fullfile(u, w(1).name), 'Class', 'single');
    m = logical(seecat.io.read_nii(fullfile(u, 'mask_brain.nii')));
    nT = size(Y, 4);
    Y = reshape(Y, [], nT)';
    C = seecat.io.read_tsv(fullfile(u, 'confounds.tsv'));
    idx = find(m(:));
    pick = idx(randperm(numel(idx), min(4000, numel(idx))));
    seed = sphere(V(1), m, [0 -53 26], 6);
    data(i).Y = double([mean(Y(:, seed), 2), Y(:, pick)]);   % column 1: PCC seed
    data(i).R = seecat.denoise.select_regressors(C, d.regressors);
    data(i).bad = C.censor > 0;
    data(i).tr = tr;
    data(i).id = units(i).name;
end

% Censor patterns: {bad, tr, id}
pat = arrayfun(@(x) {x.bad, x.tr, x.id}, data, 'UniformOutput', false);
if nargin > 3
    for e = 1:2:numel(extra)
        U = dir(fullfile(extra{e}, 'sub-*'));
        for i = 1:numel(U)
            C = seecat.io.read_tsv(fullfile(U(i).folder, U(i).name, 'confounds.tsv'));
            pat{end+1} = {C.censor > 0, extra{e + 1}, U(i).name}; %#ok<AGROW>
        end
    end
end

methods = {'spline', 'spectral'};
rows = {};
for i = 1:numel(data)
    for j = 1:numel(pat)
        if strcmp(pat{j}{3}, data(i).id)
            continue
        end
        B = data(i).bad;
        H = onGrid(pat{j}{1}, pat{j}{2}, numel(B), tr) & ~B;
        if nnz(H) < 3
            continue
        end
        keep = ~(B | H);
        if nnz(keep) < 60                % too little left to fit the model (2 min)
            continue
        end
        for k = 1:2
            o = struct('tr', data(i).tr, 'detrend_order', d.detrend_order, 'band', d.band, 'interp', methods{k});
            o.bad = B;
            E0 = seecat.denoise.clean(data(i).Y, data(i).R, o);
            o.bad = B | H;
            E1 = seecat.denoise.clean(data(i).Y, data(i).R, o);
            contam = median(rms(E1(keep, 2:end) - E0(keep, 2:end)) ./ rms(E0(keep, 2:end)));
            fill = median(rms(E1(H, 2:end) - E0(H, 2:end)) ./ rms(E0(keep, 2:end)));
            z0 = atanh(corr(E0(keep, 1), E0(keep, 2:end)));
            z1 = atanh(corr(E1(keep, 1), E1(keep, 2:end)));
            rows(end+1, :) = {data(i).id, pat{j}{3}, methods{k}, nnz(H), nnz(keep), ...
                contam, mean(abs(z1 - z0)), fill}; %#ok<AGROW>
        end
    end
end
T = cell2table(rows, 'VariableNames', {'subject', 'pattern_from', 'method', 'n_heldout', ...
    'n_kept', 'contam', 'fc_dz', 'fill'});
if nargin > 2 && ~isempty(out_file)
    seecat.io.write_tsv(T, out_file);
end
end

function h = onGrid(bad, trFrom, n, trTo)
% Frames (TR trTo) whose start falls in a flagged frame of the pattern
k = floor((0:n - 1)' * trTo / trFrom) + 1;
h = false(n, 1);
in = k <= numel(bad);
h(in) = bad(k(in));
end

function in = sphere(V, m, mm, r)
[i, j, k] = ndgrid(1:V.dim(1), 1:V.dim(2), 1:V.dim(3));
xyz = V.mat * [i(:) j(:) k(:) ones(numel(i), 1)]';
in = sum((xyz(1:3, :) - mm(:)) .^ 2, 1)' <= r ^ 2 & m(:);
end
