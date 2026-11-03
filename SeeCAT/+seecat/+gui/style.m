function style(fig)
% STYLE  Give every control in FIG the SeeCAT font (seecat.gui.theme); text
% already set in the monospaced font keeps it. A figure is also kept in
% the light theme (figures follow the desktop theme; SeeCAT sets its own
% colours).
T = seecat.gui.theme();
if isa(fig, 'matlab.ui.Figure')
    fig.Theme = 'light';
end
h = findall(fig, '-property', 'FontName');
for k = 1:numel(h)
    if ~strcmp(h(k).FontName, T.mono)
        h(k).FontName = T.font;
    end
end
end
