function out = icon(name, color, kind)
% ICON  SeeCAT's line icons (24 x 24, drawn for SeeCAT), as a file or markup.
%   f = seecat.gui.icon('folder')              % SVG file for uibutton/uiimage Icon
%   f = seecat.gui.icon('play', '#FFFFFF')     % in another colour
%   s = seecat.gui.icon('brain', '#64748B', 'markup')   % <svg> text for uihtml
%   seecat.gui.icon('logo')                    % the SeeCAT mark (fixed colours)
%
% Files are written once per name and colour under tempdir/seecat_icons.

if nargin < 2 || isempty(color)
    color = seecat.gui.theme().hex.icon;
end
if nargin < 3
    kind = 'file';
end
svg = markup(name, color);
if strcmp(kind, 'markup')
    out = svg;
    return
end
d = fullfile(tempdir, 'seecat_icons');
if ~exist(d, 'dir')
    mkdir(d);
end
out = fullfile(d, sprintf('%s_%s.svg', name, lower(color(2:end))));
if ~exist(out, 'file')
    fid = fopen(out, 'w', 'n', 'UTF-8');
    fprintf(fid, '%s', svg);
    fclose(fid);
end
end

function s = markup(name, color)
if strcmp(name, 'logo')
    a = seecat.gui.theme().hex.accent;
    s = ['<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32">' ...
        '<rect width="32" height="32" rx="7" fill="' a '"/>' ...
        '<path d="M7 24.5V10.5l5 4h8l5-4v14" fill="none" stroke="#fff" stroke-width="2.2" ' ...
        'stroke-linecap="round" stroke-linejoin="round"/>' ...
        '<path d="M12.5 19.5h7" stroke="#fff" stroke-width="1.3"/>' ...
        '<circle cx="12.5" cy="19.5" r="2" fill="#fff"/><circle cx="19.5" cy="19.5" r="2" fill="#fff"/></svg>'];
    return
end
[body, filled] = shape(name);
fill = 'none';
if filled
    fill = color;
end
s = sprintf(['<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" ' ...
    'fill="%s" stroke="%s" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">%s</svg>'], ...
    fill, color, body);
end

