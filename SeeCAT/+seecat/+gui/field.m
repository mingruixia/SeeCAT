function f = field(path, label, widget, section, varargin)
% FIELD  One entry of a pipeline's form description (seecat.<p>.gui).
%   f = seecat.gui.field('denoise.band', 'Band (Hz)', 'range', 'Denoising', ...
%                        'help', 'Band-pass filter; empty = none', 'advanced', false)
%
% WIDGET: folder, file, text, labels, number, range, flag, choice, multi,
% seeds, contrasts, maps. Options: 'help', 'advanced' (false), 'choices'
% (choice and multi).
p = inputParser;
p.addParameter('help', '');
p.addParameter('advanced', false);
p.addParameter('choices', {});
p.parse(varargin{:});
f = struct('path', path, 'label', label, 'widget', widget, 'section', section, ...
    'help', p.Results.help, 'advanced', p.Results.advanced, 'choices', {p.Results.choices});
end
