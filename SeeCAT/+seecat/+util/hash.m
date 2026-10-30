function h = hash(value)
% HASH  MD5 of a value's JSON encoding, as 32 hex characters.
%   h = seecat.util.hash(cfg)
%
% Used to tell whether options changed between runs; values must be
% JSON-encodable (no function handles or objects).

bytes = unicode2native(jsonencode(value), 'UTF-8');
md = java.security.MessageDigest.getInstance('MD5');
d = typecast(md.digest(bytes), 'uint8');
h = lower(reshape(dec2hex(d, 2)', 1, []));
end
