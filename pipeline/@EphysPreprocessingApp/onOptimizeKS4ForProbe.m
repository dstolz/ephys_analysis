function onOptimizeKS4ForProbe(obj)
%onOptimizeKS4ForProbe  Tune the probe-dependent Kilosort4 parameters to a probe map.
%   Uses the probe of the dataset last clicked in the Project table, else the
%   config's default probe (the one a run assigns), dropping that dataset's
%   excluded channels, and applies EphysPipelineConfig.ks4ForProbe to the
%   Sorting tab. Every tuned value and its reason goes to the Kilosort4 log;
%   a dialog summarizes the changes.
%
%   See also onResetKS4Params, EphysPipelineConfig.ks4ForProbe.

dlgTitle = "Optimize for probe";
[S, errMsg] = obj.gatherSortingSection();
if errMsg ~= ""
    uialert(obj.Fig, errMsg + newline + "Fix this field first.", dlgTitle);
    return
end

d = obj.currentDataset();
exclude = double.empty(1, 0);
if ~isempty(d)
    exclude = d.ExcludeChannels;
end
if ~isempty(d) && d.ProbeFile ~= ""
    pf = d.ProbeFile;
    source = "probe of " + d.Name;
elseif obj.Config.Probe.DefaultProbeFile ~= ""
    pf = obj.Config.Probe.DefaultProbeFile;
    source = "default probe";
    if ~isempty(d)
        source = source + ", as " + d.Name + " has none assigned";
    end
else
    uialert(obj.Fig, "Click a dataset with an assigned probe in the Project table, " + ...
        "or set a default probe on the Probe tab.", dlgTitle);
    return
end

try
    [S, report] = EphysPipelineConfig.ks4ForProbe(S, pf, ExcludeChannels=exclude);
catch ME
    uialert(obj.Fig, string(ME.message), dlgTitle);
    return
end
obj.applySortingSection(S);
obj.onConfigChanged();

[~, name, ext] = fileparts(pf);
G = report.Geometry;
C = report.Changes;
summary = sprintf("%d sites", G.NumSites);
if G.NumExcluded > 0
    summary = summary + sprintf(" (%d excluded)", G.NumExcluded);
end
summary = summary + sprintf(" on %d shank(s)", G.NumShanks);
spacing = strings(1, 0);
if ~isnan(G.RowPitchUm);     spacing(end+1) = "rows " + G.RowPitchUm + " um apart"; end
if ~isnan(G.LateralPitchUm); spacing(end+1) = "lateral spacing " + G.LateralPitchUm + " um"; end
if ~isnan(G.NearestSiteUm);  spacing(end+1) = "nearest contact " + G.NearestSiteUm + " um"; end
if ~isempty(spacing)
    summary = summary + ": " + strjoin(spacing, ", ");
end
header = "Kilosort4 parameters tuned to " + name + ext + " (" + source + ")";

obj.log("%s", header + ". " + summary + ".");
for i = 1:height(C)
    if C.Changed(i)
        obj.log("%s", "  " + C.Parameter(i) + ": " + shown(C.Old(i)) + " -> " + shown(C.New(i)) + " (" + C.Reason(i) + ")");
    else
        obj.log("%s", "  " + C.Parameter(i) + " = " + shown(C.New(i)) + " (" + C.Reason(i) + ")");
    end
end
for i = 1:numel(report.Notes)
    obj.log("%s", "  Note: " + report.Notes(i));
end

msg = header + "." + newline + summary + "." + newline + newline;
if any(C.Changed)
    msg = msg + "Changed:" + newline;
    for i = find(C.Changed).'
        msg = msg + "- " + C.Parameter(i) + ": " + shown(C.Old(i)) + " -> " + shown(C.New(i)) + ...
            " (" + C.Reason(i) + ")" + newline;
    end
    if ~all(C.Changed)
        same = ~C.Changed;
        msg = msg + newline + "Unchanged: " + strjoin(C.Parameter(same) + " " + shown(C.New(same)), ", ") + "." + newline;
    end
else
    msg = msg + "Every probe-dependent parameter already suits this probe." + newline;
end
if ~isempty(report.Notes)
    msg = msg + newline + strjoin(report.Notes, newline) + newline;
end
msg = msg + newline + "The Kilosort4 log lists the reason for every value.";

icon = "success";
if ~isempty(report.Notes); icon = "warning"; end
obj.setStatus(sprintf("Kilosort4 parameters tuned to %s%s: %d changed.", name, ext, nnz(C.Changed)));
uialert(obj.Fig, msg, dlgTitle, "Icon", icon);
end


function s = shown(v)
%shown  Edit-field text for display; blank is Kilosort's own default.
s = string(v);
s(s == "") = "auto";
end
