function [data, shape] = readNPY(filename, opts)
%readNPY  Read a little-endian NumPy .npy array (numeric or bool).
%   DATA = READNPY(FILENAME) reads a NumPy array file written by Kilosort4 /
%   phy (spike_times.npy, spike_clusters.npy, templates.npy, ...) and returns
%   it as a MATLAB array of the matching shape and class. The common dtypes are
%   supported (int/uint 8..64, float32/64, bool) in either C or Fortran order.
%   Numeric data is assumed little-endian, which is what NumPy writes on x86.
%
%   [DATA, SHAPE] = READNPY(FILENAME) also returns the shape recorded in the
%   .npy header (a 1-D array is reported as [n 1]).
%
%   The values are returned in the file's own class; cast with DOUBLE() when
%   you need to do arithmetic (spike sample indices are int64).
%
%   DATA = READNPY(FILENAME, Range=[FIRST LAST]) reads only elements
%   FIRST..LAST (1-based, LAST clipped to the array length) of a 1-D array
%   as a column, seeking past the rest; SHAPE is still the whole array's.
%   Range=[1 0] reads nothing and just returns the shape, of an array of
%   any shape.
%
%   See also EphysPreprocessingApp.loadReviewResults, ChronuxDataset.spikes.

arguments
    filename (1,1) string
    opts.Range (1,2) double = [NaN NaN]
end

fid = fopen(filename, 'r', 'l');
if fid < 0; error('readNPY:open', 'Cannot open %s', filename); end
closer = onCleanup(@() fclose(fid)); %#ok<NASGU>

magic = fread(fid, 6, '*uint8')';
if ~isequal(magic, uint8([147 78 85 77 80 89]))   % \x93NUMPY
    error('readNPY:magic', 'Not a .npy file: %s', filename);
end
verMajor = fread(fid, 1, 'uint8');
fread(fid, 1, 'uint8');   % minor version (unused)
if verMajor >= 2
    headerLen = fread(fid, 1, 'uint32');
else
    headerLen = fread(fid, 1, 'uint16');
end
header = fread(fid, headerLen, '*char')';

descrTok = regexp(header, '''descr''\s*:\s*''([^'']+)''', 'tokens', 'once');
if isempty(descrTok)
    error('readNPY:header', 'No dtype in the .npy header of %s', filename);
end
descr = descrTok{1};
fortran = ~isempty(regexp(header, '''fortran_order''\s*:\s*True', 'once'));
shapeTok = regexp(header, '''shape''\s*:\s*\(([^)]*)\)', 'tokens', 'once');
shape = sscanf(strrep(shapeTok{1}, ',', ' '), '%g')';
if isempty(shape)
    shape = [1 1];
elseif isscalar(shape)
    shape = [shape 1];
end

mtype = npyType(descr);
if all(isfinite(opts.Range))
    n = prod(shape);
    first = max(1, opts.Range(1));
    last = min(opts.Range(2), n);
    nRead = max(0, last - first + 1);
    if nRead > 0 && n ~= max(shape)
        error('readNPY:range', 'Range reads 1-D arrays only; %s has shape %s.', filename, mat2str(shape));
    end
    if nRead > 0 && first > 1
        fseek(fid, (first - 1) * str2double(descr(3:end)), 'cof');
    end
    data = fread(fid, nRead, ['*' mtype]);
    if descr(2) == 'b'; data = logical(data); end
    return
end
data = fread(fid, prod(shape), ['*' mtype]);
if descr(2) == 'b'; data = logical(data); end

if fortran
    data = reshape(data, shape);
else
    data = reshape(data, fliplr(shape));
    data = permute(data, numel(shape):-1:1);
end
end


function mtype = npyType(descr)
%npyType  Map a NumPy dtype string (e.g. '<f4', '|b1') to a MATLAB class name.
kind  = descr(2);
bytes = str2double(descr(3:end));
switch kind
    case 'f'
        if bytes == 8; mtype = 'double'; else; mtype = 'single'; end
    case 'i'
        mtype = sprintf('int%d', bytes * 8);
    case 'u'
        mtype = sprintf('uint%d', bytes * 8);
    case 'b'
        mtype = 'uint8';   % bool stored as one byte; caller casts to logical
    otherwise
        error('readNPY:dtype', 'Unsupported NumPy dtype: %s', descr);
end
end
