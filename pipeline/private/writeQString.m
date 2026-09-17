function writeQString(fid, str)
%writeQString  Qt QString: uint32 length in BYTES, then uint16 per char.
fwrite(fid, numel(str) * 2, 'uint32');
for i = 1:numel(str)
    fwrite(fid, double(str(i)), 'uint16');
end
end
