function out = protected_inputs(files)
% PROTECTED_INPUTS  The input files of the unit running in this MATLAB.
%   seecat.util.protected_inputs(files)   % seecat.run, before a unit runs
%   seecat.util.protected_inputs({})      % and after it
%   p = seecat.util.protected_inputs()
%
% FILES are canonical paths (seecat.util.input_fingerprint).
% seecat.util.record_output refuses to list one of them as an output, so a
% unit never writes over one of its inputs, and seecat.run never deletes
% one when it clears a unit's outputs. Each parallel worker keeps its own
% list, for the unit it runs.

persistent list
if nargin
    list = cell(1, numel(files));
    for i = 1:numel(files)
        [~, list{i}] = seecat.util.canonical_path(files{i});
    end
end
out = list;
if isempty(out)
    out = {};
end
end
