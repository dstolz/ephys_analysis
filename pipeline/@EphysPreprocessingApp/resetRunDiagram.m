function resetRunDiagram(obj, steps, dryRun)
%resetRunDiagram  Start the Run tab's diagram afresh.
%   app.resetRunDiagram() previews the working config: the steps it would
%   run are drawn waiting ("will run") and the others as off. It follows the
%   Steps checklist until a run starts (syncStepEnableStates).
%   app.resetRunDiagram(STEPS, DRYRUN) starts a run of STEPS (names from
%   EphysPipelineConfig.StepNames; every other step is "not in this run"),
%   which updateRunDiagram follows event by event and finishRunDiagram
%   closes. The finished run stays drawn until the next one starts.
%
%   The model is obj.RunDiagram: the phase (idle | running | done |
%   cancelled | error), the config name, the number of datasets, when the
%   run started and ended, the error message, the results so far and one
%   entry per step: key, title, what it does under this config, whether it
%   is in the run, its state (off | queued | running | done | cancelled |
%   notrun | failed), its percentage and the dataset (index of count) and
%   message of its last event. refreshRunDiagram draws it.

cfg = obj.Config;
running = nargin >= 2;
if ~running
    steps = cfg.enabledSteps();
end
if nargin < 3; dryRun = false; end

names = EphysPipelineConfig.StepNames;
titles = ["Probe check" "Behavior" "Artifacts" "Sorting" "Signals" "Spikes" "Export"];
S = struct('key', num2cell(names), 'title', num2cell(titles), 'what', num2cell(stepWhat(cfg)), ...
    'inRun', num2cell(ismember(names, string(steps))), 'state', "queued", 'pct', 0, ...
    'index', 0, 'count', 0, 'dataset', "", 'message', "");
for k = find(~[S.inRun])
    S(k).state = "off";
end

nDatasets = 0;
started = NaT;
if running
    started = datetime('now');
    if ~isempty(obj.Pipe); nDatasets = numel(obj.Pipe.DatasetIdx); end
end
phase = "idle";
if running; phase = "running"; end
obj.RunDiagram = struct('phase', phase, 'dryRun', logical(dryRun), 'name', cfg.Name, ...
    'nDatasets', nDatasets, 'started', started, 'finished', NaT, 'note', "", ...
    'results', EphysPipeline.emptyResults(), 'steps', S);
obj.refreshRunDiagram();
end


function w = stepWhat(cfg)
%stepWhat  What each step does under CFG, in a few words (StepNames order).
w = strings(1, 7);

w(1) = "assigned probes vs channel counts";
if cfg.Probe.DefaultProbeFile ~= ""
    [~, f, x] = fileparts(cfg.Probe.DefaultProbeFile);
    w(1) = w(1) + "; default " + f + x;
end

B = cfg.Behavior;
w(2) = "match Epsych2 sessions";
if B.PairTrials; w(2) = w(2) + ", pair trials"; end
if B.WriteFile; w(2) = w(2) + ", write the behavior file"; end

A = cfg.Artifacts;
switch A.Method
    case "rms";        m = "running RMS";
    case "mad";        m = "robust z-score";
    case "microvolts"; m = "absolute amplitude";
    otherwise;         m = "common-mode mean";
end
if A.Enabled
    w(3) = "automatic detection: " + m;
else
    w(3) = "manual periods only (detection off)";
end

S = cfg.Sorting;
if S.Execution == "blocking"
    w(4) = "SpikeInterface + Kilosort4, waits for the sort";
else
    w(4) = "SpikeInterface + Kilosort4, launched in the background";
end
if S.DryRun; w(4) = w(4) + " (run files only)"; end

G = cfg.Signals;
types = ["LFP" "MUA" "SPIKE" "AUX"];
types = types([G.LFP G.MUA G.SPIKE G.AUX]);
if isempty(types)
    w(5) = "no signal ticked";
else
    w(5) = join(types, " + ") + " .mat";
end

switch cfg.Spikes.Source
    case "detect"; w(6) = "threshold detection .mat";
    case "sorted"; w(6) = "sorted units .mat";
    otherwise;     w(6) = "threshold detection + sorted units .mat";
end

fmts = replace(cfg.Export.Formats, ["chronux" "fieldtrip"], ["Chronux" "FieldTrip"]);
if isempty(fmts)
    w(7) = "no format ticked";
else
    w(7) = join(fmts, " + ") + " files";
end
end
