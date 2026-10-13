function files = writeExtractEvents(obj, D)
%writeExtractEvents  Bring the derived events in the extract's events up to date.
%   FILES = ds.writeExtractEvents() puts the derived events marked
%   InDataset (readDerivedEvents: the behavior file's) into the events of
%   the existing extract, <outputFolder>/<Name>_extract.mat or its
%   per-signal-type files, and takes out the derived lines it held before
%   that are no longer marked (or defined). The extract's info.derivedEvents
%   lists the derived lines in its events (name, line, conditions,
%   combine, expression, description). Only the events and info variables
%   are rewritten (save -append), only in a file that changes, so the
%   signals are not derived again. Returns the files rewritten.
%   ds.writeExtractEvents(D) takes the derived events D (deriveEvents' D)
%   instead of the behavior file's.
%
%   behaviorToMat calls it after writing the behavior file; toMat adds the
%   same lines to a new extract.
%
%   See also EphysDataset.readDerivedEvents, EphysDataset.toMat, deriveEvents.

files = strings(1, 0);
if nargin < 2
    D = obj.readDerivedEvents();
end
f = string(fullfile(obj.outputFolder(), obj.Name + "_extract.mat"));
if ~isfile(f)
    f = EphysDataset.signalFiles(f, ["LFP" "MUA" "SPIKE" "AUX"]);
    f = f(isfile(f));
end
for k = 1:numel(f)
    w = whos('-file', f(k));
    names = string({w.name});
    if ~all(ismember(["events" "info"], names))
        continue
    end
    S = load(f(k), 'events', 'info');
    [S.events, S.info, changed] = mergeDerivedEvents(S.events, S.info, D);
    if changed
        save(f(k), '-struct', 'S', 'events', 'info', '-append');
        files(end+1) = f(k); %#ok<AGROW>
    end
end
end
