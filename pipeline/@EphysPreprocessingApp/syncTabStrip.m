function syncTabStrip(obj)
%syncTabStrip  Colour each tab button by its status and underline the selected tab.
%   States: off (step disabled), ok (ready), warn (needs attention: config
%   warnings, selected datasets without a probe, trial pairings not yet
%   approved), error (config errors), busy (pipeline running) and neutral
%   (utility tabs, or nothing to judge yet). Config issues come from
%   EphysPipelineConfig.validate without path checks, attributed to the tab
%   that edits the offending field. The button tooltip says why.
if isempty(obj.TabButtons) || ~all(isvalid(obj.TabButtons)); return; end

cfg = obj.Config;
try
    issues = cfg.validate(CheckPaths=false);
catch
    issues = table(strings(0, 1), strings(0, 1), strings(0, 1), strings(0, 1), ...
        'VariableNames', {'Step', 'Field', 'Severity', 'Message'});
end
% Behavior issues belong to the Project tab (search) or the Trials tab (pairing).
isPairing = issues.Step == "behavior" & issues.Field == "TrialLine";
issues.Step(isPairing) = "trials";
issues.Step(issues.Step == "behavior") = "project";
% The Acquisition section (reader options) is edited on the Project tab.
issues.Step(issues.Step == "acquisition") = "project";
% A blank output root is a normal choice (outputs next to each recording), not a problem.
issues(issues.Step == "project" & issues.Field == "OutputRoot", :) = [];

P = obj.Project;
hasData = ~isempty(P) && P.NumDatasets > 0;
sel = [];
if hasData; sel = obj.selectedDatasetIndices(); end

tabs = obj.TabList;
for k = 1:numel(tabs)
    switch tabs(k)
        case obj.TabCopy
            state = "neutral"; tip = "Find sessions on the source and copy them to local session folders.";
            if ~isempty(obj.CopyJob)
                state = "busy";
                tip = "Copying sessions in the background; the Copy tab shows how far it has got.";
            end
        case obj.TabProject
            [state, tip] = issueState(issues, "project");
            if state == "ok"
                if ~hasData
                    state = "warn"; tip = "No datasets scanned yet.";
                else
                    tip = sprintf("%d dataset(s), %d selected.", P.NumDatasets, numel(sel));
                end
            end
        case obj.TabTrials
            [state, tip] = issueState(issues, "trials");
            if state == "ok"
                [state, tip] = trialsState(P, sel);
            end
        case obj.TabProbe
            [state, tip] = issueState(issues, "probe");
            if state == "ok"
                [state, tip] = probeState(P, sel, cfg.Probe.DefaultProbeFile);
            end
        case obj.TabArtifacts
            [state, tip] = stepState(issues, "artifacts", cfg.Artifacts.Enabled);
        case obj.TabSorting
            [state, tip] = stepState(issues, "sorting", cfg.Sorting.Enabled);
        case obj.TabSignals
            [state, tip] = stepState(issues, "signals", cfg.Signals.Enabled);
        case obj.TabSpikes
            [state, tip] = stepState(issues, "spikes", cfg.Spikes.Enabled);
        case obj.TabExport
            [state, tip] = stepState(issues, "export", cfg.Export.Enabled);
        case obj.TabRun
            if obj.RunActive
                state = "busy"; tip = "Pipeline running.";
            else
                state = "neutral"; tip = "Validate, plan and run the enabled steps.";
            end
        case obj.TabFlow
            state = "neutral"; tip = "Diagram of the working config.";
        case obj.TabSynthetic
            state = "neutral"; tip = "Design, preview and write a synthetic dataset, its events from the built-in task or the active dataset's Epsych2 session.";
        case obj.TabCleanup
            state = "neutral"; tip = "Remove local raw recordings and sorter copies to free disk space; outputs are kept.";
        otherwise
            state = "neutral"; tip = "";
    end
    [bg, fg] = stateColors(state);
    b = obj.TabButtons(k);
    b.BackgroundColor = bg;
    b.FontColor = fg;
    b.Tooltip = tip;
    selected = tabs(k) == obj.Tabs.SelectedTab;
    b.FontWeight = ternary(selected, "bold", "normal");
    obj.TabMarks(k).Visible = selected;
end
end


function [state, tip] = issueState(issues, step)
%issueState  error / warn from the config issues of STEP, else ok.
rows = issues(issues.Step == step, :);
err = rows(rows.Severity == "error", :);
if height(err) > 0
    state = "error"; tip = strjoin(err.Message, newline);
elseif height(rows) > 0
    state = "warn"; tip = strjoin(rows.Message, newline);
else
    state = "ok"; tip = "";
end
end


function [state, tip] = stepState(issues, step, enabled)
if ~enabled
    state = "off"; tip = "Step disabled.";
    return
end
[state, tip] = issueState(issues, step);
if state == "ok"; tip = "Step enabled."; end
end


function [state, tip] = probeState(P, sel, defaultProbe)
%probeState  The selected datasets' probes: each its own, else the default
%   (EphysPipeline.probeFor), and whether the file is there.
if isempty(sel)
    state = "neutral"; tip = "Scan a project to check probe assignments.";
    return
end
own = arrayfun(@(i) P.Datasets(i).ProbeFile, sel);
nDefault = nnz(own == "");
probe = own;
probe(own == "") = defaultProbe;
nNone = nnz(probe == "");
nGone = nnz(probe ~= "" & ~arrayfun(@isfile, probe));
if nNone + nGone > 0
    state = "warn";
    tip = strings(1, 0);
    if nNone > 0; tip(end+1) = sprintf("%d of %d selected dataset(s) have no probe.", nNone, numel(sel)); end
    if nGone > 0; tip(end+1) = sprintf("%d selected dataset(s) have a probe file that is not there.", nGone); end
    tip = strjoin(tip, " ");
elseif nDefault > 0
    state = "ok"; tip = sprintf("%d selected dataset(s) will use the default probe.", nDefault);
else
    state = "ok"; tip = "Every selected dataset has a probe.";
end
end


function [state, tip] = trialsState(P, sel)
nBeh = 0; nApproved = 0;
for i = sel
    d = P.Datasets(i);
    if d.BehaviorFile == "" || ~isfile(d.BehaviorFile); continue; end
    nBeh = nBeh + 1;
    if ~isempty(d.TrialPairing) && d.TrialPairing.status == "approved"
        nApproved = nApproved + 1;
    end
end
if nBeh == 0
    state = "neutral"; tip = "No selected dataset has an Epsych2 session.";
elseif nApproved < nBeh
    state = "warn"; tip = sprintf("%d of %d trial pairing(s) approved.", nApproved, nBeh);
else
    state = "ok"; tip = sprintf("All %d trial pairing(s) approved.", nBeh);
end
end


function [bg, fg] = stateColors(state)
fg = [0.12 0.12 0.12];
switch state
    case "ok";    bg = [0.78 0.91 0.78];
    case "warn";  bg = [1.00 0.86 0.58];
    case "error"; bg = [0.96 0.70 0.68];
    case "busy";  bg = [0.72 0.84 0.98];
    case "off";   bg = [0.86 0.86 0.86]; fg = [0.45 0.45 0.45];
    otherwise;    bg = [0.97 0.97 0.97];
end
end


function v = ternary(tf, a, b)
if tf; v = a; else; v = b; end
end
