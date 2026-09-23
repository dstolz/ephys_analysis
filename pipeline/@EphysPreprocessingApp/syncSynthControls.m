function syncSynthControls(obj)
%syncSynthControls  Enable the Synthetic tab's controls for its source; fill the tables' lists.
%   The task's trials and scenario apply to the built-in task, the trial
%   duration and rebuilt lines to "Epsych2 session only", Max (s) to the
%   dataset sources. The units / LFP tables' Event lists hold the source's
%   lines (plus any the design names), their Parameter lists its numeric
%   Epsych2 parameters (synthSourceLists).
mode = string(obj.SynthSourceDropDown.Value);
onOff = @(tf) string(ternary(tf, "on", "off"));   % a uitable's Enable takes no OnOffSwitchState
obj.SynthTrialsSpinner.Enable = onOff(mode == "task");
obj.SynthScenarioDropDown.Enable = onOff(mode == "task");
for c = [obj.SynthTrialDurField, obj.SynthLinesTable, obj.SynthAddLineButton, obj.SynthRemoveLineButton]
    c.Enable = onOff(mode == "session");
end
obj.SynthMaxDurField.Enable = onOff(mode ~= "task");

[lines, params] = obj.synthSourceLists();
D = obj.gatherSynthDesign();
lines = unique([lines, D.usedLines()], 'stable');
params = unique([params, D.usedParameters()], 'stable');
evList = cellstr(lines);
if isempty(evList); evList = {''}; end
parList = [{'(none)'}, cellstr(params)];
edges = cellstr(SyntheticDesign.Edges);
tunings = cellstr(SyntheticDesign.Tunings);
obj.SynthUnitsTable.ColumnFormat = {'char', [{'(none)'}, cellstr(lines)], edges, cellstr(SyntheticDesign.Shapes), ...
    'numeric', 'numeric', 'numeric', 'numeric', 'numeric', 'numeric', 'numeric', 'numeric', parList, tunings};
obj.SynthLFPTable.ColumnFormat = {'char', cellstr(SyntheticDesign.Kinds), evList, edges, ...
    'numeric', 'numeric', 'numeric', 'numeric', 'numeric', 'logical', cellstr(SyntheticDesign.Profiles), ...
    'numeric', parList, tunings};

% the probe the recording is drawn on
S = obj.SynthSource;
nCh = obj.SynthChannelsField.Value;
txt = sprintf("Probe: synthetic, %d channels (makeSyntheticProbe; written with the dataset).", nCh);
if mode ~= "task" && ~isempty(S) && S.probeFile ~= ""
    [~, f, e] = fileparts(S.probeFile);
    p = readJsonFile(S.probeFile, ErrorOnFail=false);
    nSite = 0;
    if isstruct(p) && isfield(p, 'xc'); nSite = numel(p.xc); end
    who = "the dataset's own"; if ~S.ownProbe; who = "the config's default"; end
    if nSite >= nCh
        txt = sprintf("Probe: %s%s (%s, %d sites).", f, e, who, nSite);
    else
        txt = sprintf("Probe: synthetic, %d channels: %s%s (%s) has only %d sites.", nCh, f, e, who, nSite);
    end
end
obj.SynthProbeLabel.Text = txt;
end


function v = ternary(tf, a, b)
if tf; v = a; else; v = b; end
end
