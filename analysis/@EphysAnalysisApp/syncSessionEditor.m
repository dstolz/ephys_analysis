function syncSessionEditor(obj)
%syncSessionEditor  Show and list the Sessions tab's editor rows for the selected session plot.
%   The base plot list holds the plots whose kind merges across sessions
%   (EphysAnalysisConfig.SessionKinds), the layout list "(base plot's)"
%   and the base plot's kind's layouts; each keeps a value it lacks. The
%   kind label names the base plot's kind; the note says what is wrong
%   with the base plot (missing, a kind that cannot be merged).
%
%   Rows shown (the session plot's base plot decides; spikes: units or
%   detected; signals: LFP / MUA / SPIKE / AUX):
%     trial groups               the base plot's selection has a Group by
%     keys and Pick...           Datasets "These datasets"
%     show sessions faintly,     a color per subject or one mean (with a
%       error band                 color per session there is no mean)
%     units (match)              spike bases that are not heatmap or unit
%                                waveforms (those always pool; signals
%                                match by recording channel)
%     mapping file, Browse,      match "mapping" (with the units row)
%       Edit...
%     min. sessions              always (it also counts sessions per
%                                signal channel)
%     the "signals" data box     signal bases
%   With no session plot selected only the note shows. Remove, Duplicate,
%   Up and Down follow the selection; To workspace and Save .mat need a
%   scan. The "Sessions: N ticked" line over the preview says how many
%   datasets the session plot covers (its subjects and dates).
%   layoutSessionEditor then packs the rows.
E = obj.SessionEditor;
S = obj.SessionSections;
cfg = obj.Config;
k = obj.SelectedSessionPlot;
n = numel(cfg.SessionPlots);
has = k >= 1 && k <= n;
note = "";
if has
    sp = cfg.SessionPlots(k);
    ids = string.empty(1, 0);
    if ~isempty(cfg.Plots)
        ids = [cfg.Plots(ismember([cfg.Plots.kind], EphysAnalysisConfig.SessionKinds)).id];
    end
    offerItems(E.plot, ids, sp.plot);
    b = cfg.plotIndex(sp.plot);
    kind = "";
    source = "";
    grouped = false;
    layouts = string.empty(1, 0);
    if b == 0
        note = "The base plot """ + sp.plot + """ is not in the config: pick another.";
        E.kind.Text = "(no base plot)";
    else
        p = cfg.Plots(b);
        kind = p.kind;
        source = p.source;
        K = EphysAnalysisConfig.plotKinds();
        E.kind.Text = K.Label(K.Kind == kind) + " (" + source + ")";
        ch = plotEditorChoices(kind, source);
        layouts = reshape(string(ch.Layouts), 1, []);
        if ~ismember(kind, EphysAnalysisConfig.SessionKinds)
            note = "A " + K.Label(K.Kind == kind) + " plot cannot be merged across sessions: pick another base plot.";
        end
        try
            spec = cfg.plotFor(b);   % its selection, the Alignment tab's when it uses the default
            grouped = isstruct(spec.selection) && ~isempty(spec.selection.groupBy);
        catch
        end
    end
    v = sp.layout;
    if v ~= "" && ~ismember(v, layouts); layouts(end+1) = v; end
    if v == ""; v = "base"; end
    set(E.layout, "Items", ["(base plot's)" layouts], "ItemsData", ["base" layouts], "Value", v);
    isSpike = ismember(source, EphysAnalysisConfig.SpikeSources);
    matches = isSpike && ~ismember(kind, ["heatmap" "waveforms"]);
    summary = sp.series ~= "session";
    show = struct('kind', true, 'enabled', true, 'note', note ~= "", 'id', true, 'title', true, 'plot', true, ...
        'layout', b > 0, 'trialGroups', grouped, 'datasets', true, 'datasetKeys', sp.datasets == "list", ...
        'facet', true, 'series', true, 'colorOrder', true, 'showMembers', summary, 'error', summary, ...
        'match', matches, 'mappingFile', matches && sp.match == "mapping", 'minSessions', true, ...
        'dataResults', true, 'toWorkspace', true);
    E.dataSignals.Visible = matlab.lang.OnOffSwitchState(ismember(source, EphysAnalysisConfig.SignalSources));
else
    E.kind.Text = "";
    note = "Add a session plot: pick its base plot under the list and press Add.";
    show = struct('kind', false, 'enabled', false, 'note', true, 'id', false, 'title', false, 'plot', false, ...
        'layout', false, 'trialGroups', false);
end
E.note.Text = note;
for f = string(fieldnames(show)).'
    S = formShow(S, f, show.(f));
end
for i = 2:numel(S)
    S(i).Visible = has;
end
obj.SessionSections = S;
set([obj.RemoveSessionButton obj.DuplicateSessionButton], "Enable", matlab.lang.OnOffSwitchState(has));
obj.UpSessionButton.Enable = matlab.lang.OnOffSwitchState(has && k > 1);
obj.DownSessionButton.Enable = matlab.lang.OnOffSwitchState(has && k < n);
set([E.toWorkspace E.saveMat], "Enable", matlab.lang.OnOffSwitchState(has && ~isempty(obj.Runner)));
obj.SessionEditorPanel.Title = "Session plot";
if has; obj.SessionEditorPanel.Title = "Session plot: " + cfg.SessionPlots(k).id; end
obj.SessionCountLabel.Text = countText(obj, cfg, k, has);
obj.layoutSessionEditor();
end


function t = countText(obj, cfg, k, has)
%countText  "Sessions: N ticked (subjects; first to last date)": what the session plot draws.
if isempty(obj.Runner)
    t = "Sessions: scan the datasets first (Data tab).";
    return
end
if has && cfg.SessionPlots(k).datasets == "list"
    keys = cfg.SessionPlots(k).datasetKeys;
    idx = arrayfun(@(key) obj.Runner.index(key), reshape(keys, 1, []));
    idx = idx(idx > 0);
    t = sprintf("Sessions: %d listed", numel(keys));
    if numel(idx) < numel(keys); t = t + sprintf(", %d found", numel(idx)); end
else
    idx = obj.tickedDatasetIndices();
    t = sprintf("Sessions: %d ticked", numel(idx));
end
if isempty(idx); return; end
try
    T = obj.Runner.sessionTable(idx);
    subj = unique(T.subject(T.subject ~= ""));
    if isscalar(subj)
        what = subj;
    else
        what = sprintf("%d subjects", numel(subj));
    end
    d = T.date(~isnat(T.date));
    if ~isempty(d)
        span = string(min(d), "yyyy-MM-dd");
        if max(d) > min(d); span = span + " to " + string(max(d), "yyyy-MM-dd"); end
        what = what + "; " + span;
    end
    t = t + " (" + what + ")";
catch
end
end
