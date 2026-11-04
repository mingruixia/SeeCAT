function cm = colours(name, n)
% COLOURS  N x 3 colour table of a viewer colour map, low to high.
%   cm = seecat.view.colours('hot', 256)
%
% MATLAB's map of that name; hot and gray start at black, which hides the
% voxels just above the threshold on a grey brain, so their darkest fifth
% is left out.
full = feval(name, 1024);
lo = 1;
if any(strcmp(name, {'hot', 'gray'}))
    lo = round(0.2 * 1024);
end
cm = full(round(linspace(lo, 1024, n)), :);
end
