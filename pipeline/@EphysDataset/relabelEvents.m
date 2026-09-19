function E = relabelEvents(E, labelField, lineNames)
%relabelEvents  Rename native-keyed digital-line events to their final names.
%   E = EphysDataset.relabelEvents(E, LABELFIELD, LINENAMES) takes a struct
%   with events (one field per line, keyed by the line's native name, as
%   every EphysReader returns them), digInNames (the custom names) and
%   digInNativeNames (aligned), and returns it with:
%     events              re-keyed by each line's final name
%     digInNames          the final names, in line order
%     digInNativeNames    unchanged
%     digInDefaultNames   the name each line has without LINENAMES
%   A line's final name is its LINENAMES entry ("native=name", native names
%   matched without case, e.g. "TTL4=InTrial" or "DIGITAL-IN-04=InTrial")
%   when there is one, else its custom name (LABELFIELD "custom") or native
%   name ("native"). Formats without custom names (Open Ephys TTL lines)
%   have custom = native. Two lines ending with the same name throw
%   EphysDataset:relabelEvents:Duplicate; a LINENAMES entry whose native
%   name is not a line of the recording is ignored.
%
%   See also EphysDataset.parseLineNames, EphysDataset.readData,
%   EphysDataset.digitalEvents.

arguments
    E (1,1) struct
    labelField (1,1) string {mustBeMember(labelField, ["custom" "native"])} = "custom"
    lineNames (1,:) string = string.empty(1,0)
end

[mapNative, mapName] = EphysDataset.parseLineNames(lineNames);
events = struct();
if isfield(E, 'events') && isstruct(E.events); events = E.events; end
custom = string.empty(1, 0); native = string.empty(1, 0);
if isfield(E, 'digInNames'); custom = reshape(string(E.digInNames), 1, []); end
if isfield(E, 'digInNativeNames'); native = reshape(string(E.digInNativeNames), 1, []); end
if numel(custom) ~= numel(native)
    if isempty(native); native = custom; elseif isempty(custom); custom = native; end
end

% One entry per line: the reader's line list first, then any event field
% the list does not name (kept under its own key).
keys = keysOf(native);
fields = string(fieldnames(events)).';
extra = setdiff(fields, keys, 'stable');
nativeAll = [native, extra];
defaultAll = [custom, extra];
if labelField == "native"; defaultAll(1:numel(native)) = native; end
keyAll = [keys, extra];

finalNames = defaultAll;
for k = 1:numel(nativeAll)
    hit = find(strcmpi(mapNative, nativeAll(k)) | strcmpi(mapNative, keyAll(k)), 1);
    if ~isempty(hit); finalNames(k) = mapName(hit); end
end
finalKeys = keysOf(finalNames);
[u, ~, g] = unique(finalKeys);
if numel(u) < numel(finalKeys)
    counts = accumarray(g(:), 1);
    dup = u(counts > 1);
    error('EphysDataset:relabelEvents:Duplicate', ...
        'Two digital lines would both be named "%s" (check Signals.LineNames and the line names).', dup(1));
end

out = struct();
for k = 1:numel(nativeAll)
    if isfield(events, keyAll(k))
        out.(finalKeys(k)) = events.(keyAll(k));
    end
end
E.events = out;
nLines = numel(native);
E.digInNames = finalNames(1:nLines);
E.digInNativeNames = native;
E.digInDefaultNames = defaultAll(1:nLines);
end


function k = keysOf(names)
%keysOf  Events-struct field names of line names (EphysReader.eventKey).
k = reshape(string(matlab.lang.makeValidName(cellstr(names))), 1, []);
end
