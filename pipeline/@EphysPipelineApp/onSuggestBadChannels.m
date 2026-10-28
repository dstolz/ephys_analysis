function onSuggestBadChannels(obj)
%onSuggestBadChannels  Suggest the active dataset's bad channels: a noise
%   floor outside the Good noise band (Reference.BadLow / BadHigh),
%   relative to the median across channels, measured on the recording as
%   it is (EphysDataset.suggestReferenceExclude, as in Ludwig et al. 2009;
%   only the Probe tab's exclusions count as already out). The suggestion
%   replaces the dataset's list, marked "suggested", and is saved in its
%   manifest; edit the Bad field to change it. Each channel's ratio goes to
%   the log. The channels are left out of every step while Leave out bad
%   channels is ticked.
%
%   See also onBadChannelsEdited, refreshReferencePanel, EphysDataset.prepareBadChannels.

if obj.refuseWhileRunning("Suggest"); return; end
d = obj.currentDataset();
if isempty(d)
    uialert(obj.Fig, "Scan a project first.", "Bad channels");
    return
end
obj.applyArtifactConfigToProject();   % the bounds as they stand on the tab

obj.ArtBadSuggestButton.Enable = "off";
cleanup = onCleanup(@() obj.refreshReferencePanel());
dlg = uiprogressdlg(obj.Fig, "Title", "Bad channels", ...
    "Message", "Measuring each channel's noise floor...", "Value", 0, "Cancelable", "off");
try
    [bad, info] = d.suggestReferenceExclude(Excluded=d.ExcludeChannels, ...
        ProgressFcn=@(i, n, name) progress(dlg, i, n, name));
catch ME
    if isvalid(dlg); close(dlg); end
    uialert(obj.Fig, ME.message, "Bad channels");
    return
end
if isvalid(dlg); close(dlg); end

d.BadChannels = bad;
d.BadChannelsSource = "suggested";
obj.saveManifests(d);

names = info.channelNames;
for k = 1:numel(info.ratio)
    if ismember(k, info.excluded)
        obj.log("[bad channels] %s ch %d (%s): excluded on the Probe tab", d.Name, k, names(k));
    else
        mark = "";
        if ismember(k, bad); mark = "  <- bad"; end
        obj.log("[bad channels] %s ch %d (%s): %.2f uV, %.2fx median%s", ...
            d.Name, k, names(k), info.sigma(k), info.ratio(k), mark);
    end
end
obj.setStatus(sprintf("%s: %s.", d.Name, info.summary), ...
    "Edit the Bad field to change it; tick Leave out bad channels to leave them out of every step.");
end


function progress(dlg, i, n, name)
if isvalid(dlg)
    dlg.Value = min(1, (i - 1) / max(n, 1));
    dlg.Message = sprintf("Measuring the noise floor: %s (%d of %d)", name, i, n);
end
end
