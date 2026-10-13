function T = readUnitMapping(file)
%readUnitMapping  Read a unit-mapping CSV: which unit is the same cell in each dataset.
%   T = readUnitMapping(FILE) reads the CSV a session plot with match
%   "mapping" names (combineSessions Mapping=): one row per cell, the first
%   column "cell" (the cell's name, text), then one column per dataset key
%   (the Data tab's Key column, e.g. SYNTH-01/260908_103000; names kept as
%   they are, since keys hold "/") holding that dataset's unit id(s):
%
%     cell,SYNTH-01/260908_103000,SYNTH-01/260909_101500
%     cellA,42,17
%     cellB,8,
%
%   A unit id is a number, or text such as "3 7" for two units that are
%   averaged; an empty field means the cell was not found in that dataset.
%   A key column holding only numbers (and empty fields) is read as a
%   numeric column with NaN for an empty field; one with any text such as
%   "2 3" is a string column with missing for an empty field. The column
%   "cell" is found whatever its case. T is a table whose variable names
%   are the header's own (VariableNamingRule "preserve").
%
%   Errors: readUnitMapping:NoFile (the file does not exist),
%   readUnitMapping:NoCell (no column "cell").
%
%   See also writeUnitMapping, combineSessions, sessionResults.
arguments
    file (1,1) string
end
if ~isfile(file)
    error('readUnitMapping:NoFile', 'The unit mapping file %s does not exist.', file);
end
o = detectImportOptions(file, 'FileType', 'text', 'Delimiter', ',', 'VariableNamingRule', 'preserve', 'TextType', 'string');
names = string(o.VariableNames);
c = find(strcmpi(names, "cell"), 1);
if isempty(c)
    error('readUnitMapping:NoCell', 'The unit mapping file %s has no column "cell" (its columns: %s).', ...
        file, strjoin(names, ", "));
end
o = setvartype(o, names, 'string');     % read as text: the import must not guess "2 3" away as a number
o = setvaropts(o, names, 'WhitespaceRule', 'trim', 'EmptyFieldRule', 'missing');
T = readtable(file, o);
T.Properties.VariableNames{c} = 'cell';
T.cell = string(T.cell);
T.cell(ismissing(T.cell)) = "";
for k = setdiff(1:width(T), c)
    name = T.Properties.VariableNames{k};
    v = string(T.(name));
    blank = ismissing(v) | strtrim(v) == "";
    num = str2double(v);
    if all(~isnan(num(~blank)))
        num(blank) = NaN;
        T.(name) = num;                 % every id is a number
    else
        v(blank) = missing;
        T.(name) = v;                   % some are text such as "2 3"
    end
end
end
