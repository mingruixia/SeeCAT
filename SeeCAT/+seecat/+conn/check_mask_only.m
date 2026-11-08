function check_mask_only(cfg, brainIsSubject)
% CHECK_MASK_ONLY  Settings that cannot go with cfg.mask_only.
%   seecat.conn.check_mask_only(cfg, brainIsSubject)
%
% "Use the mask as given" replaces the brain mask, so it cannot be combined
% with the group mask (the intersection of brain masks), and, where
% cfg.mask = 'brain' means the subject's own brain mask (BRAINISSUBJECT;
% Degree and Seed FC), it needs another mask.
if ~(isfield(cfg, 'mask_only') && cfg.mask_only)
    return
end
if isfield(cfg, 'group_mask') && cfg.group_mask
    error('SeeCAT:conn', ['"Use the mask as given" and "Same voxels in every run" cannot both be ' ...
        'on: the first uses the mask without any brain mask, the second the brain mask of every ' ...
        'run. Turn one of them off.']);
end
if brainIsSubject && strcmp(cfg.mask, 'brain')
    error('SeeCAT:conn', ['"Use the mask as given" needs a mask other than the brain mask: ' ...
        'choose grey matter (gm) or a mask file.']);
end
end
