function v = scrub_names(v, words)
% SCRUB_NAMES  Take words (names of people) out of text, also inside structs.
%   s = seecat.bids.scrub_names('sub-173_zhangsan_rest.nii', {'zhangsan'})   % 'sub-173_rest.nii'
%   m = seecat.bids.scrub_names(sidecar, {'Zhang', 'San', 'ZhangSan'})
%
% Each word is removed where it stands as a word of its own (not inside a
% longer word), ignoring case, together with the separator (_ - or space)
% before it; separators left at the start of the text or of a path part
% are removed too. V can be text, a string array, a cell or a struct
% (also nested and struct arrays); numbers and logicals are left as they
% are. WORDS shorter than 2 characters are ignored.

words = cellstr(words);
words = words(cellfun(@numel, words) >= 2);
if isempty(words)
    return
end
[~, ord] = sort(cellfun(@numel, words), 'descend');       % ZhangSan before Zhang
words = words(ord);
v = scrub(v, words);
end

function v = scrub(v, words)
if ischar(v)
    v = text(v, words);
elseif isstring(v)
    for k = 1:numel(v)
        if ~ismissing(v(k))
            v(k) = text(char(v(k)), words);
        end
    end
elseif iscell(v)
    for k = 1:numel(v)
        v{k} = scrub(v{k}, words);
    end
elseif isstruct(v)
    for k = 1:numel(v)
        for f = fieldnames(v)'
            v(k).(f{1}) = scrub(v(k).(f{1}), words);
        end
    end
end
end

function s = text(s, words)
s0 = s;
for w = words(:)'
    s = regexprep(s, ['[_\- ]*(?<![a-zA-Z0-9])' regexptranslate('escape', w{1}) '(?![a-zA-Z0-9])'], '', ...
        'ignorecase');
end
if ~strcmp(s, s0)
    s = regexprep(s, '(^|[/\\])[_\- ]+', '$1');
end
end
