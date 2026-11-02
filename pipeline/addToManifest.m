function c = addToManifest(target, varargin)
%addToManifest  Add your own fields to a dataset's manifest.
%   addToManifest(TARGET, Name=Value, ...) writes each Name and Value to the
%   "custom" block of the dataset's <Name>_manifest.json and changes nothing
%   else but the file's "updated" time. A name already there gets the new
%   value; the block's other fields stay.
%   addToManifest(TARGET, S) takes the fields from the scalar struct S, and
%   addToManifest(TARGET, S, Name=Value, ...) adds the pairs to them; a pair
%   wins over a field of S with its name.
%   C = addToManifest(...) returns the whole block as it now stands; a cell
%   array of them, one per dataset, for an array of datasets.
%
%   TARGET is one of
%     an EphysDataset  a manifest is written first when it has none yet; an
%                      array adds to each, and an empty one does nothing
%     a folder         holding one dataset manifest (session_manifest.json,
%                      the Copy tab's, does not count)
%     a file           the manifest itself
%
%   A field of S replaces the field of its name whole: a nested struct is not
%   merged with the one already in the file.
%
%   Each name must be a valid MATLAB field name. A value is anything
%   jsonencode takes: numbers, text, logicals, structs, cells. It comes back
%   as jsondecode returns it, so a row vector reads as a column and a
%   string array as a cell column, and NaN is written as null, which reads
%   as [].
%
%   Only the custom block and the "updated" time change: the block is
%   spliced into the file's text, so nothing else in the file is decoded and
%   encoded again (a null stays null, a list of one stays a list). A dataset
%   holds the block as its Custom property: applyManifest reads it and
%   writeManifest writes it, and writeManifest also reads back a block
%   added since the object last read or wrote the file, so a Scan, a
%   pipeline step or the app keeps what a script added, also while the app
%   has the dataset open. No step reads it. To read it back:
%     m = EphysDataset.readManifest(file);  m.custom
%
%   The manifest counts in outputsStamp, so a dataset's results in a
%   DatasetRuns folder are computed again after this, as after a tag edit.
%
%   Errors (nothing is written): addToManifest:BadInput, :BadValue,
%   :NotFound (no such file or folder), :NoManifest, :Ambiguous (a folder of
%   several manifests: name the file), :Unreadable (not JSON, an unknown
%   schema, or a custom field that is not an object). An array of datasets is
%   read through first, so one bad manifest stops them all.
%
%   Example
%     info.surgeon = "DS";
%     info.depth_um = 1200;
%     addToManifest("D:\EPHYS\subjA\subjA_260101_120000", info);
%     addToManifest(P.Datasets, info, batch="pilot");
%
%   See also EphysDataset.writeManifest, EphysDataset.readManifest,
%   ManifestViewerApp, TagSet.

[names, values] = fieldsToAdd(varargin);
if isa(target, 'EphysDataset')
    targets = arrayfun(@(d) d, target, 'UniformOutput', false);
else
    targets = {target};
end

files = strings(size(targets));
texts = cell(size(targets));
blocks = cell(size(targets));
for k = 1:numel(targets)
    files(k) = manifestOf(targets{k});
    [texts{k}, blocks{k}] = withFields(files(k), names, values);
end
for k = 1:numel(targets)
    writeJsonFile(files(k), texts{k}, Text=true);
end
c = blocks;
if isscalar(c); c = c{1}; end
end

function [txt, c] = withFields(file, names, values)
%withFields  The text of the manifest in FILE with the fields in its custom
%   block, not yet written, and the block as jsondecode reads it. Only the
%   custom and updated members of the text change.
[m, why] = EphysDataset.readManifest(file);
if why ~= ""
    error('addToManifest:Unreadable', 'Cannot add to %s: %s.', file, why);
end
c = struct();
if isfield(m, 'custom'); c = m.custom; end
if isempty(c); c = struct(); end   % "custom": [] in a hand-edited file
if ~isstruct(c) || ~isscalar(c)
    error('addToManifest:Unreadable', 'Cannot add to %s: its custom field is not an object.', file);
end

for k = 1:numel(names)
    c.(names{k}) = values{k};
end
stamp = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
txt = fileread(file);
txt = setMember(txt, 'custom', indented(jsonencode(c, 'PrettyPrint', true)));
txt = setMember(txt, 'updated', jsonencode(stamp));
try
    decoded = jsondecode(txt);
catch ME
    error('addToManifest:BadValue', 'Cannot add these fields to %s: %s', file, ME.message);
end
c = decoded.custom;
end

function txt = setMember(txt, key, valueText)
%setMember  TXT with the value of its top-level member KEY replaced by VALUETEXT.
%   TXT is the text of a JSON object and VALUETEXT a JSON value. A member
%   that is not there is added after the last one. Nothing else in TXT is
%   touched: it is not decoded. The text is read as its strings and
%   brackets (a string may hold any of the others), counting the depth.
[tok, st, en] = regexp(txt, '"(?:[^"\\]|\\.)*"|[{}\[\],:]', 'match', 'start', 'end');
if isempty(tok)
    error('addToManifest:Unreadable', 'The manifest is not a JSON object.');
end
c = cellfun(@(t) t(1), tok);
after = cumsum((c == '{' | c == '[') - (c == '}' | c == ']'));
before = [0, after(1:end-1)];
isKey = c == '"' & before == 1 & [c(2:end) == ':', false] & strcmp(tok, ['"' key '"']);
ki = find(isKey, 1);
if ~isempty(ki)
    a = en(ki + 1) + find(~isspace(txt(en(ki + 1) + 1:end)), 1);   % where the value starts
    j = ki + 1 + find(before(ki + 2:end) == 1 & (c(ki + 2:end) == ',' | c(ki + 2:end) == '}'), 1);
    b = find(~isspace(txt(1:st(j) - 1)), 1, 'last');                % where it ends
    txt = [txt(1:a - 1), valueText, txt(b + 1:end)];
else
    close = find(c == '}' & before == 1 & after == 0, 1);
    p = find(~isspace(txt(1:st(close) - 1)), 1, 'last');            % the last member's end
    sep = ',';
    if txt(p) == '{'; sep = ''; end
    txt = [txt(1:p), sep, newline, '    "', key, '": ', valueText, txt(p + 1:end)];
end
end

function t = indented(t)
%indented  The pretty-printed JSON T for a member of the top-level object: its lines
%   after the first indented one level.
t = strrep(t, newline, [newline '    ']);
end

function [names, values] = fieldsToAdd(args)
%fieldsToAdd  The names and values asked for, checked, as cell arrays.
names = {};
values = {};
if ~isempty(args) && isstruct(args{1}) && isscalar(args{1})
    names = fieldnames(args{1}).';
    values = struct2cell(args{1}).';
    args = args(2:end);
end
if mod(numel(args), 2) ~= 0
    error('addToManifest:BadInput', 'Give Name=Value pairs, a scalar struct, or the struct and then pairs.');
end
names = [names, args(1:2:end)];
values = [values, args(2:2:end)];
if isempty(names)
    error('addToManifest:BadInput', 'Nothing to add: give Name=Value pairs or a struct with fields.');
end
for k = 1:numel(names)
    if ~(ischar(names{k}) || (isstring(names{k}) && isscalar(names{k}))) || ~isvarname(names{k})
        error('addToManifest:BadInput', 'Field %d''s name is not a valid MATLAB field name.', k);
    end
    names{k} = char(names{k});
    try
        jsonencode(values{k});
    catch ME
        error('addToManifest:BadValue', 'Cannot write %s to a manifest (%s): %s', ...
            names{k}, class(values{k}), ME.message);
    end
end
end

function file = manifestOf(target)
%manifestOf  The manifest file of an EphysDataset, a folder or a file path.
if isa(target, 'EphysDataset') && isscalar(target)
    file = target.manifestFile();
    if ~isfile(file) && ~target.writeManifest()
        error('addToManifest:NoManifest', 'Could not write a manifest for %s.', target.Name);
    end
    return
end
if ~((ischar(target) && isrow(target)) || (isstring(target) && isscalar(target)))
    error('addToManifest:BadInput', 'TARGET must be one EphysDataset, a folder or a manifest file.');
end
target = string(target);
if isfile(target)
    file = target;
elseif isfolder(target)
    d = dir(fullfile(target, '*_manifest.json'));
    d = d(~strcmpi({d.name}, 'session_manifest.json'));
    if isempty(d)
        error('addToManifest:NoManifest', ...
            'No dataset manifest in %s. EphysDataset(folder).writeManifest() writes one.', target);
    elseif ~isscalar(d)
        error('addToManifest:Ambiguous', '%d dataset manifests in %s (%s): name the file.', ...
            numel(d), target, strjoin(string({d.name}), ", "));
    end
    file = string(fullfile(d.folder, d.name));
else
    error('addToManifest:NotFound', 'No such file or folder: %s', target);
end
end
