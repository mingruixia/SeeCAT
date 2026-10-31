function segment(buttons, on)
% SEGMENT  Show which of a row of push buttons is selected (accent tint),
% for segmented choices such as Log | Summary or Orthogonal | Single.
T = seecat.gui.theme();
for k = 1:numel(buttons)
    if on(k)
        buttons(k).BackgroundColor = T.accentSoft;
        buttons(k).FontColor = T.accent;
        buttons(k).FontWeight = 'bold';
    else
        buttons(k).BackgroundColor = T.panel;
        buttons(k).FontColor = T.text2;
        buttons(k).FontWeight = 'normal';
    end
end
end
