function T = compare_interp(work_dir, out_file)
% COMPARE_INTERP  Spline vs spectral gap fill on real data, by held-out frames.
%   T = compare_interp('D:/data/SeeCAT_e2e/ds000030/work/prep', 'interp.tsv')
%
% Real data have no ground truth for censored frames, so good frames are
% censored on purpose. For each subject and each other subject's real
% censor pattern H (restricted to frames this subject kept):
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

units = dir(fullfile(work_dir, 'sub-*'));
cfg = seecat.config('prep');
d = cfg.denoise;
rng(7);
data = struct('Y', {}, 'R', {}, 'bad', {}, 'tr', {}, 'id', {});
for i = 1:numel(units)
    u = fullfile(units(i).folder, units(i).name);
    [Y, V] = seecat.io.read_nii(fullfile(u, 'wmc_abold.nii'), 'Class', 'single');
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
    data(i).tr = 2;
    data(i).id = units(i).name;
end

methods = {'spline', 'spectral'};
rows = {};
for i = 1:numel(data)
    for j = 1:numel(data)
        if i == j || numel(data(j).bad) ~= numel(data(i).bad)
            continue
        end
        B = data(i).bad;
        H = data(j).bad & ~B;
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
            rows(end+1, :) = {data(i).id, data(j).id, methods{k}, nnz(H), nnz(keep), ...
                contam, mean(abs(z1 - z0)), fill}; %#ok<AGROW>
        end
    end
end
T = cell2table(rows, 'VariableNames', {'subject', 'pattern_from', 'method', 'n_heldout', ...
    'n_kept', 'contam', 'fc_dz', 'fill'});
if nargin > 1
    seecat.io.write_tsv(T, out_file);
end
end

function in = sphere(V, m, mm, r)
[i, j, k] = ndgrid(1:V.dim(1), 1:V.dim(2), 1:V.dim(3));
xyz = V.mat * [i(:) j(:) k(:) ones(numel(i), 1)]';
in = sum((xyz(1:3, :) - mm(:)) .^ 2, 1)' <= r ^ 2 & m(:);
end
