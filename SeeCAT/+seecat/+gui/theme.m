function T = theme()
% THEME  Colours, fonts and sizes shared by the SeeCAT windows.
%   T = seecat.gui.theme();   T.accent, T.font, T.size.body, ...
%
% Colours are RGB triplets in 0..1; T.hex holds the same as '#rrggbb' for
% the HTML parts (seecat.gui.icon, resources/ui).

hex = struct( ...
    'accent',     '#3B5BDB', ...   % links, selection, primary button
    'accentSoft', '#EDF2FF', ...   % selected row / item
    'accentRing', '#DBE4FF', ...
    'page',       '#F6F7F9', ...   % window background
    'panel',      '#FFFFFF', ...   % cards, side bar, header
    'side',       '#FBFCFD', ...   % right-hand column
    'border',     '#E2E8F0', ...   % dividers, card outlines
    'control',    '#CBD5E1', ...   % input outlines
    'text',       '#0F172A', ...
    'text2',      '#475569', ...   % labels
    'muted',      '#94A3B8', ...   % hints, units
    'icon',       '#64748B', ...
    'canvas',     '#0B0D10', ...   % behind the slices
    'canvas2',    '#14171C', ...   % info cell in the viewer
    'canvasText', '#CBD5E1', ...
    'logBg',      '#F8FAFC', ...   % log drawer
    'logText',    '#334155', ...
    'ok',         '#2F9E44', ...
    'running',    '#F59F00', ...
    'failed',     '#E03131', ...
    'cursor',     '#40C057');
T = structfun(@rgb, hex, 'UniformOutput', false);
T.hex = hex;
if ispc
    T.font = 'Segoe UI';
elseif ismac
    T.font = 'Helvetica Neue';
else
    T.font = 'Helvetica';
end
T.mono = 'Consolas';
if ~ispc
    T.mono = 'Menlo';
end
T.size = struct('small', 11, 'body', 12, 'card', 13, 'title', 18);
T.row = 26;            % height of one form row
T.label = 210;         % width of the label column
end

function c = rgb(h)
c = sscanf(h(2:end), '%2x')' / 255;
end
