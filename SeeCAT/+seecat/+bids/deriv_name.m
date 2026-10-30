function [rel, name] = deriv_name(source, varargin)
% DERIV_NAME  BIDS-derivatives path of a file derived from a raw BIDS file.
%   rel = seecat.bids.deriv_name(src, 'space', 'IXI549Space', 'res', '3', ...
%                                'desc', 'preproc', 'suffix', 'bold', 'ext', '.nii.gz')
%   % -> 'sub-01/func/sub-01_task-rest_space-IXI549Space_res-3_desc-preproc_bold.nii.gz'
%   [rel, name] = seecat.bids.deriv_name(...)   % NAME is the file name alone
%
% SOURCE is the raw file's path or name. Its entities are kept unless
% overridden; an empty value removes an entity (e.g. 'task', '' for an
% anatomical output derived from a BOLD run). Options besides entities:
%   'suffix'    default: the source suffix
%   'ext'       default: the source extension
%   'datatype'  default: the source's folder (anat, func, ...)
% Entities are written in BIDS order; 'stat' (BIDS stats models) follows
% 'desc', and unknown entities follow those, in the order given.
% Labels must be alphanumeric. REL uses forward slashes.

order = {'sub', 'ses', 'sample', 'task', 'tracksys', 'acq', 'nuc', 'voi', 'ce', ...
    'trc', 'stain', 'rec', 'dir', 'run', 'mod', 'echo', 'flip', 'inv', 'mt', ...
    'part', 'proc', 'hemi', 'space', 'split', 'recording', 'chunk', 'seg', ...
    'res', 'den', 'label', 'from', 'to', 'mode', 'desc', 'stat'};

[ent, suffix, ext] = seecat.bids.parse_name(source);
if isempty(ent) || ~isfield(ent, 'sub')
    error('SeeCAT:bids', 'Not a BIDS subject file: %s', char(source));
end
[d, ~] = fileparts(char(source));
[~, datatype] = fileparts(d);

if mod(numel(varargin), 2)
    error('SeeCAT:bids', 'Options must be name-value pairs.');
end
extra = {};
for i = 1:2:numel(varargin)
    key = varargin{i};
    val = char(string(varargin{i+1}));
    switch key
        case 'suffix'
            suffix = val;
        case 'ext'
            ext = val;
        case 'datatype'
            datatype = val;
        otherwise
            if isempty(val)
                if isfield(ent, key)
                    ent = rmfield(ent, key);
                end
                continue
            end
            if isempty(regexp(val, '^[a-zA-Z0-9]+$', 'once'))
                error('SeeCAT:bids', 'Label for "%s" must be alphanumeric: "%s"', key, val);
            end
            ent.(key) = val;
            if ~ismember(key, order) && ~ismember(key, extra)
                extra{end+1} = key; %#ok<AGROW>
            end
    end
end
if isempty(datatype) || ~ismember(datatype, {'anat', 'func', 'dwi', 'fmap', 'perf', 'pet', 'meg', 'eeg', 'ieeg', 'beh'})
    error('SeeCAT:bids', 'Cannot tell the datatype of %s; pass ''datatype''.', char(source));
end

keys = fieldnames(ent)';
known = order(ismember(order, keys));
other = [extra, setdiff(keys, [order extra], 'stable')];
parts = cellfun(@(k) [k '-' ent.(k)], [known other], 'UniformOutput', false);
name = [strjoin([parts {suffix}], '_') ext];

folder = ['sub-' ent.sub];
if isfield(ent, 'ses')
    folder = [folder '/ses-' ent.ses];
end
rel = [folder '/' datatype '/' name];
end
