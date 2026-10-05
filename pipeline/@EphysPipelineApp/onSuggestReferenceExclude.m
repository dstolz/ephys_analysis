function onSuggestReferenceExclude(obj)
%onSuggestReferenceExclude  Suggest the active dataset's channels to leave out
%   of the common reference (EphysDataset.suggestReferenceExclude: a noise
%   floor outside the Good noise band, relative to the median across channels,
%   as in Ludwig et al. 2009). The suggestion replaces the dataset's list,
%   marked "suggested", and is saved in its manifest; edit the Left out field
%   to change it. Each channel's ratio goes to the log.
%
%   See also onReferenceExcludeEdited, refreshReferencePanel.

if obj.refuseWhileRunning("Suggest"); return; end
d = obj.currentDataset();
if isempty(d)
    uialert(obj.Fig, "Scan a project first.", "Common reference");
    return
end
obj.applyArtifactConfigToProject();   % the bounds as they stand on the tab

obj.ArtRefSuggestButton.Enable = "off";
cleanup = onCleanup(@() obj.refreshReferencePanel());
dlg = uiprogressdlg(obj.Fig, "Title", "Common reference", ...
    "Message", "Measuring each channel's noise floor...", "Value", 0, "Cancelable", "off");
try
    [bad, info] = d.suggestReferenceExclude(ProgressFcn=@(i, n, name) progress(dlg, i, n, name));
catch ME
    if isvalid(dlg); close(dlg); end
    uialert(obj.Fig, ME.message, "Common reference");
    return
end
if isvalid(dlg); close(dlg); end

d.ReferenceExclude = bad;
d.ReferenceExcludeSource = "suggested";
obj.saveManifests(d);

names = info.channelNames;
for k = 1:numel(info.ratio)
    if ismember(k, info.excluded)
        obj.log("[reference] %s ch %d (%s): excluded on the Probe tab", d.Name, k, names(k));
    else
        mark = "";
        if ismember(k, bad); mark = "  <- left out"; end
        obj.log("[reference] %s ch %d (%s): %.2f uV, %.2fx median%s", ...
            d.Name, k, names(k), info.sigma(k), info.ratio(k), mark);
    end
end
obj.setStatus(sprintf("%s: %s.", d.Name, info.summary), ...
    "Edit the Left out field to change it; press Detect / Preview to see the result.");
end


function progress(dlg, i, n, name)
if isvalid(dlg)
    dlg.Value = min(1, (i - 1) / max(n, 1));
    dlg.Message = sprintf("Measuring the noise floor: %s (%d of %d)", name, i, n);
end
end
