function T = benchFigGenUI(opts)
%benchFigGenUI  Time the Figures tab's selecting, figure switching, Arrange drags and edits, each under the profiler.
%   T = benchFigGenUI(Name=Value) opens the synthetic fixture (Project="") or
%   a real project and its config, then times: Ctrl+click and Shift+click on
%   panels, a switch between two figures (and, unprofiled, to a third one
%   not drawn yet), Arrange (on, press, 20 drag steps, a release that keeps
%   the neighbors, a release that changes them, an arrow nudge, off) and a
%   title edit (to "bench x", then, unprofiled, again and with a word added
%   to the title, which keeps the label variables it names: set in place).
%   Each action prints its seconds (the call
%   alone, then to the paint after a drawnow; with the profiler on, so
%   inflated) and the top functions by self and total time. T has one row
%   per action. Nothing is saved; run it under Bench-FigGen.ps1 (hidden
%   desktop, scratch preferences).
%
%   Project  project root; "" = the fixture (default: the owner's OFC project)
%   Config   config file to open (default: the LastConfigFile preference)
%   Figure   figure id (default: the first figure with two panels)
%   Panels   two panel ids (default: the figure's panels 1 and 2)
%   Auto     Auto slider value (default: the FigureAutoRedraw preference, else 0.5)
%   Reps     repeats of the select actions and steps (default 3)
%   Log      file the report is also written to
arguments
    opts.Project (1,1) string = "S:\ANALYSIS_BACKUPS\Daniel\EPHYS\OFC\Analysis"
    opts.Config (1,1) string = ""
    opts.Figure (1,1) string = ""
    opts.Panels (1,:) string = string.empty(1, 0)
    opts.Auto (1,1) double = NaN
    opts.Reps (1,1) double = 3
    opts.Log (1,1) string = ""
end
repo = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(repo, 'analysis'), fullfile(repo, 'pipeline'), repo, genpath(fullfile(repo, 'vendor')));
fid = -1;
if opts.Log ~= ""; fid = fopen(opts.Log, 'w'); end
closeLog = onCleanup(@() closeFile(fid));
rows = struct('action', {}, 'call_s', {}, 'paint_s', {}, 'wait_s', {}, 'state', {}, 'busy_delta', {}, 'note', {});
app = [];
fixtureRoot = "";
pressed = @(k) struct('Key', k, 'Modifier', {{}}, 'Character', '');

% the owner's preferences, read with the app's own store switched off (MATLAB's preferences)
envOld = getenv(AppPrefs.EnvVar);
setenv(AppPrefs.EnvVar, '');
g = EphysFigGenApp.PrefGroup;
prefConfig = "";
prefAuto = NaN;
try
    if AppPrefs.ispref(g, 'LastConfigFile'); prefConfig = string(AppPrefs.getpref(g, 'LastConfigFile')); end
    if AppPrefs.ispref(g, 'FigureAutoRedraw'); prefAuto = double(AppPrefs.getpref(g, 'FigureAutoRedraw')); end
catch ME
    emit('could not read the preferences: %s\n', ME.message);
end
setenv(AppPrefs.EnvVar, envOld);
restorePrefs = []; %#ok<NASGU>
if envOld == ""; restorePrefs = AppPrefs.useTemporary(); end   % never write the owner's preferences

fixture = opts.Project == "";
auto = opts.Auto;
if isnan(auto); auto = prefAuto; end
if isnan(auto); auto = 0.5; end
configFile = opts.Config;
if ~fixture && configFile == ""; configFile = prefConfig; end
emit('benchFigGenUI %s on %s\n', string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), computer);
emit('MATLAB %s, repo %s\n', version, repo);
if fixture
    emit('project: the synthetic fixture (Scenarios=clean, NumTrials=40)\n');
else
    emit('project: %s\n', opts.Project);
    emit('config: %s (%s)\n', configFile, ternary(opts.Config ~= "", 'given', 'preference LastConfigFile'));
    if configFile == "" || ~isfile(configFile)
        error('benchFigGenUI:NoConfig', 'No config to open (LastConfigFile preference "%s", Config "%s"). Stop and ask.', prefConfig, opts.Config);
    end
end
emit('Auto slider: %.2f (%s)\n', auto, ternary(~isnan(opts.Auto), 'given', ternary(~isnan(prefAuto), 'preference FigureAutoRedraw', 'default')));

try
    % ---- open the app ----
    t = tic;
    if fixture
        fixtureRoot = string(fullfile(tempdir, sprintf('bench_figgen_%s', char(datetime('now', 'Format', 'yyyyMMdd_HHmmss')))));
        mkdir(fixtureRoot);
        here0 = pwd;
        cd(fullfile(repo, 'analysis', 'private'));
        mk = @makeAnalysisFixture;
        cd(here0);
        F = mk(fixtureRoot, Scenarios="clean", NumTrials=40);
        emit('fixture built in %.1f s\n', toc(t));
        t = tic;
        app = EphysFigGenApp(F.proj, Splash=false);
        emit('app opened in %.1f s\n', toc(t));
    else
        app = EphysFigGenApp(opts.Project, Splash=false);
        emit('app opened on the project (scan included) in %.1f s\n', toc(t));
        t = tic;
        ok = app.openConfigFile(configFile);
        emit('config opened (ok=%d, scan included) in %.1f s\n', ok, toc(t));
        if ~ok; error('benchFigGenUI:OpenFailed', 'The config could not be opened.'); end
    end
    app.FigureAutoSlider.Value = auto;
    app.onFigureAutoRedrawChanged();
    app.selectTab(app.TabFigures);
    if fixture
        app.onAddFigure("rasterPsth");
        app.onPanelSelected(2);
        app.onNewPanel(Type="continuous", Where="below");
        app.onPanelSelected(1);
        app.onNewPanel(Type="psth", Where="right");
        drawnow;
    end
    figs = app.Config.Figures;
    emit('figures: %d (%s)\n', numel(figs), strjoin([figs.id], ", "));

    % ---- the figure and panels ----
    k1 = 0;
    if opts.Figure ~= ""
        k1 = app.Config.figureIndex(opts.Figure);
        if k1 < 1; error('benchFigGenUI:NoFigure', 'No figure "%s".', opts.Figure); end
    else
        k1 = find(arrayfun(@(f) numel(f.panels) >= 2, figs), 1);
        if isempty(k1); error('benchFigGenUI:NoPanels', 'No figure has two panels.'); end
        if k1 ~= 1; emit('the first figure has fewer than 2 panels; using figure %d\n', k1); end
    end
    fig1 = figs(k1);
    ids = [fig1.panels.id];
    types = [fig1.panels.type];
    panels = opts.Panels;
    if isempty(panels); panels = ids(1:2); end
    id1 = panels(1);
    id2 = panels(2);
    emit('figure %d: %s, panels %s, bench panels %s and %s, sessions.enabled=%d\n', k1, fig1.id, ...
        strjoin(ids + " (" + types + ")", ", "), id1, id2, fig1.sessions.enabled);

    app.onFigureSelected(k1);
    t = tic;
    app.refreshFigurePreview(Force=true);
    drawnow;
    [w, st] = waitPreview(app, 120);
    emit('first draw of the figure: %.1f s, state %s\n', toc(t), st);
    addRow('first draw (not an action)', NaN, toc(t), w, st, NaN, "");

    % ---- a. counts ----
    emit('\n=== counts ===\n');
    nAll = numel(findall(app.Fig));
    nMenus = numel(findall(app.Fig, '-depth', 1, 'Type', 'uicontextmenu'));
    emit('findall(app.Fig): %d objects\n', nAll);
    emit('uicontextmenus at depth 1: %d\n', nMenus);
    emit('FigureViews kept: %d\n', numel(app.FigureViews));
    emit('Config.Figures: %d\n', numel(app.Config.Figures));
    emit('panels of the figure: %d (%s)\n', numel(ids), strjoin(types, ", "));
    emit('timers: %d\n', numel(timerfindall));
    dr = zeros(1, 3);
    for q3 = 1:3; t3 = tic; drawnow; dr(q3) = toc(t3); end
    emit('bare drawnow: %s s\n', strjoin(compose('%.4f', dr), ', '));

    % ---- b. select ----
    emit('\n=== select ===\n');
    p1 = find(ids == id1, 1);
    p2 = find(ids == id2, 1);
    fid1 = fig1.id;
    toPanel1 = @() app.onPanelSelected(p1);
    toPanel2 = @() app.onPanelSelected(p2);
    measure('Ctrl+click panel 2', @() app.onFigurePanelClicked(fid1, id2, true, false, false), struct('Reps', opts.Reps, 'Setup', toPanel1));
    measure('Ctrl+click panel 1', @() app.onFigurePanelClicked(fid1, id1, true, false, false), struct('Reps', opts.Reps, 'Setup', toPanel2));
    measure('Ctrl+click panel 2 (no profiler)', @() app.onFigurePanelClicked(fid1, id2, true, false, false), ...
        struct('Reps', opts.Reps, 'Setup', toPanel1, 'Profile', false));
    measure('Ctrl+click panel 1 (no profiler)', @() app.onFigurePanelClicked(fid1, id1, true, false, false), ...
        struct('Reps', opts.Reps, 'Setup', toPanel2, 'Profile', false));
    app.onPanelSelected(p1);
    drawnow;
    measure('Shift+click panel 2 (adds it)', @() app.onFigurePanelClicked(fid1, id2, false, false, true), struct());
    measure('Escape (the shown panel alone)', @() app.onKeyPress(pressed('escape')), struct());
    app.onPanelSelected(p1);
    drawnow;
    measure('Shift+click panel 2 (no profiler)', @() app.onFigurePanelClicked(fid1, id2, false, false, true), struct('Profile', false));
    measure('Escape (no profiler)', @() app.onKeyPress(pressed('escape')), struct('Profile', false));
    app.onPanelSelected(p1);

    % ---- c. figure switch ----
    emit('\n=== figure switch ===\n');
    k2 = find((1:numel(figs)) ~= k1, 1);
    if isempty(k2)
        emit('only one figure: skipped\n');
        addRow('switch to another figure', NaN, NaN, NaN, "", NaN, "skipped: one figure");
    else
        emit('switching between figure %d (%s) and %d (%s)\n', k1, figs(k1).id, k2, figs(k2).id);
        measure(sprintf('switch to figure %d', k2), @() app.onFigureSelected(k2), struct('Wait', true));
        measure(sprintf('switch back to figure %d', k1), @() app.onFigureSelected(k1), struct('Wait', true));
        k3 = find(~ismember(1:numel(figs), [k1 k2]) & arrayfun(@(f) ~f.sessions.enabled && ~f.probe.enabled && numel(f.panels) >= 2, figs), 1);
        if ~isempty(k3)   % a figure not drawn yet: the whole draw, true times
            measure(sprintf('switch to figure %d, not drawn yet (no profiler)', k3), @() app.onFigureSelected(k3), struct('Wait', true, 'Profile', false));
            measure(sprintf('switch back to figure %d (no profiler)', k1), @() app.onFigureSelected(k1), struct('Wait', true, 'Profile', false));
        end
        if app.FigurePreviewState ~= "drawn"
            app.refreshFigurePreview(Force=true);
            drawnow;
            waitPreview(app, 120);
        end
    end

    % ---- d. Arrange ----
    emit('\n=== arrange ===\n');
    app.onFigureSelected(k1);
    if fixture   % the fixture's panels lie flush, so no small move keeps their neighbors: a 2 x 2 grid with gaps
        cfgA = app.gatherConfig();
        pg = cfgA.Figures(k1).panels;
        grid = [0.02 0.52 0.46 0.46; 0.52 0.52 0.46 0.46; 0.02 0.02 0.46 0.46; 0.52 0.02 0.46 0.46];
        for j = 1:min(numel(pg), 4); pg(j).rect = grid(j, :); end
        cfgA.Figures(k1).panels = pg;
        app.applyConfig(cfgA);
        drawnow;
        app.onFigureSelected(k1);
        app.refreshFigurePreview(Force=true);
        drawnow;
        [~, st] = waitPreview(app, 120);
        figs = app.Config.Figures;
        fig1 = figs(k1);
        emit('fixture panels set to a 2 x 2 grid with gaps (not timed); state %s\n', st);
    end
    if app.FigurePreviewState ~= "drawn"; app.refreshFigurePreview(Force=true); drawnow; waitPreview(app, 120); end
    app.onPanelSelected(p1);
    measure('Arrange on', @() arrangeOn(true), struct('Wait', true));
    O = app.FigureArrangeOverlay;
    if ~isstruct(O) || ~isKey(O.widgets, char(id2))
        emit('no Arrange box for %s (overlay %s)\n', id2, class(O));
        addRow('arrange boxes', NaN, NaN, NaN, string(app.FigurePreviewState), NaN, "no boxes: the rest of Arrange skipped");
    else
        app.onPanelSelected(p1);
        drawnow;
        measure('Arrange press on unselected box', @() app.onArrangeClicked(id2, struct('SelectionType', 'normal')), struct());
        r2 = rectOf(id2);
        dxs = 0.01 * mod(1:20, 5);
        if r2(1) + r2(3) + 0.05 > 1; dxs = -dxs; end
        n = 0;
        stepFcn = @() stepMove();
        measure('Arrange drag step (no profiler)', stepFcn, struct('Reps', 20, 'Profile', false, 'Rows', 'summary', 'Settle', false));
        n = 0;
        measure('Arrange drag step (profiled)', stepFcn, struct('Reps', 20, 'Rows', 'summary', 'Settle', false));
        % release 1: a small shift that keeps the neighbors
        [target1, why1] = neighborKeeping(ids, id2);
        emit('release 1 target %s (%s)\n', mat2str(target1, 4), why1);
        measure('Arrange release, neighbors kept', @() release(target1), struct('Wait', true));
        emit('  rect now %s; neighbors unchanged: %d\n', mat2str(rectOf(id2), 4), sameNeighbors(rectOf(id2), id2, ids, fig1));
        % drag 2: flush against a neighbor
        app.onArrangeClicked(id2, struct('SelectionType', 'normal'));
        r2 = rectOf(id2);
        n = 0;
        dxs = 0.01 * mod(1:20, 5);
        if r2(1) + r2(3) + 0.05 > 1; dxs = -dxs; end
        app.onArrangeMoving(id2, images.roi.ROIMovingEventData(r2, r2 + [dxs(1) 0 0 0]));
        [target2, why2] = flushTarget(ids, id2);
        emit('release 2 target %s (%s)\n', mat2str(target2, 4), why2);
        measure('Arrange release, neighbors changed', @() release(target2), struct('Wait', true));
        emit('  rect now %s; neighbors unchanged: %d\n', mat2str(rectOf(id2), 4), sameNeighbors(rectOf(id2), id2, ids, fig1));
        app.onArrangeClicked(id2, struct('SelectionType', 'normal'));
        measure('Arrange right-arrow nudge', @() app.onKeyPress(pressed('rightarrow')), struct('Wait', true));
    end
    measure('Arrange off', @() arrangeOn(false), struct('Wait', true));
    settleWait();
    % ---- d2. Arrange again, no profiler (the overlay kept; true times) ----
    for pass = 1:2
        tag = sprintf(' (no profiler, pass %d)', pass);
        np0 = struct('Wait', true, 'Profile', false);
        if app.FigurePreviewState ~= "drawn"; app.refreshFigurePreview(Force=true); drawnow; waitPreview(app, 120); end
        app.onPanelSelected(p1);
        drawnow;
        measure(['Arrange on' tag], @() arrangeOn(true), np0);
        if ~isstruct(app.FigureArrangeOverlay) || ~isKey(app.FigureArrangeOverlay.widgets, char(id2)); break; end
        measure(['Arrange press on unselected box' tag], @() app.onArrangeClicked(id2, struct('SelectionType', 'normal')), struct('Profile', false));
        r2 = rectOf(id2);
        n = 0;
        dxs = 0.01 * mod(1:20, 5);
        if r2(1) + r2(3) + 0.05 > 1; dxs = -dxs; end
        app.onArrangeMoving(id2, images.roi.ROIMovingEventData(r2, r2 + [dxs(1) 0 0 0]));
        [t1, ~] = neighborKeeping(ids, id2);
        measure(['Arrange release, neighbors kept' tag], @() release(t1), np0);
        measure(['Arrange editor fill (timer)' tag], @() fireSelectTimer(), struct('Profile', false, 'Settle', false));
        app.onArrangeClicked(id2, struct('SelectionType', 'normal'));
        r2 = rectOf(id2);
        app.onArrangeMoving(id2, images.roi.ROIMovingEventData(r2, r2 + [dxs(1) 0 0 0]));
        [t2, why2b] = flushTarget(ids, id2);
        emit('pass %d flush target %s (%s)\n', pass, mat2str(t2, 4), why2b);
        measure(['Arrange release, neighbors changed' tag], @() release(t2), np0);
        app.onArrangeClicked(id2, struct('SelectionType', 'normal'));
        measure(['Arrange right-arrow nudge' tag], @() app.onKeyPress(pressed('rightarrow')), np0);
        measure(['Arrange off' tag], @() arrangeOn(false), np0);
        measure(['Arrange off: the redraw that follows' tag], @() settleWait(), struct('Profile', false, 'Settle', false));
    end

    % ---- e. a title edit ----
    emit('\n=== title edit ===\n');
    title0 = app.FigureEditor.title.Value;
    measure('title edit via onConfigChanged', @() editTitle('bench x'), struct('Wait', true));
    editTitle(title0);
    drawnow;
    waitPreview(app, 120);
    measure('title edit (no profiler)', @() editTitle('bench x'), struct('Wait', true, 'Profile', false));
    editTitle(title0);
    drawnow;
    waitPreview(app, 120);
    % the same title with a word added: the label variables it names are the same, so it is set in place
    measure('title edit, its variables kept (no profiler)', @() editTitle([char(title0) ' x']), struct('Wait', true, 'Profile', false));
    editTitle(title0);
    drawnow;
    waitPreview(app, 120);
catch ME
    emit('\nFAILED: %s\n', ME.message);
    for s = reshape(ME.stack(1:min(6, end)), 1, [])
        emit('  at %s line %d\n', s.name, s.line);
    end
    addRow('FAILED', NaN, NaN, NaN, "", NaN, string(ME.message));
end

% ---- the table ----
T = struct2table(rows, 'AsArray', true);
T.action = string(T.action);
T.state = string(T.state);
T.note = string(T.note);
emit('\n=== table (seconds; the profiler was on unless the action says otherwise) ===\n');
emit('%-44s %8s %8s %8s %-9s %5s  %s\n', 'action', 'call_s', 'paint_s', 'wait_s', 'state', 'busy', 'note');
for row = 1:height(T)
    emit('%-44s %8.3f %8.3f %8.2f %-9s %5g  %s\n', T.action(row), T.call_s(row), T.paint_s(row), T.wait_s(row), T.state(row), T.busy_delta(row), T.note(row));
end
if ~isempty(app) && isvalid(app); delete(app); end
if fixtureRoot ~= "" && isfolder(fixtureRoot)
    try rmdir(fixtureRoot, 's'); catch; end
end

    % ===== helpers (nested: they share app, rows, fid) =====
    function emit(fmt, varargin)
        txt = sprintf(fmt, varargin{:});
        fprintf('%s', txt);
        if fid > 0; fprintf(fid, '%s', txt); end
    end

    function addRow(action, call, paint, wait, state, busy, note)
        rows(end + 1) = struct('action', string(action), 'call_s', call, 'paint_s', paint, 'wait_s', wait, ...
            'state', string(state), 'busy_delta', busy, 'note', string(note));
    end

    function measure(name, fcn, o)
        % MEASURE  Time FCN Reps times (call alone, then to the paint after a drawnow), under the profiler.
        d = struct('Reps', 1, 'Setup', [], 'Wait', false, 'Profile', true, 'Rows', 'all', 'Settle', true);
        for f = fieldnames(o)'; d.(f{1}) = o.(f{1}); end
        o = d;
        call = nan(1, o.Reps);
        paint = nan(1, o.Reps);
        waits = nan(1, o.Reps);
        if o.Profile; profile clear; end
        for i = 1:o.Reps
            label = name;
            if o.Reps > 1; label = sprintf('%s [%d]', name, i); end
            try
                if ~isempty(o.Setup); o.Setup(); end
                drawnow;
                if o.Settle   % the browser's answers to the last action (a position event per control laid out) come in first, as between a person's clicks
                    for q = 1:2; pause(0.4); drawnow; end
                end
                b0 = app.FigurePreviewBusyCount;
                if o.Profile && i == 1; profile on; elseif o.Profile; profile resume; end
                t0 = tic;
                fcn();
                call(i) = toc(t0);
                drawnow;
                paint(i) = toc(t0);
                if o.Wait; [waits(i), ~] = waitPreview(app, 120); end
                if o.Profile; profile off; end
                if o.Rows == "all"
                    addRow(label, call(i), paint(i), waits(i), string(app.FigurePreviewState), app.FigurePreviewBusyCount - b0, "");
                end
            catch ME
                try profile off; catch; end
                addRow(label, NaN, NaN, NaN, string(app.FigurePreviewState), NaN, "ERROR: " + string(ME.message) + " (" + errorSite(ME) + ")");
                emit('ERROR in %s: %s (%s)\n', label, ME.message, errorSite(ME));
            end
        end
        if o.Reps > 1
            st = string(app.FigurePreviewState);
            addRow(name + " median", median(call, 'omitnan'), median(paint, 'omitnan'), median(waits, 'omitnan'), st, NaN, "");
            if o.Rows == "summary"
                addRow(name + " max", max(call), max(paint), max(waits), st, NaN, "");
                addRow(name + " first", call(1), paint(1), waits(1), st, NaN, "");
            end
        end
        if o.Profile
            try
                report(profile('info'), name);
            catch ME
                emit('profile report failed: %s\n', ME.message);
            end
        end
    end

    function report(P, name)
        FT = P.FunctionTable;
        if isempty(FT); emit('-- %s: no profile data --\n', name); return; end
        names = string({FT.FunctionName});
        tt = [FT.TotalTime];
        self = reshape(arrayfun(@(f) f.TotalTime - sum([f.Children.TotalTime]), FT), 1, []);
        emit('-- %s: top 12 by self time --\n', name);
        [~, o] = sort(self, 'descend');
        for i = reshape(o(1:min(12, end)), 1, [])
            emit('%8.3f self %8.3f total %6d calls  %s\n', self(i), tt(i), FT(i).NumCalls, names(i));
        end
        emit('-- %s: top 10 by total time --\n', name);
        [~, o] = sort(tt, 'descend');
        for i = reshape(o(1:min(10, end)), 1, [])
            emit('%8.3f total %8.3f self %6d calls  %s\n', tt(i), self(i), FT(i).NumCalls, names(i));
        end
    end

    function arrangeOn(tf)
        app.FigureArrangeButton.Value = tf;
        app.onArrangeToggled();
    end

    function r = rectOf(id)
        kk = app.SelectedFigure;
        pp = app.Config.Figures(kk).panels;
        r = pp([pp.id] == id).rect;
    end

    function stepMove()
        n = n + 1;
        app.onArrangeMoving(id2, images.roi.ROIMovingEventData(r2, r2 + [dxs(n) 0 0 0]));
    end

    function release(target)
        wgt = app.FigureArrangeOverlay.widgets(char(id2));
        wgt.Position = target;
        app.onArrangeMoved(id2, []);
    end

    function settleWait()
        % the redraw onArrangeToggled leaves to a timer, run now (and the preview waited for)
        t = [];
        try t = app.FigureSettleTimer; catch; end
        if ~isempty(t) && isvalid(t)
            f = t.TimerFcn;
            stop(t);
            f(t, []);
        end
        drawnow;
        waitPreview(app, 120);
        pause(0.5);   % (the browser's paint of a redraw ends before the next action is timed)
        drawnow;
    end

    function fireSelectTimer()
        t = [];
        try t = app.FigureSelectTimer; catch; end
        if ~isempty(t) && isvalid(t)
            f = t.TimerFcn;
            stop(t);
            f(t, []);
        end
    end

    function editTitle(v)
        app.FigureEditor.title.Value = v;
        app.onConfigChanged("figure");
    end

    function [target, why] = neighborKeeping(allIds, id)
        % A small shift of panel ID's rect that leaves figureNeighbors as it is, on the page.
        r = rectOf(id);
        base = neighborsOf(r, id, allIds);
        why = 'no shift kept the neighbors; the rect itself';
        target = r;
        for d = [0.02 -0.02 0.03 -0.03 0.05 -0.05]
            for axis = 1:2
                c = r;
                c(axis) = c(axis) + d;
                if c(1) < 0 || c(2) < 0 || c(1) + c(3) > 1 || c(2) + c(4) > 1; continue; end
                if isequal(neighborsOf(c, id, allIds), base)
                    target = c;
                    why = sprintf('shift %+.2f along %s', d, axisName(axis));
                    return
                end
            end
        end
    end

    function [target, why] = flushTarget(allIds, id)
        % A rect flush against another panel that changes figureNeighbors, on the page.
        r = rectOf(id);
        base = neighborsOf(r, id, allIds);
        pp = app.Config.Figures(app.SelectedFigure).panels;
        target = r;
        why = 'no flush place changed the neighbors; the rect itself';
        for q = 1:numel(pp)
            if pp(q).id == id; continue; end
            o2 = pp(q).rect;
            cands = {[o2(1) + o2(3), r(2), r(3), r(4)], [o2(1) - r(3), r(2), r(3), r(4)], ...
                [r(1), o2(2) + o2(4), r(3), r(4)], [r(1), o2(2) - r(4), r(3), r(4)]};
            names = ["right of" "left of" "above" "below"];
            for c = 1:4
                cc = cands{c};
                if cc(1) < 0 || cc(2) < 0 || cc(1) + cc(3) > 1 || cc(2) + cc(4) > 1; continue; end
                if ~isequal(neighborsOf(cc, id, allIds), base)
                    target = cc;
                    why = sprintf('flush %s %s', names(c), pp(q).id);
                    return
                end
            end
        end
    end

    function N = neighborsOf(r, id, allIds)
        pp = app.Config.Figures(app.SelectedFigure).panels;
        R = reshape([pp.rect], 4, []).';
        R(allIds == id, :) = r;
        S = figureNeighbors(R, EphysAnalysisConfig.RectTol);
        N = {S.below, S.above, S.left, S.right, S.flushV, S.flushH};
    end

    function tf = sameNeighbors(r, id, allIds, ~)
        % Whether the neighbors of the original layout (the config as first opened) equal those with ID at R.
        pp0 = figs(k1).panels;
        R0 = reshape([pp0.rect], 4, []).';
        S0 = figureNeighbors(R0, EphysAnalysisConfig.RectTol);
        N0 = {S0.below, S0.above, S0.left, S0.right, S0.flushV, S0.flushH};
        tf = isequal(neighborsOf(r, id, allIds), N0);
    end
end


function [secs, state] = waitPreview(app, limit)
%waitPreview  Wait while the preview computes or draws (up to LIMIT s); the seconds waited and the state.
t0 = tic;
while any(app.FigurePreviewState == ["computing" "drawing"]) && toc(t0) < limit
    pause(0.1);
    drawnow;
end
secs = toc(t0);
state = char(app.FigurePreviewState);
end


function a = axisName(k)
a = ["x" "y"];
a = a(k);
end


function s = errorSite(ME)
if isempty(ME.stack); s = "no stack"; return; end
s = string(ME.stack(1).name) + " line " + ME.stack(1).line;
end


function closeFile(fid)
if fid > 0; fclose(fid); end
end


function v = ternary(c, a, b)
if c; v = a; else; v = b; end
end
