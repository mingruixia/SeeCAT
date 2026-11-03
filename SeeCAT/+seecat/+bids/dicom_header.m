function h = dicom_header(file)
% DICOM_HEADER  The patient, study and series fields of one DICOM file.
%   h = seecat.bids.dicom_header('IM0001')
%
% Reads only the start of the file, up to group 0020, so it is fast also on
% enhanced multi-frame files. H has PatientID, PatientName,
% PatientBirthDate, StudyInstanceUID, StudyDate, StudyTime,
% SeriesInstanceUID, SeriesNumber (double), SeriesDescription and Modality,
% as text ('' when missing). H is [] when FILE is not DICOM, or is big
% endian or deflated (then spm_dicom_headers is tried for the patient and
% study fields).

tags = {'0010', '0020', 'PatientID'; '0010', '0010', 'PatientName'; '0010', '0030', 'PatientBirthDate'; ...
    '0020', '000D', 'StudyInstanceUID'; '0008', '0020', 'StudyDate'; '0008', '0030', 'StudyTime'; ...
    '0020', '000E', 'SeriesInstanceUID'; '0020', '0011', 'SeriesNumber'; '0008', '103E', 'SeriesDescription'; ...
    '0008', '0060', 'Modality'};
key = hex2dec(tags(:, 1)) * 65536 + hex2dec(tags(:, 2));
for bytes = [65536, 4194304]
    [d, whole] = readStart(file, bytes);
    [v, ok, complete] = parse(d, key);
    if ~ok
        h = spmFallback(file, tags(:, 3));
        return
    end
    if complete || whole
        break
    end
end
h = cell2struct(v, tags(:, 3), 1);
h.SeriesNumber = str2double(h.SeriesNumber);
end

function [d, whole] = readStart(file, n)
fid = fopen(file, 'r', 'l');
if fid < 0
    d = uint8([]);
    whole = true;
    return
end
d = fread(fid, n, '*uint8')';
whole = numel(d) < n;
fclose(fid);
end

function [v, ok, complete] = parse(d, key)
% ok false: not DICOM or a syntax this reader skips; complete: reached
% group 0021 (every wanted field seen)
v = repmat({''}, numel(key), 1);
ok = false;
complete = false;
n = numel(d);
if n >= 132 && isequal(char(d(129:132)), 'DICM')
    p = 133;
else
    p = 1;
end
if p + 8 > n
    return
end
g = u16(d, p);
if ~ismember(g, [2 8])
    return
end
explicit = isVR(d, p + 4);
if g == 2                                          % file meta: always explicit VR
    [p, ts] = metaGroup(d, p);
    if isempty(p) || startsWith(ts, {'1.2.840.10008.1.2.2', '1.2.840.10008.1.2.1.99'})
        return                                     % big endian or deflated
    end
    explicit = ~strcmp(ts, '1.2.840.10008.1.2');
end
ok = true;
while p + 8 <= n
    tag = double(u16(d, p)) * 65536 + double(u16(d, p + 2));
    if tag > hex2dec('00210000')
        complete = true;
        return
    end
    [len, p, sq] = elementLength(d, p, explicit);
    if isempty(len)
        return
    end
    if sq
        p = skipSequence(d, p, len, explicit);
        if isempty(p), return, end
        continue
    end
    k = find(key == tag, 1);
    if ~isempty(k) && p + len - 1 <= n
        v{k} = strtrim(deblank(char(d(p:p + len - 1))));
    end
    p = p + len;
end
end

function [p, ts] = metaGroup(d, p)
ts = '';
n = numel(d);
while p + 8 <= n && u16(d, p) == 2
    el = u16(d, p + 2);
    [len, q] = elementLength(d, p, true);
    if isempty(len) || q + len - 1 > n
        p = [];
        return
    end
    if el == 16                                     % (0002,0010) transfer syntax
        ts = strtrim(deblank(char(d(q:q + len - 1))));
    end
    p = q + len;
end
end

function [len, p, sq] = elementLength(d, p, explicit)
% Length of the element at P and where its value starts; SQ true for a
% sequence (or an undefined length)
n = numel(d);
sq = false;
len = [];
if explicit && isVR(d, p + 4)
    vr = char(d(p + 4:p + 5));
    if ismember(vr, {'OB', 'OW', 'OF', 'SQ', 'UT', 'UN', 'OD', 'OL', 'OV', 'UC', 'UR', 'SV', 'UV'})
        if p + 12 > n + 1, return, end
        len = double(u32(d, p + 8));
        p = p + 12;
    else
        len = double(u16(d, p + 6));
        p = p + 8;
    end
    sq = strcmp(vr, 'SQ');
else
    len = double(u32(d, p + 4));
    p = p + 8;
end
if len == 4294967295
    sq = true;
end
end

function p = skipSequence(d, p, len, explicit)
% Past a sequence that starts at P (value start); [] if the data ends first
n = numel(d);
if len ~= 4294967295
    p = p + len;
    return
end
while p + 8 <= n
    g = u16(d, p);
    e = u16(d, p + 2);
    ilen = double(u32(d, p + 4));
    p = p + 8;
    if g ~= hex2dec('FFFE')
        p = [];
        return
    end
    if e == hex2dec('E0DD')                         % sequence end
        return
    end
    if ilen ~= 4294967295                           % item of known length
        p = p + ilen;
        continue
    end
    while p + 8 <= n                                % item of undefined length
        if u16(d, p) == hex2dec('FFFE') && u16(d, p + 2) == hex2dec('E00D')
            p = p + 8;
            break
        end
        [l2, p, sq] = elementLength(d, p, explicit);
        if isempty(l2), p = []; return, end
        if sq
            p = skipSequence(d, p, l2, explicit);
            if isempty(p), return, end
        else
            p = p + l2;
        end
    end
end
p = [];
end

function tf = isVR(d, p)
tf = p + 1 <= numel(d) && all(d(p:p + 1) >= 65 & d(p:p + 1) <= 90);
end

function x = u16(d, p)
x = double(d(p)) + 256 * double(d(p + 1));
end

function x = u32(d, p)
x = double(d(p)) + 256 * double(d(p + 1)) + 65536 * double(d(p + 2)) + 16777216 * double(d(p + 3));
end

function h = spmFallback(file, names)
h = [];
if ~exist('spm_dicom_headers', 'file')
    return
end
w = warning('off', 'spm:dicom');
restore = onCleanup(@() warning(w));
try
    [~, s] = evalc('spm_dicom_headers(file, true)');
catch
    return
end
if isempty(s)
    return
end
s = s{1};
h = cell2struct(repmat({''}, numel(names), 1), names, 1);
for k = 1:numel(names)
    if isfield(s, names{k})
        x = s.(names{k});
        if isnumeric(x), x = sprintf('%.15g', x); end
        h.(names{k}) = strtrim(char(x));
    end
end
h.SeriesNumber = str2double(h.SeriesNumber);
end
