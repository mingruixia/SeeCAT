function h = file_md5(file)
% FILE_MD5  MD5 of a file's contents, as 32 hex characters.
%   h = seecat.util.file_md5(file)

fid = fopen(file, 'r');
if fid < 0
    error('SeeCAT:io', 'Cannot read %s.', file);
end
c = onCleanup(@() fclose(fid));
md = java.security.MessageDigest.getInstance('MD5');
while true
    b = fread(fid, 2^24, '*uint8');
    if isempty(b)
        break
    end
    md.update(typecast(b, 'int8'));
end
d = typecast(md.digest(), 'uint8');
h = lower(reshape(dec2hex(d, 2)', 1, []));
end
