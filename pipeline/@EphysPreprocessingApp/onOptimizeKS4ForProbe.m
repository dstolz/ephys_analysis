function onOptimizeKS4ForProbe(obj, ifMissing)
%onOptimizeKS4ForProbe  Load the Kilosort4 parameters saved for a probe.
%   Uses the probe of the active dataset, else the config's default probe
%   (the one a run assigns), and loads its parameter file (<probe>.ks4.json
%   next to the probe map, EphysPipelineConfig.ks4ForProbe) into the Sorting
%   tab. The log lists every loaded value; a dialog summarizes the changes.
%
%   When the probe has no parameter file, an alert offers to generate one,
%   with the values of EphysPipelineConfig.KS4ProbeParams taken either from
%   the current parameters (nothing else changes) or from the probe layout
%   (EphysPipelineConfig.ks4ProbeDefaults; the new file is then loaded).
%   IFMISSING answers that offer: "ask" (default, the dialog), or without a
%   dialog "generate" (current parameters), "derive" (probe layout) or
%   "cancel".
%
%   See also onResetKS4Params, EphysPipelineConfig.ks4ForProbe,
%   EphysPipelineConfig.writeKS4Params, EphysPipelineConfig.ks4ProbeDefaults.

arguments
    obj (1,1) EphysPreprocessingApp
    ifMissing (1,1) string {mustBeMember(ifMissing, ["ask" "generate" "derive" "cancel"])} = "ask"
end

dlgTitle = "Optimize for probe";
[S, errMsg] = obj.gatherSortingSection();
if errMsg ~= ""
    uialert(obj.Fig, errMsg + newline + "Fix this field first.", dlgTitle);
    return
end

d = obj.currentDataset();
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
    uialert(obj.Fig, "Choose a dataset with an assigned probe in the Dataset box, " + ...
        "or set a default probe on the Probe tab.", dlgTitle);
    return
end
if ~isfile(pf)
    uialert(obj.Fig, "Probe file not found:" + newline + pf, dlgTitle);
    return
end
[~, name, ext] = fileparts(pf);
probeName = name + ext;
paramsFile = EphysPipelineConfig.ks4ParamsFile(pf);
[~, name, ext] = fileparts(paramsFile);
paramsName = name + ext;
action = "loaded from " + paramsName;
layoutNotes = strings(0, 1);

if ~isfile(paramsFile)
    names = EphysPipelineConfig.KS4ProbeParams;
    current = paramText(S.KS4, names);
    deriveErr = "";
    try
        [derived, layout] = EphysPipelineConfig.ks4ProbeDefaults(pf);
    catch ME
        deriveErr = string(ME.message);
    end
    if ifMissing == "ask"
        options = "From current parameters";
        msg = probeName + " (" + source + ") has no Kilosort4 parameter file." + newline + newline + ...
            "Generate " + paramsName + " next to the probe map from" + newline + ...
            "- the current parameters: " + strjoin(current, ", ") + newline;
        if deriveErr == ""
            options(end+1) = "From probe layout";
            msg = msg + "- defaults derived from the probe layout, also loaded into the Sorting tab: " + ...
                strjoin(paramText(derived, names), ", ") + newline;
        else
            msg = msg + "(Defaults cannot be derived from the probe layout: " + deriveErr + ")" + newline;
        end
        options(end+1) = "Cancel";
        msg = msg + newline + "Optimize for probe loads that file from then on; edit it to change the values.";
        choice = string(uiconfirm(obj.Fig, msg, dlgTitle, "Icon", "warning", "Options", options, ...
            "DefaultOption", 1, "CancelOption", numel(options)));
        ifMissing = "cancel";
        if choice == "From current parameters"
            ifMissing = "generate";
        elseif choice == "From probe layout"
            ifMissing = "derive";
        end
    end

    switch ifMissing
        case "generate"
            values = struct();
            for p = names
                values.(p) = S.KS4.(p);
            end
            desc = sprintf("Current parameters of config ""%s"", saved from the Sorting tab on %s.", ...
                obj.Config.Name, string(datetime('today', 'Format', 'yyyy-MM-dd')));
            reasons = struct();
            from = "the current parameters: " + strjoin(current, ", ");
        case "derive"
            if deriveErr ~= ""
                uialert(obj.Fig, "Cannot derive defaults from the probe layout:" + newline + deriveErr, dlgTitle);
                return
            end
            values = derived;
            desc = "Good defaults derived from the probe layout by EphysPipelineConfig.ks4ProbeDefaults. " + ...
                layout.Summary + ".";
            reasons = layout.Reasons;
            from = "the probe layout: " + layout.Summary;
        otherwise
            obj.setStatus("No Kilosort4 parameter file for " + probeName + "; nothing loaded.");
            return
    end
    try
        EphysPipelineConfig.writeKS4Params(pf, values, Description=desc, Reasons=reasons);
    catch ME
        uialert(obj.Fig, string(ME.message), dlgTitle);
        return
    end
    obj.log("%s", "Generated " + paramsFile + " for " + probeName + " from " + from + ".");
    if obj.selectedProbeFile() == string(pf)
        obj.onProbeSelected();   % the Probe tab's info names the new file
    end
    if ifMissing == "generate"
        obj.setStatus("Generated " + paramsName + " from the current parameters; Optimize for probe loads it from now on.");
        return
    end
    action = "derived from the probe layout, saved to " + paramsName + " and loaded";
    layoutNotes = layout.Notes;
