function [kept, total] = kept_frames(unit)
% KEPT_FRAMES  Frames of a run kept after censoring, from its confounds table.
%   [kept, total] = seecat.conn.kept_frames(unit)
%
% UNIT has confounds (from seecat.bids.derivative_units). Frames with
% censor = 1 are not kept; without a censor column every frame is kept.
T = seecat.io.read_tsv(unit.confounds);
total = height(T);
kept = total;
if ismember('censor', T.Properties.VariableNames)
    kept = nnz(T.censor == 0);
end
end
