function D = design(cfg, maps)
% DESIGN  Design matrix, contrasts and covariance structure of a group model.
%   D = seecat.stat.design(cfg, maps)
%
% MAPS is a table with one row per map: path, sub, level (the within-subject
% level for paired/anova1_rm, '' otherwise) and the participants.tsv columns
% of its subject. CFG is the stat configuration (Doc/design/stat.md, 2).
%
% D fields:
%   X        n x p design, columns names in D.names
%   con      default or given contrasts (name, type, weights)
%   I, var, dep, i0   covariance structure for seecat.stat.reml
%   reml     true when non-sphericity is estimated
%   vif      variance inflation factor of covariate/regressor columns
%   coding   how each covariate was coded (for the report)

n = height(maps);
cov = covariates(maps, cfg.covariates);
subj = findgroups(maps.sub);
nsub = max(subj);
D.coding = cov.coding;
D.reml = false;
D.i0 = [];
D.I = [subj(:), ones(n, 1)];
D.var = [false false];
D.dep = [false false];
unequal = strcmp(cfg.variance, 'unequal');
vifCols = [];
switch cfg.design
    case 'one_sample'
        X = ones(n, 1);
        names = {'mean'};
        con = tpair('mean', 1, 'pos', 'neg');
    case {'two_sample', 'anova1'}
        [g, lv] = levelIndex(maps.(cfg.factor), cfg.levels);
        X = double(g == 1:numel(lv));
        names = strcat(cfg.factor, '_', lv);
        if strcmp(cfg.design, 'two_sample')
            con = tpair([lv{1} 'vs' lv{2}], [1 -1], [lv{1} 'gt' lv{2}], [lv{2} 'gt' lv{1}]);
        else
            con = fEqual(numel(lv), 'groups');
        end
        D.I = [(1:n)', g];
        D.var = [false unequal];
    case {'paired', 'anova1_rm'}
        if ~isempty(cov.X)
            error('SeeCAT:stat', 'Between-subject covariates cannot be estimated with subject effects (%s).', cfg.design);
        end
        [g, lv] = levelIndex(maps.level, cfg.levels);
        X = [double(g == 1:numel(lv)), double(subj == 1:nsub)];
        names = [strcat('level_', lv(:)'), strcat('subject_', unique(maps.sub, 'stable')')];
        nl = numel(lv);
        if strcmp(cfg.design, 'paired')
            con = tpair([lv{1} 'vs' lv{2}], [1 -1 zeros(1, nsub)], [lv{1} 'gt' lv{2}], [lv{2} 'gt' lv{1}]);
        else
            con = fEqual(nl, 'levels');
            con.weights = [con.weights, zeros(nl - 1, nsub)];
        end
        D.I = [subj(:), g];
        D.var = [false unequal];
        D.dep = [unequal false];
        D.i0 = nl + (1:nsub);
    case 'regression'
        R = zeros(n, numel(cfg.regressors));
        for k = 1:numel(cfg.regressors)
            R(:, k) = double(maps.(cfg.regressors{k}));
        end
        X = [R - mean(R, 1), ones(n, 1)];
        vifCols = 1:numel(cfg.regressors);
        names = [cfg.regressors(:)', {'mean'}];
        con = struct('name', {}, 'type', {}, 'weights', {});
        for k = 1:numel(cfg.regressors)
            w = zeros(1, size(X, 2));
            w(k) = 1;
            con = [con, tpair(cfg.regressors{k}, w, [cfg.regressors{k} 'pos'], [cfg.regressors{k} 'neg'])]; %#ok<AGROW>
        end
    case 'custom'
        X = maps{:, cfg.design_columns};
        names = cfg.design_columns(:)';
        con = struct('name', {}, 'type', {}, 'weights', {});
    otherwise
        error('SeeCAT:stat', 'Unknown design "%s".', cfg.design);
end
vifCols = [vifCols, size(X, 2) + (1:size(cov.X, 2))];
X = [X, cov.X];
names = [names, cov.names];
for k = 1:numel(con)
    con(k).weights = [con(k).weights, zeros(size(con(k).weights, 1), size(cov.X, 2))];
end
q = 0;                                        % image covariates follow X
if isfield(cfg, 'n_image_covariates')
    q = cfg.n_image_covariates;
end
for k = 1:numel(con)
    con(k).weights = [con(k).weights, zeros(size(con(k).weights, 1), q)];
end
if ~isempty(cfg.contrasts)
    con = given(cfg.contrasts, size(X, 2) + q);
end
if isempty(con)
    error('SeeCAT:stat', 'The %s design needs "contrasts".', cfg.design);
end
D.X = X;
D.names = names;
D.con = con;
D.reml = unequal && any(D.var | D.dep);
D.vif = vif(X, vifCols, names);
end

function C = covariates(maps, list)
C = struct('X', zeros(height(maps), 0), 'names', {{}}, 'coding', struct());
for k = 1:numel(list)
    v = maps.(list{k});
    if isnumeric(v) || islogical(v)
        x = double(v) - mean(double(v));
        C.X = [C.X, x];
        C.names{end+1} = list{k};
        C.coding.(list{k}) = 'numeric, mean-centred';
    else
        v = string(v);
        lv = unique(v, 'stable');
        if numel(lv) < 2
            error('SeeCAT:stat', 'Covariate %s has a single value (%s).', list{k}, lv);
        end
        for j = 2:numel(lv)
            x = double(v == lv(j));
            C.X = [C.X, x - mean(x)];
            C.names{end+1} = sprintf('%s_%s', list{k}, lv(j));
        end
        C.coding.(list{k}) = sprintf('text, %d centred dummies against %s', numel(lv) - 1, lv(1));
    end
end
end

function [g, lv] = levelIndex(v, levels)
v = cellstr(string(v));
if isempty(levels)
    lv = unique(v, 'stable')';
else
    lv = levels(:)';
end
[~, g] = ismember(v, lv);
if any(g == 0)
    error('SeeCAT:stat', 'Values not in "levels": %s.', strjoin(unique(v(g == 0)), ', '));
end
g = g(:);
end

function c = tpair(name, w, pos, neg) %#ok<INUSL>
c = struct('name', {pos, neg}, 'type', {'t', 't'}, 'weights', {w, -w});
end

function c = fEqual(k, what)
w = [eye(k - 1), zeros(k - 1, 1)] - [zeros(k - 1, 1), eye(k - 1)];
c = struct('name', ['equal' what], 'type', 'F', 'weights', w);
end

function con = given(c, p)
con = struct('name', {}, 'type', {}, 'weights', {});
for k = 1:numel(c)
    w = double(c(k).weights);
    if size(w, 2) ~= p
        error('SeeCAT:stat', 'Contrast %s has %d weights; the design has %d columns (see design.tsv).', c(k).name, size(w, 2), p);
    end
    con(k) = struct('name', c(k).name, 'type', c(k).type, 'weights', w); %#ok<AGROW>
end
end

function v = vif(X, cols, names)
v = struct();
for j = cols
    others = setdiff(1:size(X, 2), j);
    x = X(:, j);
    r = x - X(:, others) * (pinv(X(:, others)) * x);
    r2 = 1 - sum(r .^ 2) / sum((x - mean(x)) .^ 2);
    v.(matlab.lang.makeValidName(names{j})) = 1 / max(1 - r2, eps);
end
end
