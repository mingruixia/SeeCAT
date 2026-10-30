function meta = metadata(L, f)
% METADATA  Sidecar metadata of a file, following BIDS inheritance.
%   meta = seecat.bids.metadata(L, f)
%
% F is an element of L.files. Every .json with the same suffix, in the
% file's folder or a parent folder up to the dataset root, whose entities
% are all present in F with the same values, applies. Values from deeper
% folders override shallower ones (and, within one folder, more specific
% files override less specific ones). Returns a struct (empty struct if no
% sidecar applies).

meta = struct();
if isempty(L.sidecars)
    return
end
S = L.sidecars(strcmp({L.sidecars.suffix}, f.suffix));
use = false(numel(S), 1);
for i = 1:numel(S)
    use(i) = isAncestor(S(i).dir, f.dir) && entitiesMatch(S(i).ent, f.ent);
end
S = S(use);
depth = arrayfun(@(s) nnz(s.dir == filesep), S);
nEnt = arrayfun(@(s) numel(fieldnames(s.ent)), S);
[~, order] = sortrows([depth(:) nEnt(:)]);
for i = order'
    m = jsondecode(fileread(S(i).path));
    for k = fieldnames(m)'
        meta.(k{1}) = m.(k{1});
    end
end
end

function tf = isAncestor(a, b)
tf = strcmp(a, b) || startsWith(b, [a filesep]);
end

function tf = entitiesMatch(sc, file)
tf = true;
for k = fieldnames(sc)'
    if ~isfield(file, k{1}) || ~strcmp(file.(k{1}), sc.(k{1}))
        tf = false;
        return
    end
end
end
