function info = writeNPZ(file, S, opts)
%writeNPZ  Write the fields of a struct as a NumPy .npz archive.
%   writeNPZ(FILE, S) writes each field of the scalar struct S as a
%   <field>.npy member of FILE (writeNPY), the archive numpy.load reads:
%       d = numpy.load(FILE); d["<field>"]
%   The archive is uncompressed (as numpy.savez writes it), so writing
%   costs the disk time only, and uses zip64 wherever a member or the
%   archive passes 4 GB. FILE is written as given: write to a temporary
%   name and rename it when a half-written archive must never show.
%
%   writeNPZ(FILE, S, Shapes=T) gives writeNPY's Shape for the fields
%   named in struct T ("auto" | "full" | "vector" | "scalar" |
%   "transpose"); the others use "auto" (a vector 1-D, anything else its
%   full MATLAB shape). Pass "full" for a [k x 2] table that may have one
%   row, "vector" for a list that may have one element, "scalar" for a
%   0-d value.
%   writeNPZ(FILE, S, Descr=T) forces a field's NumPy dtype (writeNPY's
%   DESCR), e.g. struct('index', "<i8").
%
%   writeNPZ(FILE, S, Zip64=true) writes zip64 records whatever the sizes
%   (to test readers on them without writing 4 GB).
%
%   INFO: file, bytes, members (the .npy names, in field order).
%
%   The member CRCs are computed with java.util.zip.CRC32 (MATLAB's JVM).
%
%   See also writeNPY, readNPZ.

arguments
    file (1,1) string
    S (1,1) struct
    opts.Shapes (1,1) struct = struct()
    opts.Descr (1,1) struct = struct()
    opts.Zip64 (1,1) logical = false
end

names = string(fieldnames(S)).';
fid = fopen(file, 'w+', 'ieee-le');   % w+: each member is read back for its CRC
if fid < 0; error('writeNPZ:open', 'Cannot open %s for writing.', file); end
closer = onCleanup(@() fclose(fid));
[dosTime, dosDate] = dosClock(datetime('now'));

entries = struct('name', {}, 'offset', {}, 'size', {}, 'crc', {}, 'zip64', {});
for n = names
    member = char(n + ".npy");
    shape = "auto";
    if isfield(opts.Shapes, n); shape = string(opts.Shapes.(n)); end
    descr = "";
    if isfield(opts.Descr, n); descr = string(opts.Descr.(n)); end

    % The local header is written before the member, so zip64 is decided
    % from an upper bound of its size (the .npy header is under 64 KB).
    x = S.(n);
    bound = 65536 + numel(x) * 8;
    if isstring(x) || ischar(x) || iscellstr(x)
        bound = 65536 + numel(string(x)) * 4 * max([1; strlength(string(x(:)))]);
    end
    offset = ftell(fid);
    zip64 = opts.Zip64 || bound >= 2^32 - 1 || offset >= 2^32 - 1;
    writeLocalHeader(fid, member, 0, 0, zip64, dosTime, dosDate);
    dataStart = ftell(fid);
    nBytes = writeNPY(fid, x, descr, Shape=shape);
    clear x
    dataEnd = ftell(fid);
    if dataEnd - dataStart ~= nBytes
        error('writeNPZ:write', 'Wrote %d of the %d bytes of %s to %s.', dataEnd - dataStart, nBytes, member, file);
    end
    crc = memberCRC(fid, dataStart, nBytes);
    fseek(fid, offset, 'bof');
    writeLocalHeader(fid, member, crc, nBytes, zip64, dosTime, dosDate);
    fseek(fid, dataEnd, 'bof');
    entries(end+1) = struct('name', member, 'offset', offset, 'size', nBytes, 'crc', crc, 'zip64', zip64); %#ok<AGROW>
end

cdStart = ftell(fid);
for e = entries
    writeCentralHeader(fid, e, dosTime, dosDate);
end
cdEnd = ftell(fid);
nEntries = numel(entries);
cdSize = cdEnd - cdStart;
if opts.Zip64 || nEntries >= 65535 || cdStart >= 2^32 - 1 || cdSize >= 2^32 - 1
    fwrite(fid, uint32(hex2dec('06064b50')), 'uint32');   % zip64 end of central directory
    fwrite(fid, uint64(44), 'uint64');
    fwrite(fid, uint16([45 45]), 'uint16');
    fwrite(fid, uint32([0 0]), 'uint32');
    fwrite(fid, uint64([nEntries nEntries cdSize cdStart]), 'uint64');
    fwrite(fid, uint32(hex2dec('07064b50')), 'uint32');   % its locator
    fwrite(fid, uint32(0), 'uint32');
    fwrite(fid, uint64(cdEnd), 'uint64');
    fwrite(fid, uint32(1), 'uint32');
    n16 = 65535; cdSize32 = 2^32 - 1; cdStart32 = 2^32 - 1;
else
    n16 = nEntries; cdSize32 = cdSize; cdStart32 = cdStart;
end
fwrite(fid, uint32(hex2dec('06054b50')), 'uint32');       % end of central directory
fwrite(fid, uint16([0 0 n16 n16]), 'uint16');
fwrite(fid, uint32([cdSize32 cdStart32]), 'uint32');
fwrite(fid, uint16(0), 'uint16');
bytes = ftell(fid);
clear closer

info = struct('file', file, 'bytes', bytes, 'members', string({entries.name}));
end


function writeLocalHeader(fid, name, crc, nBytes, zip64, dosTime, dosDate)
fwrite(fid, uint32(hex2dec('04034b50')), 'uint32');
if zip64
    fwrite(fid, uint16([45 0 0 dosTime dosDate]), 'uint16');   % version, flags, stored, time, date
    fwrite(fid, uint32([crc 2^32-1 2^32-1]), 'uint32');
    fwrite(fid, uint16([numel(name) 20]), 'uint16');
    fwrite(fid, name, 'char');
    fwrite(fid, uint16([1 16]), 'uint16');                     % zip64 extra: sizes
    fwrite(fid, uint64([nBytes nBytes]), 'uint64');
else
    fwrite(fid, uint16([20 0 0 dosTime dosDate]), 'uint16');
    fwrite(fid, uint32([crc nBytes nBytes]), 'uint32');
    fwrite(fid, uint16([numel(name) 0]), 'uint16');
    fwrite(fid, name, 'char');
end
end


function writeCentralHeader(fid, e, dosTime, dosDate)
zip64 = e.zip64 || e.size >= 2^32 - 1 || e.offset >= 2^32 - 1;
fwrite(fid, uint32(hex2dec('02014b50')), 'uint32');
if zip64
    fwrite(fid, uint16([45 45 0 0 dosTime dosDate]), 'uint16');  % made by, needed, flags, stored, time, date
    fwrite(fid, uint32([e.crc 2^32-1 2^32-1]), 'uint32');
    fwrite(fid, uint16([numel(e.name) 28 0 0 0]), 'uint16');     % name, extra, comment, disk, internal
    fwrite(fid, uint32([0 2^32-1]), 'uint32');                   % external attributes, offset
    fwrite(fid, e.name, 'char');
    fwrite(fid, uint16([1 24]), 'uint16');                       % zip64 extra: sizes, offset
    fwrite(fid, uint64([e.size e.size e.offset]), 'uint64');
else
    fwrite(fid, uint16([20 20 0 0 dosTime dosDate]), 'uint16');
    fwrite(fid, uint32([e.crc e.size e.size]), 'uint32');
    fwrite(fid, uint16([numel(e.name) 0 0 0 0]), 'uint16');
    fwrite(fid, uint32([0 e.offset]), 'uint32');
    fwrite(fid, e.name, 'char');
end
end


function crc = memberCRC(fid, start, nBytes)
%memberCRC  CRC-32 of the NBYTES bytes written at START, read back in chunks.
fseek(fid, start, 'bof');
c = java.util.zip.CRC32();
left = nBytes;
chunk = 2^26;
while left > 0
    b = fread(fid, min(chunk, left), '*int8');
    if isempty(b)
        error('writeNPZ:read', 'Could not read back the member written at byte %d.', start);
    end
    c.update(b, 0, numel(b));
    left = left - numel(b);
end
crc = double(c.getValue());
end


function [t, d] = dosClock(now)
%dosClock  MS-DOS time and date words of NOW (the zip member time stamp).
t = bitor(bitor(bitshift(hour(now), 11), bitshift(minute(now), 5)), floor(second(now) / 2));
d = bitor(bitor(bitshift(year(now) - 1980, 9), bitshift(month(now), 5)), day(now));
end
