function onApplyExclude(obj, scope)
%onApplyExclude  Set per-recording channel exclusions from the Probe tab field.
%   scope = "selected" -> the active dataset (also the path taken when the
%                         edit field is committed)
%   scope = "all"      -> every dataset in the project
%
%   The field holds 1-based channels to drop from Kilosort4 sorting (e.g.
%   "1,5,32-40"). Channels are validated against each dataset's NumChannels;
%   out-of-range entries are dropped with a warning in the status label. The
%   exclusions live on EphysDataset.ExcludeChannels and are applied as a derived
%   probe at run time (see EphysDataset.runKilosort); nothing on disk changes here.
%   Text that does not parse (EphysPipelineConfig.parseOrderedList) changes
%   nothing: an alert says why and the field shows the list in force again.

if isempty(obj.Project) || obj.Project.NumDatasets == 0
    return
end
if obj.refuseWhileRunning("Exclude channels")
    obj.syncExcludeField();
    return
end
try
    ch = reshape(unique(EphysPipelineConfig.parseOrderedList(obj.ExcludeChannelsField.Value, "Exclude channels")), 1, []);
catch ME
    obj.syncExcludeField();
    uialert(obj.Fig, string(ME.message) + newline + "The exclusions are unchanged.", "Exclude channels");
    return
end

switch scope
    case "selected"
        d = obj.currentDataset();
        if isempty(d)
            % Triggered by editing the field before a scan: guide, don't
            % pop a modal (this fires on every commit).
            obj.setStatus("Channel exclusions not applied: no dataset scanned.", ...
                "Scan a project on the Project tab, then re-enter exclusions.");
            return
        end
        targets = d;
    case "all"
        targets = obj.Project.Datasets;
    otherwise
        return
end

nTrim = 0;
for k = 1:numel(targets)
    t = targets(k);
    keep = ch;
    if ~isnan(t.NumChannels)
        keep = ch(ch <= t.NumChannels);
        nTrim = nTrim + (numel(ch) - numel(keep));
    end
    t.ExcludeChannels = keep;
end
obj.saveManifests(targets);   % persist the updated exclusions

% Reflect the (possibly trimmed) list for the active dataset and redraw.
obj.syncExcludeField();
obj.refreshDatasetsTable();
obj.onProbeSelected();   % refresh the channel-count check / preview marks

if scope == "all"
    msg = sprintf("Excluded %d channel(s) on %d dataset(s).", numel(ch), numel(targets));
else
    msg = sprintf("Excluded %d channel(s) on '%s'.", ...
        numel(targets(1).ExcludeChannels), targets(1).Name);
end
if nTrim > 0
    msg = msg + sprintf(" (%d out-of-range entr(y/ies) ignored.)", nTrim);
end
obj.ScanStatusLabel.Text = msg;
obj.setStatus(msg);
end
