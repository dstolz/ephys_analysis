function writeDat(ffn, data, prec)
%writeDat  Write a flat little-endian binary .dat file (split-format fixture).
fid = fopen(ffn, 'w', 'ieee-le');
assert(fid >= 0, 'cannot open %s', ffn);
fwrite(fid, data, prec);
fclose(fid);
end
