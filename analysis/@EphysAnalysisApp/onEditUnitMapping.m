function T = onEditUnitMapping(obj, opts)
%onEditUnitMapping  Edit the selected session plot's unit-mapping file (match "mapping").
%   T = app.onEditUnitMapping() is the Edit... button of the Sessions tab's
%   editor: a modal window (private/editUnitMapping) with a table, a row
%   per cell and a column per included dataset key -- the ticked datasets,
%   or the session plot's datasetKeys for "These datasets", in date order.
%   The table starts from the mapping file (readUnitMapping) when it
%   exists, its ids under each key; Add row / Remove row change the cells;
%   Save writes the file (writeUnitMapping, replacing it), Cancel changes
%   nothing. The file's columns for keys that are not included are kept
%   for the cells that keep their names and written back. With no mapping
%   file in the editor the window first asks where to save one
%   (uiputfile); the file then goes into the editor's Mapping file box.
%   Either way the session plot is marked changed (onConfigChanged
%   "sessions"; the mapping is read when it is computed). Returns the table
%   written ([] when canceled or nothing could be made).
%
%   File=PATH uses that mapping file instead (asking nothing about it);
%   Table=T (a table: variable "cell", then one per dataset key, ids as
%   numbers or text) skips the window and writes T for its keys, for
%   scripts and tests.
%
%   Target="figure" edits the selected figure's mapping instead (the
%   Figures tab's Sessions section: its sessions block's mappingFile and
%   datasetKeys; the file goes into its Mapping file box, onConfigChanged
%   "figure").
%
%   See also onBrowseUnitMapping, onBrowseFigureMapping, readUnitMapping, writeUnitMapping.
arguments
    obj (1,1) EphysAnalysisApp
    opts.File (1,1) string = ""
    opts.Table = []
    opts.Target (1,1) string {mustBeMember(opts.Target, ["session" "figure"])} = "session"
end
T = [];
forFigure = opts.Target == "figure";
if forFigure
    k = obj.SelectedFigure;
    if k < 1 || k > numel(obj.Config.Figures)
        obj.setStatus("Figures: add or select a figure first.");
        return
    end
    sp = obj.Config.Figures(k).sessions;   % the same fields: mappingFile, datasets, datasetKeys
else
    k = obj.SelectedSessionPlot;
    if k < 1 || k > numel(obj.Config.SessionPlots)
        obj.setStatus("Sessions: add or select a session plot first.");
        return
    end
    sp = obj.Config.SessionPlots(k);
end
given = istable(opts.Table);
file = opts.File;
if file == ""; file = sp.mappingFile; end
if file == ""
    start = string(pwd);
    if obj.Config.File ~= ""; start = string(fileparts(obj.Config.File)); end
    [f, p] = uiputfile({'*.csv', 'Unit mapping (*.csv)'}, 'Save the unit mapping as', char(fullfile(start, "unit_mapping.csv")));
    if isvalid(obj.Fig); figure(obj.Fig); end
    if isequal(f, 0); return; end
    file = string(fullfile(p, f));
end
old = [];
if isfile(file)
    try
        old = readUnitMapping(file);
    catch ME
        obj.log("Sessions: could not read " + file + ": " + string(ME.message));
        uialert(obj.Fig, "Could not read " + file + ":" + newline + string(ME.message), "Unit mapping");
        return
    end
end
oldKeys = string.empty(1, 0);
if ~isempty(old)
    oldKeys = string(old.Properties.VariableNames);
    oldKeys(strcmp(oldKeys, "cell")) = [];
end

% the dataset keys that get a column
if given
    keys = string(opts.Table.Properties.VariableNames);
    if ~ismember("cell", keys)
        error('EphysAnalysisApp:UnitMapping', 'The mapping table needs a variable "cell".');
    end
    keys(keys == "cell") = [];
elseif sp.datasets == "list"
    keys = sp.datasetKeys;
elseif ~isempty(obj.Runner)
    keys = reshape(obj.Runner.sessionTable(obj.tickedDatasetIndices()).key, 1, []);
else
    keys = string.empty(1, 0);
end
keys = reshape(keys, 1, []);
if isempty(keys); keys = oldKeys; end
if isempty(keys)
    obj.setStatus("Sessions: no dataset is included to map (scan and tick datasets on the Data tab, or pick them).");
    return
end

if given
    E = unitMappingTable(textCells(opts.Table, keys), keys);
else
    [E, ok] = editUnitMapping(obj.Fig, textCells(old, keys), keys, file, numel(setdiff(oldKeys, keys)));
    if isvalid(obj.Fig); figure(obj.Fig); end
    if ~ok; return; end
end
T = withOtherColumns(E, old, setdiff(oldKeys, keys, 'stable'));
try
    writeUnitMapping(file, T, Overwrite=true);
catch ME
    T = [];
    obj.log("Sessions: saving " + file + " failed: " + string(ME.message));
    uialert(obj.Fig, "Could not save " + file + ":" + newline + string(ME.message), "Unit mapping");
    return
end
obj.log(sprintf("Sessions: unit mapping saved to %s (%d cells, %d datasets).", file, height(T), numel(keys)));
if forFigure
    if file ~= sp.mappingFile; obj.FigureEditor.sesMappingFile.Value = char(file); end
    obj.onConfigChanged("figure");   % the file changed: the matched observations and a drawn preview are out of date
    obj.setStatus(sprintf("Figures: mapping saved to %s (%d cells).", file, height(T)));
    return
end
if file ~= sp.mappingFile
    obj.SessionEditor.mappingFile.Value = char(file);
end
obj.onConfigChanged("sessions");   % the file changed: a drawn preview is out of date
obj.setStatus(sprintf("Sessions: mapping saved to %s (%d cells).", file, height(T)));
end


function C = textCells(T, keys)
%textCells  The rows of mapping table T as a cell array of text: the cell's name, then the ids under each of KEYS.
n = 0;
if ~isempty(T); n = height(T); end
C = cell(n, 1 + numel(keys));
C(:) = {''};
if n == 0; return; end
names = string(T.Properties.VariableNames);
if ismember("cell", names)
    C(:, 1) = cellstr(string(T.cell));
end
for j = 1:numel(keys)
    c = find(names == keys(j), 1);
    if isempty(c); continue; end
    v = T.(c);
    if isnumeric(v)
        s = strings(n, 1);
        for i = 1:n
            if isfinite(v(i)); s(i) = string(num2str(v(i), 15)); end
        end
    else
        s = string(v);
        s(ismissing(s)) = "";
    end
    C(:, 1 + j) = cellstr(s);
end
end


function T = withOtherColumns(E, old, other)
%withOtherColumns  The edited table E followed by the columns OTHER of the file's table OLD, matched to E's cells by name.
T = E;
if isempty(other); return; end
[tf, loc] = ismember(E.cell, string(old.cell));
for name = reshape(other, 1, [])
    v = old.(name);
    if isnumeric(v)
        w = NaN(height(E), 1);
        w(tf) = v(loc(tf));
    else
        w = strings(height(E), 1);
        w(:) = missing;
        w(tf) = string(v(loc(tf)));
    end
    T.(name) = w;
end
end
