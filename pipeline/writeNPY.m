function writeNPY(filename, data, descr)
%writeNPY  Write a numeric array as a little-endian NumPy .npy file.
%   writeNPY(filename, data) writes DATA in C order with a dtype inferred
%   from its class (int8..int64, uint8..uint64, single, double, logical).
%   writeNPY(filename, data, descr) forces the NumPy dtype string, e.g.
%   '<i8', '<i4', '<f4', '<f8', '<u2', '|b1'; DATA is cast to it.
%
%   A vector is written as a 1-D array of shape (n,); an N-D array keeps its
%   MATLAB shape (a, b, c, ...) and is stored in C order, so readNPY (and
%   NumPy) return the same array back. This is the writer counterpart of
%   READNPY; it exists so tests and tools can build phy / Kilosort4 fixtures
%   (spike_times.npy, templates.npy, ...) without NumPy.
%
%   See also readNPY.

arguments
    filename (1,1) string
    data
    descr (1,1) string = ""
end

if descr == ""
    descr = descrFor(data);
end
[prec, cls] = precFor(descr);
data = cast(data, cls);

if isvector(data)
    shapeTxt = sprintf('(%d,)', numel(data));
    payload = data(:);
else
    shapeTxt = sprintf('(%s)', char(strjoin(string(size(data)), ', ')));
    payload = permute(data, ndims(data):-1:1);   % column-major of the transpose = C order
end

h = sprintf('{''descr'': ''%s'', ''fortran_order'': False, ''shape'': %s, }', char(descr), shapeTxt);
total = 10 + numel(h) + 1;                  % magic(6) + version(2) + len(2) + h + \n
pad = mod(64 - mod(total, 64), 64);
h = [h repmat(' ', 1, pad) newline];

fid = fopen(filename, 'w', 'ieee-le');
if fid < 0; error('writeNPY:open', 'Cannot open %s for writing.', filename); end
closer = onCleanup(@() fclose(fid)); %#ok<NASGU>
fwrite(fid, uint8([147 78 85 77 80 89]), 'uint8');   % \x93NUMPY
fwrite(fid, uint8([1 0]), 'uint8');                  % version 1.0
fwrite(fid, uint16(numel(h)), 'uint16');
fwrite(fid, h, 'char');
fwrite(fid, payload(:), prec);
end


function d = descrFor(x)
switch class(x)
    case 'int8',    d = "|i1";
    case 'uint8',   d = "|u1";
    case 'int16',   d = "<i2";
    case 'uint16',  d = "<u2";
    case 'int32',   d = "<i4";
    case 'uint32',  d = "<u4";
    case 'int64',   d = "<i8";
    case 'uint64',  d = "<u8";
    case 'single',  d = "<f4";
    case 'double',  d = "<f8";
    case 'logical', d = "|b1";
    otherwise
        error('writeNPY:class', 'Unsupported class %s.', class(x));
end
end


function [prec, cls] = precFor(descr)
switch char(descr)
    case {'|i1', '<i1'}, prec = 'int8';   cls = 'int8';
    case {'|u1', '<u1'}, prec = 'uint8';  cls = 'uint8';
    case '<i2',          prec = 'int16';  cls = 'int16';
    case '<u2',          prec = 'uint16'; cls = 'uint16';
    case '<i4',          prec = 'int32';  cls = 'int32';
    case '<u4',          prec = 'uint32'; cls = 'uint32';
    case '<i8',          prec = 'int64';  cls = 'int64';
    case '<u8',          prec = 'uint64'; cls = 'uint64';
    case '<f4',          prec = 'single'; cls = 'single';
    case '<f8',          prec = 'double'; cls = 'double';
    case '|b1',          prec = 'uint8';  cls = 'logical';
    otherwise
        error('writeNPY:dtype', 'Unsupported dtype %s.', descr);
end
end
