function [C, fx] = figureTestCases(root)
%figureTestCases  Figures computed on a small synthetic dataset, one per panel type and per layout that matters (test data).
%   [C, FX] = figureTestCases(ROOT) runs makeAnalysisFixture(ROOT,
%   Scenarios="clean", NumTrials=12), makes a config of figures on it
%   (Defaults: Stim onset, [-0.2 0.8] s, trial groups by TrialType: two
%   groups, not ordered) and computes each figure for its first
%   observation (EphysAnalysisRunner.computeFigure). C is a struct array
%   (id, F, spec), one entry per figure:
%     every panel type, its template (addFigure(<type>)): raster, psth,
%       continuous, heatmap, waveforms, probemap, corrmap, rate, tuning,
%       spectrum, spectrogram, coherence (the spectral ones need Chronux
%       on the path; without it their panels are skipped, drawn as notes),
%       eventTrace (the Stim line's bars, epochs overlaid)
%     eventTrace_rows   the Stim and Platform lines as logic levels, a
%                       sub-row per epoch, colored by trial group
%     spans             rasterPsth with the Stim line drawn as a span
%                       (onset to offset) on the raster and the PSTH
%     rasterPsth        a unit's raster flush over its PSTH
%     psth_stack        the PSTH's groups stacked in rows
%     psth_auroc        the auROC baseline (only with the Statistics and
%                       Machine Learning Toolbox)
%     waveforms_probe   every unit's waveform on the probe
%     continuous_stack  three LFP channels stacked
%     rate_box          firing rates as boxes
%     heatmap_trials    a heat map of one unit's trials
%     notes_overlays    rasterPsth with a note on each panel, a line and a
%                       region overlay on the PSTH
%     ordered           a firing-rate figure grouped by Depth (more than two
%                       numeric values: ordered groups)
%     one_group         a PSTH of every trial as one group
%     sessions_combine  rasterPsth as a session figure, the dataset read as
%                       two sessions (sessionTable, figureSessionCompute;
%                       its first site): a color per session, the trial
%                       groups combined (line styles)
%     sessions_members  the same, all sessions averaged with each session
%                       drawn faintly under the mean (member lines)
%     sessions_heatmap  the heat map of units across the two sessions
%                       (session dividers)
%     first_spike       rasterPsth with the raster's first-spike marks and
%                       the PSTH's latency box plot (options.firstSpike,
%                       options.latencyBox)
%     sessions_first_spike  first_spike as a session figure (a color per
%                       session): the marks and boxes on the merged rows
%   FX: the fixture (makeAnalysisFixture's struct) with cfg (the config)
%   and runner (its EphysAnalysisRunner) and src (the dataset's source).
%   Used by test_PlotAesthetics and test_PlotDesign.
%
%   See also makeAnalysisFixture, EphysAnalysisConfig.figureTemplates, renderFigure.

arguments
    root (1,1) string
end

fx = makeAnalysisFixture(root, Scenarios="clean", NumTrials=12);
cfg = EphysAnalysisConfig();
cfg.Source.Root = fx.proj;
cfg.Defaults.EventRef.line = "Stim";
cfg.Defaults.Window = struct('mode', "fixed", 'pre', -0.2, 'post', 0.8, 'stop', []);
cfg.Defaults.Selection.groupBy = "TrialType";
types = reshape(EphysAnalysisConfig.panelTypes().Type, 1, []);
for t = types
    cfg = cfg.addFigure(t, Id=t);
end
cfg = cfg.addFigure("rasterPsth", Id="rasterPsth");
f = cfg.Figures(cfg.figureIndex("rasterPsth"));

s = f; s.id = "psth_stack";
s.panels(2).options.stack = true;
cfg = cfg.addFigure(s);
haveStats = license('test', 'Statistics_Toolbox') && exist('tiedrank', 'file') == 2;
if haveStats
    a = f; a.id = "psth_auroc";
    a.panels(2).options.baseline = struct('Mode', "auroc", 'Window', [-0.2 0]);
    cfg = cfg.addFigure(a);
end
w = cfg.Figures(cfg.figureIndex("waveforms")); w.id = "waveforms_probe";
w.panels(1).options.layout = "probe";
w.panels(1).layers(1).binding = "fixed";
cfg = cfg.addFigure(w);
c = cfg.Figures(cfg.figureIndex("continuous")); c.id = "continuous_stack";
c.panels(1).layers(1).binding = "fixed";
c.panels(1).layers(1).channels = [1 2 3];
c.panels(1).options.display = "stacked";
cfg = cfg.addFigure(c);
r = cfg.Figures(cfg.figureIndex("rate")); r.id = "rate_box";
r.panels(1).options.display = "box";
cfg = cfg.addFigure(r);
h = cfg.Figures(cfg.figureIndex("heatmap")); h.id = "heatmap_trials";
h.panels(1).options.rows = "trials";
h.panels(1).layers(1).binding = "observation";
cfg = cfg.addFigure(h);
n = f; n.id = "notes_overlays";
n.panels(2).note = EphysAnalysisConfig.normalizeSection("Note", struct('text', "n = 12", 'placement', "below"));
n.panels(1).note = EphysAnalysisConfig.normalizeSection("Note", struct('text', "raster", 'placement', "northeast"));
ovL = EphysAnalysisConfig.defaults("Overlay"); ovL.name = "Stim";
ovR = EphysAnalysisConfig.defaults("Overlay"); ovR.name = "Window"; ovR.shape = "region"; ovR.from = 0; ovR.to = 0.1;
n.panels(2).overlays = [ovL ovR];
cfg = cfg.addFigure(n);
o = cfg.Figures(cfg.figureIndex("rate")); o.id = "ordered";
o.selection = EphysAnalysisConfig.defaults("TrialSelection");
o.selection.groupBy = "Depth";
cfg = cfg.addFigure(o);
e = cfg.Figures(cfg.figureIndex("eventTrace")); e.id = "eventTrace_rows";   % two lines, a logic level per epoch's sub-row, by group
e2 = e.panels(1).layers(1); e2.event.line = "Platform";
e.panels(1).layers = [e.panels(1).layers e2];
e.panels(1).options.display = "line";
e.panels(1).options.trials = "rows";
e.panels(1).options.colorBy = "group";
cfg = cfg.addFigure(e);
sp = f; sp.id = "spans";   % Stim from onset to offset on every raster row and as a line per group on the PSTH
spL = EphysAnalysisConfig.defaultLayer("eventTrace"); spL.eventsAs = "span";
sp.panels(1).layers = [sp.panels(1).layers spL];
sp.panels(2).layers = [sp.panels(2).layers spL];
cfg = cfg.addFigure(sp);
g = cfg.Figures(cfg.figureIndex("psth")); g.id = "one_group";
g.selection = EphysAnalysisConfig.defaults("TrialSelection");
g.selection.groupBy = string.empty(1, 0);
cfg = cfg.addFigure(g);
x = f; x.id = "sessions_combine";   % a color per session, the trial groups combined (line styles)
x.sessions.enabled = true;
x.sessions.trialGroups = "combine";
cfg = cfg.addFigure(x);
x = f; x.id = "sessions_members";   % all sessions averaged, each drawn faintly under the mean
x.sessions.enabled = true;
x.sessions.series = "all";
x.sessions.showMembers = true;
cfg = cfg.addFigure(x);
x = cfg.Figures(cfg.figureIndex("heatmap")); x.id = "sessions_heatmap";   % each session's units, a divider between sessions
x.sessions.enabled = true;
cfg = cfg.addFigure(x);
x = f; x.id = "first_spike";   % a mark on each epoch's first spike, a box plot of the latencies over the PSTH
x.panels(1).options.firstSpike = struct('enabled', true, 'maxSec', 0.3);
x.panels(2).options.latencyBox = struct('enabled', true, 'maxSec', 0.3);
cfg = cfg.addFigure(x);
x.id = "sessions_first_spike";   % the same on the rows merged across the two sessions
x.sessions.enabled = true;
cfg = cfg.addFigure(x);

rn = EphysAnalysisRunner(cfg, LogFcn=[]);
src = rn.source(1);
ws = [warning('off', 'unitWaveforms:Templates') warning('off', 'unitWaveforms:NoWaveforms') ...
    warning('off', 'aurocCall:NoCutoff') warning('off', 'aurocCall:WideCutoff')];
restore = onCleanup(@() warning(ws));
ids = cfg.figureIds();
C = struct('id', cell(1, numel(ids)), 'F', [], 'spec', []);
S = sessionTable(["session_a"; "session_b"], ["session_a"; "session_b"]);   % the dataset as two sessions
for k = 1:numel(ids)
    spec = cfg.figureFor(ids(k));
    if spec.sessions.enabled   % merged across the two sessions (figureSessionCompute), its first site
        Ts = figureSessionObservations({src, src}, spec);
        res = figureSessionCompute({src, src}, S, spec, Observation=Ts(1, :));
        if height(Ts) == 0 || res(1).status ~= "done"
            error('figureTestCases:NoSessions', 'Session figure "%s" was not merged on the fixture.', ids(k));
        end
        C(k).id = ids(k);
        C(k).F = res(1).F;
        C(k).spec = spec;
        continue
    end
    T = figureObservations(src, spec);
    if height(T) == 0
        error('figureTestCases:NoObservation', 'Figure "%s" has no observation on the fixture.', ids(k));
    end
    C(k).id = ids(k);
    C(k).F = rn.computeFigure(src, spec, Observation=T(1, :));
    C(k).spec = spec;
end
fx.cfg = cfg;
fx.runner = rn;
fx.src = src;
end
