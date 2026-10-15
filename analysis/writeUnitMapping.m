function file = writeUnitMapping(file, T, opts)
%writeUnitMapping  Write a unit-mapping table as the CSV readUnitMapping reads.
%   FILE = writeUnitMapping(FILE, T) writes the table T (a variable "cell",
%   the cells' names, then one variable per dataset key holding that
%   dataset's unit id(s): numbers, or text such as "3 7") to the CSV FILE,
%   header first. A NaN or missing value is an empty field; a field with a
%   comma, a quote or a line break is quoted. The file is written to a
%   temporary name and moved into place, so a failed write never leaves half
%   a mapping behind; the folder is made when it is not there. Returns FILE.
%
%   Options
%     Overwrite  true (default): replace FILE if it is there; false:
%                writeUnitMapping:Exists then
%
%   Errors: writeUnitMapping:NoCell (T has no variable "cell"),
%   writeUnitMapping:Exists, writeUnitMapping:CannotWrite.
%
%   See also readUnitMapping, combineSessions, figureSessionObservations.
arguments
    file (1,1) string
    T table
    opts.Overwrite (1,1) logical = true
end
names = string(T.Properties.VariableNames);
if ~ismember("cell", names)
    error('writeUnitMapping:NoCell', 'The mapping needs a variable "cell" (its variables: %s).', strjoin(names, ", "));
end
if isfile(file) && ~opts.Overwrite
    error('writeUnitMapping:Exists', '%s exists; pass Overwrite=true to replace it.', file);
end
[folder, base] = fileparts(file);
if strlength(folder) > 0 && ~isfolder(folder)
    [ok, msg] = mkdir(folder);
    if ~ok
        error('writeUnitMapping:CannotWrite', 'Could not create %s: %s', folder, msg);
    end
end
n = height(T);
lines = strings(n + 1, 1);
head = strings(1, numel(names));
for c = 1:numel(names)
    head(c) = field(names(c));
end
lines(1) = strjoin(head, ",");
cols = cell(1, numel(names));
for c = 1:numel(names)
    cols{c} = cellText(T.(names(c)), n);
end
for r = 1:n
    row = strings(1, numel(names));
    for c = 1:numel(names)
        row(c) = field(cols{c}(r));
    end
    lines(r + 1) = strjoin(row, ",");
end
tmp = fullfile(folder, "~" + base + ".partial.csv");
fid = fopen(tmp, 'w', 'n', 'UTF-8');
if fid < 0
    error('writeUnitMapping:CannotWrite', 'Could not write %s.', tmp);
end
try
    fprintf(fid, '%s', char(strjoin(lines, newline) + newline));
    fclose(fid);
catch ME
    fclose(fid);
    if isfile(tmp); delete(tmp); end
    rethrow(ME);
end
[ok, msg] = movefile(tmp, file, 'f');
if ~ok
    if isfile(tmp); delete(tmp); end
    error('writeUnitMapping:CannotWrite', 'Could not move %s to %s: %s', tmp, file, msg);
end
end


function s = cellText(v, n)
%cellText  A table column as text, one string per row ("" for NaN / missing).
if iscell(v); v = string(v); end
if isnumeric(v) || islogical(v)
    v = double(v);
    s = strings(n, 1);
    for k = 1:n
        if isfinite(v(k)); s(k) = string(num2str(v(k), 15)); end
    end
else
    s = string(v);
    s(ismissing(s)) = "";
end
s = reshape(s, [], 1);
end


function t = field(s)
%field  One CSV field: quoted when it holds a comma, a quote or a line break.
s = string(s);
if contains(s, [",", """", newline, char(13)])
    t = """" + replace(s, """", """""") + """";
else
    t = s;
end
end
