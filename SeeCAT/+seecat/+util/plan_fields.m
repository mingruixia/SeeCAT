function [cfg, names] = plan_fields(cfg)
% PLAN_FIELDS  Remove the fields a plan adds to a config.
%   cfg = seecat.util.plan_fields(cfg)
%   [~, names] = seecat.util.plan_fields(struct())
%
% A plan reports the runs it left out in cfg.qc_excluded (QC exclusions,
% seecat.bids.derivative_units), cfg.few_frames (fewer than min_frames
% frames, seecat.gradient.plan) and cfg.empty_mask (no voxel of the mask or
% atlas, seecat.gradient.plan). They are results of planning, not options:
% they are worked out again by every plan, are not written to the saved
% config and are dropped when a config is read (seecat.config), so a
% planned config runs again. NAMES lists them.
names = {'qc_excluded', 'few_frames', 'empty_mask'};
cfg = rmfield(cfg, intersect(fieldnames(cfg), names));
end