function [b, filled] = shape(name)
filled = false;
switch name
    case 'dicom'       % file with an arrow in
        b = '<path d="M14 3v4a1 1 0 0 0 1 1h4"/><path d="M5 12V5a2 2 0 0 1 2-2h7l5 5v11a2 2 0 0 1-2 2h-5"/><path d="M2 18h8M7 15l3 3-3 3"/>';
    case 'sliders'
        b = '<path d="M4 6h8M16 6h4M4 12h2M10 12h10M4 18h10M18 18h2"/><circle cx="14" cy="6" r="2"/><circle cx="8" cy="12" r="2"/><circle cx="16" cy="18" r="2"/>';
    case 'filter'
        b = '<path d="M4 4h16v2.2a2 2 0 0 1-.6 1.4L15 12v7l-6 2v-8.5L4.6 7.6A2 2 0 0 1 4 6.2z"/>';
    case 'target'
        b = '<circle cx="12" cy="12" r="1"/><circle cx="12" cy="12" r="5"/><circle cx="12" cy="12" r="9"/>';
    case 'network'
        b = '<circle cx="12" cy="5" r="2"/><circle cx="5" cy="18" r="2"/><circle cx="19" cy="18" r="2"/><circle cx="12" cy="13" r="2"/><path d="M12 7v4M10.4 14.2l-3.8 2.6M13.6 14.2l3.8 2.6"/>';
    case 'stat'        % scatter
        b = '<path d="M4 4v16h16"/><circle cx="9" cy="14" r="1.4"/><circle cx="13" cy="10" r="1.4"/><circle cx="17.5" cy="6.5" r="1.4"/><circle cx="16" cy="14.5" r="1.4"/>';
    case 'brain'
        b = '<path d="M12 5.5a3 3 0 0 0-5.7.8A3 3 0 0 0 4 11a3.2 3.2 0 0 0 1 5.3 3 3 0 0 0 5.4 2.4L12 18z"/><path d="M12 5.5a3 3 0 0 1 5.7.8A3 3 0 0 1 20 11a3.2 3.2 0 0 1-1 5.3 3 3 0 0 1-5.4 2.4L12 18"/><path d="M12 5.5V18"/>';
    case 'report'
        b = '<path d="M9 5H7a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V7a2 2 0 0 0-2-2h-2"/><rect x="9" y="3" width="6" height="4" rx="1"/><path d="M9 14l2 2 4-4"/>';
    case 'book'
        b = '<path d="M4 5.5A1.5 1.5 0 0 1 5.5 4H11v16H5.5A1.5 1.5 0 0 1 4 18.5z"/><path d="M20 5.5A1.5 1.5 0 0 0 18.5 4H13v16h5.5a1.5 1.5 0 0 0 1.5-1.5z"/>';
    case 'info'
        b = '<circle cx="12" cy="12" r="9"/><path d="M12 11v5M12 8h.01"/>';
    case 'folder'
        b = '<path d="M4 7a2 2 0 0 1 2-2h4l2 2h6a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2z"/>';
    case 'save'
        b = '<path d="M6 4h10l4 4v10a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2z"/><path d="M8 4v4h7V4"/><circle cx="12" cy="14" r="2.5"/>';
    case 'play'
        b = '<path d="M7 4.5v15l12.5-7.5z"/>';
        filled = true;
    case 'stop'
        b = '<rect x="6" y="6" width="12" height="12" rx="2"/>';
        filled = true;
    case 'external'
        b = '<path d="M12 6H6a2 2 0 0 0-2 2v10a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-6"/><path d="M11 13l9-9M15 4h5v5"/>';
    case 'copy'
        b = '<rect x="8" y="8" width="12" height="12" rx="2"/><path d="M16 8V6a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v8a2 2 0 0 0 2 2h2"/>';
    case 'plus'
        b = '<path d="M12 5v14M5 12h14"/>';
    case 'minus'
        b = '<path d="M5 12h14"/>';
    case 'grid'
        b = '<rect x="4" y="4" width="7" height="7" rx="1"/><rect x="13" y="4" width="7" height="7" rx="1"/><rect x="4" y="13" width="7" height="7" rx="1"/><rect x="13" y="13" width="7" height="7" rx="1"/>';
    case 'single'
        b = '<rect x="4" y="4" width="16" height="16" rx="2"/>';
    case 'mosaic'
        b = '<rect x="4" y="4" width="16" height="16" rx="2"/><path d="M4 9.3h16M4 14.7h16M9.3 4v16M14.7 4v16"/>';
    case 'surface'     % cube
        b = '<path d="M12 3l8 4.5v9L12 21l-8-4.5v-9z"/><path d="M12 12l8-4.5M12 12v9M12 12L4 7.5"/>';
    case 'image'
        b = '<rect x="4" y="4" width="16" height="16" rx="2"/><circle cx="9" cy="9" r="1.5"/><path d="M4 16l4-4 5 5M13 15l2-2 5 5"/>';
    case 'download'
        b = '<path d="M4 17v1a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-1M7 11l5 5 5-5M12 4v12"/>';
    case 'crosshair'
        b = '<circle cx="12" cy="12" r="7"/><path d="M12 2v4M12 18v4M2 12h4M18 12h4"/>';
    case 'peak'
        b = '<path d="M3 19h18"/><path d="M5 19c3 0 4-12 7-12s4 12 7 12"/>';
    case 'layers'
        b = '<path d="M12 4L4 8l8 4 8-4z"/><path d="M4 12l8 4 8-4M4 16l8 4 8-4"/>';
    case 'chevron-down'
        b = '<path d="M6 9l6 6 6-6"/>';
    case 'chevron-up'
        b = '<path d="M6 15l6-6 6 6"/>';
    case 'check'
        b = '<path d="M5 12l5 5L20 7"/>';
    case 'refresh'
        b = '<path d="M20 11a8 8 0 0 0-14.8-4M4 4v4h4"/><path d="M4 13a8 8 0 0 0 14.8 4M20 20v-4h-4"/>';
    otherwise
        error('SeeCAT:gui', 'No icon "%s".', name);
end
end
