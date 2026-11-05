function sel = map_selector(cfg)
% MAP_SELECTOR  cfg.maps with the common sessions, task and runs fields added.
%   sel = seecat.bids.map_selector(cfg)
%
% Statistics and Harmonize choose maps by cfg.maps (entity = value); the
% common selection fields cfg.sessions, cfg.task and cfg.runs narrow it too
% (as ses, task, run), so that they are never accepted and then ignored.
% A field set in both places with different values is an error.

sel = cfg.maps;
if ~isstruct(sel)
    sel = struct();
end
pairs = {'sessions', 'ses'; 'task', 'task'; 'runs', 'run'};
for k = 1:size(pairs, 1)
    if ~isfield(cfg, pairs{k, 1}) || isempty(cfg.(pairs{k, 1}))
        continue
    end
    v = cfg.(pairs{k, 1});
    e = pairs{k, 2};
    if isfield(sel, e) && ~isempty(sel.(e))
        a = sort(cellstr(string(sel.(e))));
        b = sort(cellstr(string(v)));
        if ~isequal(a(:), b(:))
            error('SeeCAT:config', 'Maps has %s = %s but %s is %s; set it in one place.', e, ...
                strjoin(a, ','), pairs{k, 1}, strjoin(b, ','));
        end
    end
    sel.(e) = v;
end
end
