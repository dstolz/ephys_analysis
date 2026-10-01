function nBytes = writeNPY(filename, data, descr, opts)
%writeNPY  Write a numeric, logical or text array as a little-endian NumPy .npy file.
%   writeNPY(filename, data) writes DATA in C order with a dtype inferred
%   from its class (int8..int64, uint8..uint64, single, double, logical;
%   string / char / cellstr as fixed-width unicode '<Un', n the longest
%   text, BMP characters only).
%   writeNPY(filename, data, descr) forces the NumPy dtype string, e.g.
%   '<i8', '<i4', '<f4', '<f8', '<u2', '|b1'; DATA is cast to it.
%
%   A vector is written as a 1-D array of shape (n,); an N-D array keeps its
%   MATLAB shape (a, b, c, ...) and is stored in C order, so readNPY (and
%   NumPy) return the same array back. This is the writer counterpart of
%   READNPY; it exists so tests and tools can build phy / Kilosort4 fixtures
%   (spike_times.npy, templates.npy, ...) without NumPy.
%
%   Shape=... says how the MATLAB shape maps to NumPy's:
%     "auto"       (default) a vector 1-D, anything else its full shape
%     "full"       the full MATLAB shape, so a [1 x 2] row stays (1, 2)
%     "vector"     1-D (n,) whatever the shape
%     "scalar"     0-d, shape (); DATA must hold one element
%     "transpose"  a 2-D DATA written as DATA.' (shape (columns, rows))
%                  without forming the transpose: its column-major bytes
%                  are the transpose's C order
%   FILENAME may also be the id of a file open for writing (fopen with
%   'ieee-le'): the array is written at the current position and the file
%   is left open. NBYTES is the number of bytes written.
%
%   See also readNPY, writeNPZ.

arguments
    filename
    data
    descr (1,1) string = ""
    opts.Shape (1,1) string {mustBeMember(opts.Shape, ["auto" "full" "vector" "scalar" "transpose"])} = "auto"
end

if ischar(data) || iscellstr(data); data = string(data); end
isText = isstring(data);
if isText; data(ismissing(data)) = ""; end
if descr == ""
    descr = descrFor(data);
end
if isText
    if ~startsWith(descr, "<U")
        error('writeNPY:dtype', 'Text is written as unicode (<Un), not %s.', descr);
    end
    width = str2double(extractAfter(descr, 2));
    prec = 'uint32';
else
    [prec, cls] = precFor(descr);
    data = cast(data, cls);
end

shape = opts.Shape;
if shape == "auto"
    if isvector(data); shape = "vector"; else; shape = "full"; end
end
switch shape
    case "vector"
        shapeTxt = sprintf('(%d,)', numel(data));
        payload = data(:);
    case "scalar"
        if numel(data) ~= 1
            error('writeNPY:shape', 'Shape "scalar" needs one element; DATA has %d.', numel(data));
        end
        shapeTxt = '()';
        payload = data;
    case "transpose"
        if ~ismatrix(data)
            error('writeNPY:shape', 'Shape "transpose" needs a 2-D array.');
        end
        shapeTxt = sprintf('(%d, %d)', size(data, 2), size(data, 1));
        payload = data;                               % column-major = C order of DATA.'
    otherwise
        shapeTxt = sprintf('(%s)', char(strjoin(string(size(data)), ', ')));
        payload = permute(data, ndims(data):-1:1);   % column-major of the transpose = C order
end
if isText
    payload = textCodes(payload(:), width);           % [width x n] uint32: each text contiguous
end

h = sprintf('{''descr'': ''%s'', ''fortran_order'': False, ''shape'': %s, }', char(descr), shapeTxt);
total = 10 + numel(h) + 1;                  % magic(6) + version(2) + len(2) + h + \n
pad = mod(64 - mod(total, 64), 64);
h = [h repmat(' ', 1, pad) newline];

if isnumeric(filename)
    fid = filename;
else
    fid = fopen(string(filename), 'w', 'ieee-le');
    if fid < 0; error('writeNPY:open', 'Cannot open %s for writing.', filename); end
    closer = onCleanup(@() fclose(fid));
end
fwrite(fid, uint8([147 78 85 77 80 89]), 'uint8');   % \x93NUMPY
fwrite(fid, uint8([1 0]), 'uint8');                  % version 1.0
fwrite(fid, uint16(numel(h)), 'uint16');
fwrite(fid, h, 'char');
fwrite(fid, payload(:), prec);
nBytes = 10 + numel(h) + numel(payload) * elementBytes(prec);
end


function C = textCodes(s, width)
%textCodes  Texts S -> [width x numel(S)] uint32 code points, zero-padded (NumPy '<Un').
C = zeros(width, numel(s), 'uint32');
for k = 1:numel(s)
    c = uint32(char(s(k)));
    if numel(c) > width
        error('writeNPY:text', 'Text "%s" is longer than the dtype''s %d characters.', s(k), width);
    end
    C(1:numel(c), k) = c;
end
end


function n = elementBytes(prec)
switch prec
    case {'int8', 'uint8'},   n = 1;
    case {'int16', 'uint16'}, n = 2;
    case {'int32', 'uint32', 'single'}, n = 4;
    otherwise,                n = 8;
end
end


function d = descrFor(x)
if isstring(x)
    d = "<U" + max([1; strlength(x(:))]);
    return
end
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
