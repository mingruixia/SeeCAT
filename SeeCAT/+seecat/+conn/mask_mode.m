function m = mask_mode(cfg, brainIsSubject)
% MASK_MODE  How the analysis mask meets the runs' brain masks.
%   m = seecat.conn.mask_mode(cfg)                   % 'run', 'group' or 'given'
%   m = seecat.conn.mask_mode(cfg, brainIsSubject)   % also checks cfg.mask
%
% cfg.mask_mode of Degree, Seed FC and Gradients:
%   'run' (default)  the mask within each run's brain mask
%   'group'          the mask within the group mask: the intersection of
%                    the brain masks of every selected run
%                    (seecat.conn.group_mask), so every run has the same voxels
%   'given'          the mask as given, without any brain mask
% 'given' uses the mask itself, so where cfg.mask = 'brain' means the
% subject's own brain mask (BRAINISSUBJECT; Degree and Seed FC) it needs
% another mask.
m = 'run';
if isfield(cfg, 'mask_mode') && ~isempty(cfg.mask_mode)
    m = char(cfg.mask_mode);
end
if nargin > 1 && brainIsSubject && strcmp(m, 'given') && strcmp(cfg.mask, 'brain')
    error('SeeCAT:conn', ['Mask mode "as given" needs a mask other than the brain mask: ' ...
        'choose grey matter (gm) or a mask file.']);
end
end
