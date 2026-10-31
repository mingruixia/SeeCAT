function bad = flag_frames(fd, threshold, before, after)
% FLAG_FRAMES  High-motion frames and their neighbours.
%   bad = seecat.denoise.flag_frames(fd, 0.5, 1, 2)
%
% A frame is flagged when FD > THRESHOLD; BEFORE frames before and AFTER
% frames after it are flagged too. NaN FD (the first frame) never flags.
% BAD is a T x 1 logical.

fd = fd(:);
T = numel(fd);
hit = find(fd > threshold);
bad = false(T, 1);
for k = -before:after
    i = hit + k;
    bad(i(i >= 1 & i <= T)) = true;
end
end
