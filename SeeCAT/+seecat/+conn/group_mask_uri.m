function g = group_mask_uri(unit, cfg)
% GROUP_MASK_URI  The unit's group mask as a BIDS URI (bids:seecat:...), '' without one.
%   g = seecat.conn.group_mask_uri(unit, cfg)    % for the JSON sidecars of the maps
g = '';
if isfield(unit, 'group_mask') && ~isempty(unit.group_mask)
    g = strrep(unit.group_mask, '\', '/');
    root = strrep(cfg.output_dir, '\', '/');
    if startsWith(lower(g), lower([root '/']))
        g = ['bids:seecat:' g(numel(root) + 2:end)];
    end
end
end
