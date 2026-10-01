function S = readNPZ(file, vars)
%readNPZ  Read a NumPy .npz archive into a struct.
%   S = readNPZ(FILE) returns one field per <name>.npy member of FILE, read
%   by readNPY (numeric, bool and unicode text arrays; a 0-d array comes
%   back as a scalar, a 1-D array as a column). Members that are not .npy
%   are skipped.
%   S = readNPZ(FILE, VARS) returns only the members named in VARS.
%
%   Stored members (numpy.savez, writeNPZ) are read in place from the
%   archive, so reading one small member of a large file is quick; an
%   archive with compressed members (numpy.savez_compressed) is extracted
%   to a temporary folder first. zip64 archives are read.
%
%   See also writeNPZ, readNPY.

arguments
    file (1,1) string
    vars (1,:) string = string.empty(1,0)
end

if ~isfile(file)
    error('readNPZ:NoFile', 'No file %s.', file);
end
fid = fopen(file, 'r', 'l');
if fid < 0; error('readNPZ:open', 'Cannot open %s.', file); end
closer = onCleanup(@() fclose(fid));

members = centralDirectory(fid, file);
isNpy = endsWith(members.name, ".npy", 'IgnoreCase', true);
names = regexprep(members.name, '\.npy$', '', 'ignorecase');
want = isNpy;
if ~isempty(vars)
    want = want & ismember(names, vars);
    missing = setdiff(vars, names(isNpy));
    if ~isempty(missing)
        error('readNPZ:NoMember', '%s has no member(s) %s.', file, strjoin(missing + ".npy", ", "));
    end
end

S = struct();
if any(members.method(want) ~= 0)
    % compressed members: let unzip inflate them
    tmp = string(tempname);
    mkdir(tmp);
    cleaner = onCleanup(@() rmdir(tmp, 's'));
    unzip(file, tmp);
    for k = find(want)
        S.(matlab.lang.makeValidName(names(k))) = readNPY(fullfile(tmp, members.name(k)));
    end
    clear cleaner
    return
end
for k = find(want)
    fseek(fid, members.offset(k), 'bof');
    h = fread(fid, 30, '*uint8');
    if numel(h) < 30 || typecast(h(1:4), 'uint32') ~= 0x04034b50
        error('readNPZ:format', '%s: no local header for %s.', file, members.name(k));
    end
    skip = double(typecast(h(27:28), 'uint16')) + double(typecast(h(29:30), 'uint16'));
    fseek(fid, members.offset(k) + 30 + skip, 'bof');
    S.(matlab.lang.makeValidName(names(k))) = readNPY(fid);
end
end


function m = centralDirectory(fid, file)
%centralDirectory  Name, compression method and local-header offset of every member.
fseek(fid, 0, 'eof');
len = ftell(fid);
tailLen = min(len, 22 + 65535);
fseek(fid, len - tailLen, 'bof');
tail = fread(fid, tailLen, '*uint8');
sig = uint8([80 75 5 6]);                                   % PK\5\6, end of central directory
at = strfind(tail.', sig);
if isempty(at)
    error('readNPZ:format', '%s is not a zip (.npz) archive.', file);
end
e = tail(at(end):end);
nEntries = double(typecast(e(11:12), 'uint16'));
cdSize = double(typecast(e(13:16), 'uint32'));
cdStart = double(typecast(e(17:20), 'uint32'));
eocdPos = len - tailLen + at(end) - 1;
if nEntries == 65535 || cdSize == 2^32 - 1 || cdStart == 2^32 - 1
    fseek(fid, eocdPos - 20, 'bof');                         % zip64 locator
    loc = fread(fid, 20, '*uint8');
    if numel(loc) < 20 || typecast(loc(1:4), 'uint32') ~= 0x07064b50
        error('readNPZ:format', '%s: zip64 end-of-directory locator not found.', file);
    end
    fseek(fid, double(typecast(loc(9:16), 'uint64')), 'bof');
    z = fread(fid, 56, '*uint8');
    nEntries = double(typecast(z(33:40), 'uint64'));
    cdSize = double(typecast(z(41:48), 'uint64'));
    cdStart = double(typecast(z(49:56), 'uint64'));
end
fseek(fid, cdStart, 'bof');
cd = fread(fid, cdSize, '*uint8');
m = struct('name', strings(1, nEntries), 'method', zeros(1, nEntries), 'offset', zeros(1, nEntries));
p = 1;
for k = 1:nEntries
    if typecast(cd(p:p+3), 'uint32') ~= 0x02014b50
        error('readNPZ:format', '%s: corrupt central directory.', file);
    end
    method = double(typecast(cd(p+10:p+11), 'uint16'));
    sizes = double(typecast(cd(p+20:p+27), 'uint32'));      % compressed, uncompressed
    nName = double(typecast(cd(p+28:p+29), 'uint16'));
    nExtra = double(typecast(cd(p+30:p+31), 'uint16'));
    nComment = double(typecast(cd(p+32:p+33), 'uint16'));
    offset = double(typecast(cd(p+42:p+45), 'uint32'));
    name = char(cd(p+46:p+45+nName).');
    extra = cd(p+46+nName:p+45+nName+nExtra);
    if offset == 2^32 - 1
        offset = zip64Offset(extra, sizes);
    end
    m.name(k) = string(name);
    m.method(k) = method;
    m.offset(k) = offset;
    p = p + 46 + nName + nExtra + nComment;
end
end


function offset = zip64Offset(extra, sizes)
%zip64Offset  The local-header offset in a zip64 extra field: after the
%   uncompressed and compressed sizes that are 0xFFFFFFFF in the header.
q = 1;
while q + 3 <= numel(extra)
    id = typecast(extra(q:q+1), 'uint16');
    n = double(typecast(extra(q+2:q+3), 'uint16'));
    if id == 1
        skip = 8 * sum(sizes == 2^32 - 1);
        offset = double(typecast(extra(q+4+skip:q+11+skip), 'uint64'));
        return
    end
    q = q + 4 + n;
end
error('readNPZ:format', 'A zip64 member has no zip64 extra field.');
end
