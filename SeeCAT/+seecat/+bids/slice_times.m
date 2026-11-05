function st = slice_times(st, direction)
% SLICE_TIMES  BIDS SliceTiming in voxel order along the third axis.
%   st = seecat.bids.slice_times(meta.SliceTiming, meta.SliceEncodingDirection)
%
% BIDS lists SliceTiming along SliceEncodingDirection, which is k when the
% field is absent. SPM's slice timing works along the third voxel axis:
% k is returned as it is; k- reversed (its first entry belongs to the last
% slice of that axis). i, j, i- and j- (slices along the first or second
% voxel axis) are an error: applying their times along the third axis
% would be wrong.

st = st(:)';
if nargin < 2 || isempty(direction)
    direction = 'k';
end
switch char(direction)
    case 'k'
    case 'k-'
        st = fliplr(st);
    otherwise
        error('SeeCAT:prep', ['SliceEncodingDirection is %s: slices along the first or second ' ...
            'voxel axis are not supported by slice timing. Reorient the images so that slices ' ...
            'lie along the third axis, or turn slice timing off.'], char(direction));
end
end
