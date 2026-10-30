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
%   The block is the file's alone: writeManifest carries it over from the
%   file each time it rewrites it, so a Scan, a pipeline step or the app
%   keeps what a script added, also while the app has the dataset open. No
%   step reads it. To read it back:
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
manifests = cell(size(targets));
for k = 1:numel(targets)
    files(k) = manifestOf(targets{k});
    manifests{k} = withFields(files(k), names, values);
end
for k = 1:numel(targets)
    writeJsonFile(files(k), manifests{k});
end
c = cellfun(@(m) m.custom, manifests, 'UniformOutput', false);
if isscalar(c); c = c{1}; end
end

function m = withFields(file, names, values)
%withFields  The manifest in FILE with the fields in its custom block, not yet written.
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
m.custom = c;
m.updated = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
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