end

try
    [S, report] = EphysPipelineConfig.ks4ForProbe(S, pf);
catch ME
    uialert(obj.Fig, string(ME.message), dlgTitle);
    return
end
obj.applySortingSection(S);
obj.onConfigChanged();

C = report.Changes;
notes = [layoutNotes; report.Notes];
header = "Kilosort4 parameters for " + probeName + " (" + source + ") " + action;
obj.log("%s", "Kilosort4 parameters for " + probeName + " (" + source + ") loaded from " + report.File + ".");
if report.Description ~= ""
    obj.log("%s", "  " + report.Description);
end
for i = 1:height(C)
    if C.Changed(i)
        obj.log("%s", "  " + C.Parameter(i) + ": " + shown(C.Old(i)) + " -> " + shown(C.New(i)) + why(C.Reason(i)));
    else
        obj.log("%s", "  " + C.Parameter(i) + " = " + shown(C.New(i)) + why(C.Reason(i)));
    end
end
for i = 1:numel(notes)
    obj.log("%s", "  Note: " + notes(i));
end

msg = header + "." + newline;
if report.Description ~= ""
    msg = msg + report.Description + newline;
end
msg = msg + newline;
if any(C.Changed)
    msg = msg + "Changed:" + newline;
    for i = find(C.Changed).'
        msg = msg + "- " + C.Parameter(i) + ": " + shown(C.Old(i)) + " -> " + shown(C.New(i)) + ...
            why(C.Reason(i)) + newline;
    end
    if ~all(C.Changed)
        same = ~C.Changed;
        msg = msg + newline + "Unchanged: " + strjoin(C.Parameter(same) + " " + shown(C.New(same)), ", ") + "." + newline;
    end
else
    msg = msg + "The current parameters already match the file." + newline;
end
if ~isempty(notes)
    msg = msg + newline + strjoin(notes, newline) + newline;
end
msg = msg + newline + "To change these values, edit " + paramsName + " next to the probe map.";

icon = "success";
if ~isempty(notes); icon = "warning"; end
obj.setStatus(sprintf("Kilosort4 parameters %s: %d of %d changed.", action, nnz(C.Changed), height(C)));
uialert(obj.Fig, msg, dlgTitle, "Icon", icon);
end


function s = shown(v)
%shown  Edit-field text for display; blank is Kilosort's own default.
s = string(v);
s(s == "") = "auto";
end


function s = why(reason)
%why  " (reason)", or "" when the file gives none.
s = "";
if reason ~= ""
    s = " (" + reason + ")";
end
end


function t = paramText(ks4, names)
%paramText  "name value" for each parameter, blank shown as auto.
spec = EphysPipelineConfig.kilosortParamSpec();
t = strings(1, numel(names));
for i = 1:numel(names)
    kind = spec(strcmp({spec.name}, names(i))).kind;
    t(i) = names(i) + " " + shown(EphysPipelineConfig.ks4ParamText(kind, ks4.(names(i))));
end
end
