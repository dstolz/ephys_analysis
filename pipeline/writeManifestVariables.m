function [s, added] = writeManifestVariables(target, opts)
%writeManifestVariables  Set, change or remove a dataset's variables in its manifest, logging each change.
%   writeManifestVariables(TARGET, Name=N, Value=V, Label=, Units=, Description=)
%   sets one variable: N a valid MATLAB name (probeDepth), V a number or
%   text. A new variable takes Label (default: made from the name,
%   "Probe Depth"), Units and Description ("" when not given); an existing
%   one keeps the label, units and description not given.
%   writeManifestVariables(TARGET, Remove=NAMES) removes those variables
%   (a name that is not there is ignored).
%   writeManifestVariables(TARGET, Set=S) makes S the whole set (a struct
%   of entries, DatasetVariables.entry; struct() removes them all), as the
%   variable dialog does; Renamed= ([k x 2] string, old name then new)
%   logs those as renamed rather than removed and created.
%   Name and Remove may be given together (Remove applies first); Set
%   goes alone.
%
%   [S, ADDED] = writeManifestVariables(...) returns the set as written
%   and the history rows added (DatasetVariables.update). Each change is
%   logged in the manifest's "variable_history" with the time, what
%   changed and the user (created, updated, renamed, removed); a request
%   that changes nothing writes nothing.
%
%   TARGET is one of
%     a file           the manifest itself
%     a folder         holding one dataset manifest (session_manifest.json,
%                      the Copy tab's, does not count)
%     an EphysDataset  its variables are set (setVariables) and its
%                      manifest written (writeManifest), so the object and
%                      the file agree
%   For a file or a folder only "variables", "variable_history" and
%   "updated" change: they are spliced into the file's text, as
%   writeManifestTags splices the tags, so nothing else is decoded and
%   encoded again and no recording is needed. An app or a project holding
%   the dataset reads them back the next time it writes the manifest
%   (EphysDataset.writeManifest merges them, variable by variable); a scan
%   (applyManifest) reads them too.
%
%   The manifest counts in outputsStamp, so a dataset's results in a
%   DatasetRuns folder are computed again after this, as after a tag edit.
%
%   Errors (nothing is written): DatasetVariables:BadName, :BadLabel,
%   :BadValue, :BadUnits, :BadDescription, :Duplicate,
%   writeManifestVariables:BadInput, :NotFound (no such file or folder),
%   :NoManifest, :Ambiguous (a folder of several manifests: name the file),
%   :Unreadable (not JSON or an unknown schema), :NotWritten (an
%   EphysDataset whose manifest could not be written; writeManifest warns
%   why).
%
%   Example
%     out = "S:\outputs\subjA_260101_120000";
%     writeManifestVariables(out, Name="probeDepth", Value=1200, ...
%         Label="Probe Depth", Units="µm", Description="Tip depth below the pia");
%     writeManifestVariables(out, Name="probeDepth", Value=1250);   % an update, logged
%     writeManifestVariables(out, Remove="probeDepth");
%
%   See also DatasetVariables, VariableDialog, EphysDataset.setVariables,
%   writeManifestTags, ManifestViewerApp.

arguments
    target
    opts.Name string = strings(0, 1)
    opts.Value = []
    opts.Label string = strings(0, 1)
    opts.Units string = strings(0, 1)
    opts.Description string = strings(0, 1)
    opts.Remove string = strings(0, 1)
    opts.Set = []
    opts.Renamed string = strings(0, 2)
end

hasSet = isstruct(opts.Set);
hasName = ~isempty(opts.Name);
if hasSet && (hasName || ~isempty(opts.Remove))
    error('writeManifestVariables:BadInput', 'Give Set= alone, or Name=/Value= and Remove=.');
end
if ~hasSet && ~isempty(opts.Set)
    error('writeManifestVariables:BadInput', 'Set= is a struct of variables (struct() for none).');
end
if ~hasSet && ~hasName && isempty(opts.Remove)
    error('writeManifestVariables:BadInput', 'Nothing to do: give Name= and Value=, Remove= or Set=.');
end
if hasName && (~isscalar(opts.Name) || isempty(opts.Value))
    error('writeManifestVariables:BadInput', 'Name= is one variable''s name, and Value= its value.');
end

if isa(target, 'EphysDataset')
    if ~isscalar(target)
        error('writeManifestVariables:BadInput', 'TARGET must be one EphysDataset, a folder or a manifest file.');
    end
    old = target.Variables;
    new = wanted(old, opts, hasSet);
    added = target.setVariables(new, Renamed=opts.Renamed);
    s = target.Variables;
    if isempty(added); return; end
    if ~target.writeManifest()
        error('writeManifestVariables:NotWritten', 'Could not write the manifest of %s.', target.Name);
    end
    return
end

file = manifestOf(target, 'writeManifestVariables');
[m, why] = EphysDataset.readManifest(file);
if why ~= ""
    error('writeManifestVariables:Unreadable', 'Cannot write the variables of %s: %s.', file, why);
end
old = DatasetVariables.parse(fieldOr(m, 'variables'));
h = DatasetVariables.parseHistory(fieldOr(m, 'variable_history'));
new = wanted(old, opts, hasSet);
[s, h, added] = DatasetVariables.update(old, h, new, Renamed=opts.Renamed);
if isempty(added); return; end
txt = fileread(file, 'Encoding', 'UTF-8');
txt = setJsonMember(txt, 'variables', s, 'writeManifestVariables');
txt = setJsonMember(txt, 'variable_history', DatasetVariables.historyCell(h), 'writeManifestVariables');
txt = setJsonMember(txt, 'updated', DatasetVariables.stamp(), 'writeManifestVariables');
try
    jsondecode(txt);
catch ME
    error('writeManifestVariables:Unreadable', 'Cannot write the variables of %s: %s', file, ME.message);
end
writeJsonFile(file, txt, Text=true);
end


function new = wanted(old, opts, hasSet)
%wanted  The whole set asked for, from the set before and the options.
if hasSet
    new = opts.Set;
    return
end
new = old;
for n = reshape(opts.Remove, 1, [])
    if isfield(new, n); new = rmfield(new, n); end
end
if isempty(opts.Name); return; end
n = opts.Name;
[ok, why] = DatasetVariables.checkName(n, setdiff(DatasetVariables.names(new), n));
if ~ok; error('DatasetVariables:BadName', '%s', why); end
if isfield(new, n)
    e = new.(n);
    lab = e.label; uni = e.units; des = e.description;
else
    lab = DatasetVariables.suggestLabel(n); uni = ""; des = "";
end
if ~isempty(opts.Label); lab = opts.Label; end
if ~isempty(opts.Units); uni = opts.Units; end
if ~isempty(opts.Description); des = opts.Description; end
new.(n) = DatasetVariables.entry(lab, opts.Value, Units=uni, Description=des);
end


function v = fieldOr(s, f)
v = [];
if isstruct(s) && isfield(s, f); v = s.(f); end
end
