classdef DatasetBrowser < handle
    %DatasetBrowser  Pick a project's datasets in a window, set the epoch settings, compute; read the result from a script.
    %   B = DatasetBrowser(ROOT) scans the project ROOT (an EphysProject root,
    %   or a copy of its output root), lists its datasets in a window where
    %   they are filtered, searched and ticked, holds the settings of
    %   epochMatrix in a form (the event, its sequence, the window and the
    %   trial selection in the analysis app's controls, AlignControls), and
    %   computes data(row, time, group) over the ticked datasets. A script
    %   waits for the window and reads the
    %   result through the handle:
    %
    %     B = DatasetBrowser(root, Settings="ofc_hit_depth.json");
    %     B.wait();          % tick, adjust, Compute, Done
    %     R = B.Result;      % R.data, R.rows, R.t, R.groupLabels, R.settings
    %
    %   Or it goes on with the result it has and leaves the window open for
    %   later changes: DatasetBrowser.open returns the window already open
    %   on ROOT (whatever the script's variables), else opens one.
    %
    %     B = DatasetBrowser.open(root);
    %     if isempty(B.Result), B.wait(); end   % nothing computed yet
    %     R = B.Result;      % after a Compute in the window, run again
    %
    %   Without a window the same methods work:
    %
    %     B = DatasetBrowser(root, Visible=false);
    %     B.setFilter(ExcludeSubjects="SUBJ-ID-1255", Tags=["ofc" "perceptual_training"], TagMode="all");
    %     B.tickShown();
    %     B.Settings = epochMatrixSettings(B.Settings, data="detected", binSec=0.01);
    %     R = B.compute();
    %
    %   Options
    %     NamePattern  the project's name pattern (default: the result
    %                  file's, else the last one used, else
    %                  EphysDataset.DefaultNamePattern)
    %     OutputRoot   the project's output root ("" = outputs beside the
    %                  recordings)
    %     Recordings   Open Ephys sessions with several recordings:
    %                  "concatenate" (default) | "separate" | "single"
    %     Settings     epochMatrixSettings' settings: a struct or a .json file
    %     Filter       a struct of setFilter's options
    %     ResultFile   default <ROOT>\DatasetBrowser_results.mat
    %     Visible      false: no window shows (tests, scripts)
    %     Scan         false: only restore the result file (B.Result) without
    %                  touching the share
    %     Workers      process workers compute and forEach compute the
    %                  datasets on (B.Workers; the Workers field beside
    %                  Cancel): 0 = here, one after the other; N >= 1 = up to
    %                  N datasets at once (Parallel Computing Toolbox;
    %                  DatasetRuns.run's Workers). Default: all workers of a
    %                  process pool already open, else the last one set,
    %                  else 0
    %   On opening, the ticks, filter, settings and result saved in the result
    %   file are restored, unless the options set them. With no saved state,
    %   the first scan ticks what the filter shows.
    %
    %   Scanning reads each dataset's outputs (which files exist, the manifest's
    %   tags, the stamp of its outputs: outputsStamp, whose one listing of
    %   the sorting folder replaces the check for a sort) but loads no
    %   source; the line and parameter lists of the form load one source
    %   when opened (the clicked row's, else the first ticked dataset's).
    %   Every dataset's part is kept in Runs (DatasetRuns,
    %   "epochMatrix/<data>", or "epochMatrix/<data>/epochs" with Keep each
    %   epoch) with the stamp of the scan: ticking a new
    %   dataset computes only that one, a settings change computes all
    %   again (but Normalize: it normalizes the result again in place,
    %   epochMatrixNormalize, and computes nothing), and a dataset whose
    %   outputs changed (a new sort, phy curation, a new spikes file, ...;
    %   seen at the next Scan) is computed again, a skipped one tried again. The Cached column says
    %   "✓ <n> rows", "skipped", "old" (another settings id or another
    %   stamp: Compute computes it again) or nothing. The result file (-v7.3,
    %   written through a temporary file) holds the browser's state, the
    %   result and Runs; it is written after a compute or forEach that added
    %   parts (a canceled one too), on Done and on close when the state
    %   changed. A root that cannot be written keeps them in memory, with
    %   the warning DatasetBrowser:NotSaved. Kept parts of an older
    %   DatasetRuns version are not restored (DatasetRuns:OldVersion): they
    %   are computed again.
    %
    %   The progress strip at the bottom is the browser's and a script's:
    %     B.progressStart("Histograms", Total=nS);
    %     for si = 1:nS
    %         B.progressStep(si, sprintf("Session %d", si));
    %         if B.CancelRequested, break, end     % or B.checkCancel()
    %         ...
    %     end
    %     B.progressFinish("Histograms done");
    %   Scan, compute and forEach drive it too (a compute inside a script's
    %   run takes the strip over). While Busy, every control but Cancel is
    %   off. checkCancel, once Cancel was pressed, ends a script's run as
    %   "Canceled" (the bar as it was, the controls on) before it throws. A
    %   script that stopped on an error leaves its run open: pressing
    %   Cancel a second time ends it ("Canceled"). The browser's own scan,
    %   compute and forEach end their runs themselves; a second Cancel does
    %   not end them early. With Visible=false, or once the window is
    %   closed, the same calls print a line to the command window at most
    %   every 2 s, and one at the finish.
    %
    %   Startup: a small window (AppSplash) shows the name, version and a
    %   progress bar while the window is built hidden, the last session
    %   restored and the root scanned; then the window shows. Splash=false
    %   starts without it (the default under -batch and with Visible=false).
    %
    %   Methods (each control's action has one)
    %     scan(B, Root=, NamePattern=)       find the datasets (the Scan button)
    %     setFilter(B, Subjects=, ExcludeSubjects=, Tags=, TagMode=, ExcludeTags=, Search=)
    %     clearFilter(B); tick(B, KEYS, TF); tickShown(B); untickAll(B)
    %     sortBy(B, COLUMN, DIRECTION); clearSort(B); setListSource(B, KEY)
    %     formEdit(B, CONTROL, VALUE)        a form control edited (Ctl.<CONTROL>, or Ctl.Align.<CONTROL>)
    %     fillLists(B)                       fill the line / parameter lists
    %     showEpochs(B)                      the Epoch Diagram window (EpochDiagram) of one dataset
    %     SRC = source(B, KEY)
    %     R = compute(B, Recompute=false)
    %     [VALUES, T] = forEach(B, FN, Name=, Id=, Datasets=, Recompute=, SkipIds=)
    %                  FN(SRC) or FN(SRC, INFO) per dataset, kept in Runs
    %                  (DatasetRuns.run); Name defaults to "forEach/" + func2str(FN)
    %     forget(B, NAME, KEYS); forgetTicked(B)   (nothing ticked: nothing dropped)
    %     loadSettings(B, FILE)              (no FILE: a file dialog; File > Load settings)
    %     saveSettings(B, FILE)              (no FILE: SettingsFile, else a file dialog; File > Save settings)
    %     saveSettingsAs(B)                  a file dialog (File > Save settings as)
    %     removeRecent(B, FILE); clearRecent(B)   File > Recent settings' list (RecentSettings)
    %     save(B, FILE); restore(B, FILE)    the result file
    %     progressStart, progress, progressStep, checkCancel, progressFinish, cancel
    %     wait(B, Timeout=Inf); done(B); close(B)
    %     B = DatasetBrowser.open(ROOT, ...)   the window open on ROOT, else a new browser
    %   Closing the window keeps the object: Result, compute and forEach work.
    %
    %   Errors: DatasetBrowser:NoRoot, DatasetBrowser:NotScanned,
    %   DatasetBrowser:NoneTicked, DatasetBrowser:UnknownDataset,
    %   DatasetBrowser:BadValue, DatasetBrowser:BadFilter,
    %   DatasetBrowser:NoFile, DatasetBrowser:Canceled (checkCancel; a scan);
    %   compute raises epochMatrix's (epochMatrix:Canceled after a Cancel)
    %   and forEach DatasetRuns' (DatasetRuns:Canceled). Warnings:
    %   DatasetBrowser:BadResultFile, DatasetBrowser:NotSaved, and with
    %   Workers DatasetRuns:Serial (no process pool: computed here).
    %   Preferences (AppPrefs group DatasetBrowser, saved on close): Root,
    %   NamePattern, Position, Sort, SettingsFolder, RecentSettings, Workers,
    %   OnTop.
    %
    %   See also epochMatrix, epochMatrixSettings, DatasetRuns, outputsStamp,
    %   datasetFilter, EphysAnalysisRunner.

    properties (SetAccess = private)
        Root (1,1) string = ""             % the project root
        OutputRoot (1,1) string = ""
        NamePattern (1,1) string = ""
        Recordings (1,1) string = "concatenate"
        Runner = []                        % the EphysAnalysisRunner of the last scan ([] before one)
        Datasets table                     % every dataset found: key, name, subject, date, session, tags (";"-joined), tagSet, units, detected, behavior, signals, stamp (outputsStamp at the scan)
        Result = []                        % the last compute's result ([] before one):
        %   R fields (size(R.data) = [height(R.rows), numel(R.t), numel(R.groupLabels)])
        %     R.data         double [nRows x nTime x nGroups]
        %                    The values: data(row, time, group). It holds the
        %                    measure (rate, count or auROC) for spikes, and the
        %                    group mean or median for signals. Wherever a row's
        %                    dataset has no epochs in a group, the value is NaN.
        %                    With settings.normalize.method other than "none" the
        %                    values are normalized (R.raw holds them before).
        %     R.rows         table, nRows rows
        %                    One row per unit (spikes) or channel (signals), in
        %                    data's first-dimension order. Columns for every kind:
        %                    label, Dataset (key), Subject, Date (day), Session,
        %                    Tags (";"-joined). Units add unitId, class ("su",
        %                    "mua", "det", ...), channel, channelName, shank, x, y,
        %                    nSpikes, and nSites/sites when merged. Channels add
        %                    channel, shank, x, y, units. A column that some
        %                    datasets lack is missing (missing/NaN) in their rows.
        %     R.t            double column, nTime
        %                    Times along data's second dimension, in s from the
        %                    event. For spikes these are bin centers (auROC window
        %                    centers for auroc); for signals, sample times.
        %     R.groupLabels  column, nGroups
        %                    Labels along data's third dimension, in
        %                    settings.selection.groupOrder. Numeric when grouped by
        %                    one parameter that is numeric in every dataset (e.g.
        %                    Depth), otherwise string: the value's text for one
        %                    parameter, "Depth = 3, Level = 2" for several.
        %     R.rowKind      string
        %                    "unit" or "channel".
        %     R.valueUnits   string
        %                    The unit of data: "spikes/s", "spikes/bin", "auROC",
        %                    "uV" or "V"; normalized: "z", "%", "x baseline" or
        %                    "0-1" ("subtract" keeps the unit). Use it for axis
        %                    labels.
        %     R.settings     struct
        %                    The settings that made R (see the table above), e.g.
        %                    R.settings.measure, R.settings.data,
        %                    R.settings.window.pre.
        %     R.datasets     table, one row per ticked dataset
        %                    key, name, subject, date, status ("done", "cached",
        %                    "skipped" or "error"), message, nRows, nEpochs,
        %                    nGroups, seconds. This table answers "why is dataset
        %                    X missing".
        %     R.keys         string column
        %                    The datasets whose rows are in R, in row order.
        %     R.created      datetime
        %                    When the result was assembled.
        %     R.raw          double, the size of R.data, or []
        %                    The values before normalization ([] when
        %                    settings.normalize.method is "none").
        %     R.normalization struct
        %                    How R.data was normalized (epochMatrixNormalize):
        %                    method, baseline, scope, rawUnits, center and scale
        %                    (R.data = (R.raw - center) ./ scale), undefined
        %                    (logical [nRows x nGroups]: NaN for a zero or flat
        %                    baseline), nBaseline.
        %     R.labels       struct
        %                    Labels and a description in words (epochMatrixLabels):
        %                    value (R.data's axis label), measure, time (R.t's),
        %                    event, group, groups (one per group), rows, trials,
        %                    window, bins, baseline, normalization, description.
        %                    A restored result's are made again, in the current
        %                    wording.
        %     R.epochs       struct column, one per dataset of R.keys, or []
        %                    Each epoch before any average, with
        %                    settings.keepEpochs (the Measure tab's "Keep each
        %                    epoch"): key, name, rows (of R.rows), E (the epochs,
        %                    with resultGroup, the group in R.groupLabels), and
        %                    spikes (per row: times from the event, epoch) or
        %                    data (signals: single [nRows x nTime x nEpochs]).
        %                    See epochMatrix. The result file leaves them out
        %                    (the kept parts hold them); a restore assembles
        %                    them again from the parts.
        %   Notes on the fields:
        %     Subject and Date come from subjectAndDate: the subject from the
        %     dataset's name (the project's name pattern); the date is the day
        %     the recording started (the project's AcqDate) when that is known,
        %     else the date in the name. The table's Subject and Date are the
        %     same (both use one function with the same inputs).
        %     Session is each subject's datasets numbered 1, 2, ... by date,
        %     counting only the datasets that contribute rows (as the script
        %     does): the rank of the dataset's date among them, so two datasets
        %     of one day share a number. A NaT date gives NaN. (The table's
        %     Session counts every dataset listed.)
        %     Group labels: NaN is treated as one label, and groups are matched
        %     across datasets as epochMatrix's help describes.
        %   ("The table above" is epochMatrixSettings' list of the fields of S.)
        Runs                               % the DatasetRuns holding every dataset's parts and forEach values
        Busy (1,1) logical = false         % the progress strip is running (progressStart .. progressFinish)
        CancelRequested (1,1) logical = false   % Cancel was pressed (or cancel() called) since progressStart
        Fig = []                           % the uifigure
        Ctl = struct()                     % the controls
        Sort = TableSort.none()            % the table's sort (a header click; TableSort state)
        SettingsFile (1,1) string = ""     % the settings file last loaded or saved ("" = none): saveSettings() writes it
        RecentSettings (:,1) string = strings(0, 1)   % the settings files last loaded or saved, newest first (File > Recent settings)
    end

    properties
        OnChange = []                      % OnChange(B, what): "scan" | "filter" | "ticks" | "settings" | "result" | "done" | "closed"
    end

    properties (Hidden)
        ProgressHook = []                  % ProgressHook(B, fraction, message) after each progress call (tests)
    end

    properties (Hidden, SetAccess = private)
        SequenceDialog = []                % the Event sequence window (AlignControls.editSequence), when open
        EpochWindow = []                   % the Epoch Diagram window (showEpochs), when open
    end

    properties (Dependent)
        Settings                           % epochMatrixSettings' struct (set: the whole struct, checked by epochMatrixSettings)
        Filter                             % struct: Subjects, ExcludeSubjects, Tags, TagMode, ExcludeTags, Search
        Selected                           % the ticked dataset keys (string column, in the datasets' order)
        ResultFile                         % the result file ("" = none)
        Table                              % the rows shown (the filter's, in the table's sort)
        Shown                              % their keys
        ResultCurrent                      % Result was computed with these settings on these ticks
        Workers                            % process workers compute and forEach use (0 = here; DatasetRuns.run's Workers)
        OnTop                              % the window stays above the other windows (WindowStyle "alwaysontop")
    end

    properties (Access = private)
        SettingsS = []                     % the full settings struct
        Id = []                            % its cache identity (epochMatrixSettings' ID)
        IdText (1,1) string = ""           % DatasetRuns.idText(Id)
        PartName (1,1) string = ""         % the Runs name of its parts (epochMatrixSettings' NAME)
        ResultIdText (1,1) string = ""     % ... of Result's
        FilterS = struct()
        SelectedKeys (:,1) string = strings(0, 1)
        HasTicks (1,1) logical = false     % the ticks were set (restored, given, or by a scan)
        ResultFileS (1,1) string = ""
        DefaultFile (1,1) logical = true   % ResultFile follows Root
        SavedSig (1,1) string = ""         % the state last written to (or read from) the result file
        NotSavedWarned (1,1) logical = false
        Clock = []                         % ProgressClock of the strip's run
        RunStart = []                      % tic of the strip's run
        RunTitle (1,1) string = ""
        RunTotal = []
        RunFraction (1,1) double = 0
        LastPrint (1,1) double = -Inf      % seconds into the run of the last printed line
        ListKey (1,1) string = ""          % the clicked row's dataset: the lists load its source
        SettingsFolder (1,1) string = ""
        DoneFlag (1,1) logical = false
        OwnRun (1,1) logical = false       % the strip's run is the browser's own scan, compute or forEach (they end it themselves)
        WorkersN (1,1) double = 0          % Workers
        OnTopS (1,1) logical = false       % OnTop
        Splash AppSplash = AppSplash.empty % the startup window (AppSplash; open while the window is built and the root scanned)
    end

    properties (Constant)
        PrefGroup = "DatasetBrowser"
        Schema = "dataset-browser-results"
        Version = 1
    end

    properties (Constant, Access = private)
        DataItems = ["units" "detected" "LFP" "MUA" "SPIKE" "AUX"]
        Controls = ["Root" "Browse" "Pattern" "Scan" "Subject" "NotSubject" "Search" "Tags" "TagMode" "NotTags" ...
            "TickShown" "UntickAll" "Table" "FileMenu" "Data" "Normalize" "NormBaseline" "NormScope" ...
            "Merge" "UnitShanks" "Measure" "Bin" "Baseline" ...
            "Channels" "SigShanks" "SigBaseline" "Detrend" "Rectify" "Magnitude" "Statistic" "KeepEpochs" "Compute" "Done" "Workers"]
        MaxRecent = 10                     % RecentSettings' length
        ErrorColor = [0.75 0.1 0.1]
        TextColor = [0.25 0.25 0.25]
    end

    methods
        function B = DatasetBrowser(root, opts)
            %DatasetBrowser  The browser of ROOT (see the class help).
            arguments
                root (1,1) string = ""
                opts.NamePattern (1,1) string
                opts.OutputRoot (1,1) string
                opts.Recordings (1,1) string
                opts.Settings = []
                opts.Filter = []
                opts.ResultFile (1,1) string = ""
                opts.Visible (1,1) logical = true
                opts.Scan (1,1) logical = true
                opts.Workers (1,1) double {mustBeInteger, mustBeNonnegative}
                opts.Splash (1,1) logical = ~batchStartupOptionUsed()   % no one watches a -batch run
            end
            % Behind the startup window (AppSplash) the UI is built hidden and
            % the root scanned; the window shows at the end. A hidden browser
            % (Visible=false) or Splash=false has none.
            [steps, weights] = startupSteps();
            B.Splash = AppSplash("Dataset browser", steps, weights, Show=opts.Visible && opts.Splash);
            splash = B.Splash;
            unfinished = onCleanup(@() splash.close()); %#ok<NASGU> an error closes the splash too
            B.Splash.step("settings", "Reading the preferences ...");
            B.Runs = DatasetRuns();
            B.Datasets = DatasetBrowser.emptyDatasets();
            B.FilterS = DatasetBrowser.noFilter();
            [S0, ID, name] = epochMatrixSettings();
            B.takeSettings(S0, ID, name);
            prefs = DatasetBrowser.readPrefs();
            if root == "" && isfield(prefs, 'Root'); root = string(prefs.Root); end
            B.Root = strtrim(root);
            B.NamePattern = EphysDataset.DefaultNamePattern;
            if isfield(prefs, 'NamePattern') && string(prefs.NamePattern) ~= ""; B.NamePattern = string(prefs.NamePattern); end
            if isfield(prefs, 'SettingsFolder'); B.SettingsFolder = string(prefs.SettingsFolder); end
            if isfield(prefs, 'RecentSettings') && (iscellstr(prefs.RecentSettings) || isstring(prefs.RecentSettings) || ischar(prefs.RecentSettings))
                r = reshape(string(prefs.RecentSettings), [], 1);
                B.RecentSettings = r(r ~= "");
            end
            if isfield(prefs, 'Sort'); B.Sort = TableSort.fromPref(prefs.Sort); end
            if isfield(prefs, 'Workers') && isnumeric(prefs.Workers) && isscalar(prefs.Workers) && prefs.Workers >= 0
                B.WorkersN = round(double(prefs.Workers));
            end
            nPool = DatasetBrowser.openPoolWorkers();
            if nPool > 0; B.WorkersN = nPool; end
            if isfield(opts, 'Workers'); B.WorkersN = opts.Workers; end
            if isfield(prefs, 'OnTop') && (islogical(prefs.OnTop) || isnumeric(prefs.OnTop)) && isscalar(prefs.OnTop)
                B.OnTopS = logical(prefs.OnTop);
            end
            B.DefaultFile = opts.ResultFile == "";
            B.ResultFileS = opts.ResultFile;
            if B.DefaultFile; B.ResultFileS = DatasetBrowser.defaultFile(B.Root); end

            B.Splash.step("window", "Building the window ...");
            B.build(prefs);
            B.Splash.step("restore", "Restoring the last session ...");
            % precedence: the options, then the result file, then the defaults
            if B.ResultFileS ~= "" && isfile(B.ResultFileS)
                B.restoreFile(B.ResultFileS, false);
            end
            if isfield(opts, 'NamePattern'); B.NamePattern = opts.NamePattern; end
            if isfield(opts, 'OutputRoot'); B.OutputRoot = opts.OutputRoot; end
            if isfield(opts, 'Recordings'); B.Recordings = opts.Recordings; end
            if ~isempty(opts.Settings)
                B.setSettings(opts.Settings, false);
                if isstring(opts.Settings) || ischar(opts.Settings)
                    B.tookFile(string(opts.Settings));
                else
                    B.SettingsFile = "";
                end
            end
            if ~isempty(opts.Filter); B.FilterS = DatasetBrowser.checkFilter(opts.Filter, DatasetBrowser.noFilter()); end
            B.refreshAll();
            behind = B.Splash.isOpen();   % the splash shows: the scan runs on the hidden window, then it shows
            if opts.Visible && ~behind; B.Fig.Visible = "on"; end
            if opts.Scan && B.Root ~= ""
                B.Splash.step("scan", "Scanning " + B.Root + " ...");
                if opts.Visible
                    B.uiRun(@() B.scan());
                else
                    B.scan();
                end
            elseif B.Root == ""
                B.setStatus("Choose the project root and press Scan.");
            end
            if behind
                B.Splash.step("show", "Drawing the window ...");
                B.Fig.Visible = "on";
                drawnow;
            end
            B.Splash.close();
        end

        function delete(B)
            B.closeWindows();
            if ~isempty(B.Fig) && isvalid(B.Fig); delete(B.Fig); end
        end

        % --- dependent properties ----------------------------------------------------------
        function S = get.Settings(B)
            S = B.SettingsS;
        end

        function set.Settings(B, S)
            B.closeSequenceDialog();
            B.setSettings(S, true);
        end

        function f = get.Filter(B)
            f = B.FilterS;
        end

        function set.Filter(B, f)
            if isempty(f); f = DatasetBrowser.noFilter(); end
            B.FilterS = DatasetBrowser.checkFilter(f, DatasetBrowser.noFilter());
            B.refreshFilterControls();
            B.refreshTable();
            B.changed("filter");
        end

        function k = get.Selected(B)
            k = B.SelectedKeys;
        end

        function set.Selected(B, keys)
            B.setTicks(B.keysOf(keys));
        end

        function f = get.ResultFile(B)
            f = B.ResultFileS;
        end

        function set.ResultFile(B, f)
            B.ResultFileS = string(f);
            B.DefaultFile = false;
        end

        function T = get.Table(B)
            T = B.buildTable();
        end

        function k = get.Shown(B)
            T = B.buildTable();
            k = T.Key;
        end

        function tf = get.ResultCurrent(B)
            [tf, ~] = B.resultState();
        end

        function n = get.Workers(B)
            n = B.WorkersN;
        end

        function set.Workers(B, n)
            arguments
                B
                n (1,1) double {mustBeInteger, mustBeNonnegative}
            end
            B.WorkersN = n;
            if B.uiOk(); B.Ctl.Workers.Value = n; end
        end

        function tf = get.OnTop(B)
            tf = B.OnTopS;
        end

        function set.OnTop(B, tf)
            arguments
                B
                tf (1,1) logical
            end
            B.OnTopS = tf;
            if B.uiOk()
                B.Ctl.OnTop.Value = tf;
                if tf; B.Fig.WindowStyle = "alwaysontop"; else; B.Fig.WindowStyle = "normal"; end
            end
        end

        % --- scanning ----------------------------------------------------------------------
        function scan(B, opts)
            %scan  Find the root's datasets: which outputs each has and its tags (no source is loaded).
            %   scan(B, Root=, NamePattern=) first takes a new root (its result
            %   file, when ResultFile follows the root) or name pattern, as
            %   the Scan button does with the fields above the table.
            arguments
                B
                opts.Root (1,1) string
                opts.NamePattern (1,1) string
            end
            if isfield(opts, 'Root') && strtrim(opts.Root) ~= B.Root; B.switchRoot(strtrim(opts.Root)); end
            if isfield(opts, 'NamePattern') && strtrim(opts.NamePattern) ~= ""; B.NamePattern = strtrim(opts.NamePattern); end
            [ok, why] = folderReachable(B.Root, 5);
            if ~ok
                error('DatasetBrowser:NoRoot', 'Cannot scan "%s": %s.', B.Root, why);
            end
            cfg = EphysAnalysisConfig();
            cfg.Source.Mode = "project";
            cfg.Source.Root = B.Root;
            cfg.Source.OutputRoot = B.OutputRoot;
            cfg.Source.NamePattern = B.NamePattern;
            cfg.Source.Recordings = B.Recordings;
            cfg.Source.Selection = "all";
            own = B.beginOwnRun(); %#ok<NASGU> cleared on return
            B.progressStart("Scanning " + B.Root);
            stopper = onCleanup(@() B.endRun("Scan stopped."));
            try
                r = EphysAnalysisRunner(cfg, LogFcn=[], ProgressFcn=@(f, m) B.scanProgress(0.5 * f, m));
                r.ProgressFcn = [];
                D = B.readDatasets(r);
            catch ME
                if endsWith(string(ME.identifier), ":Canceled")
                    B.endRun("Scan canceled: the datasets listed before stay.");
                    error('DatasetBrowser:Canceled', 'The scan was canceled.');
                end
                rethrow(ME);
            end
            B.Runner = r;
            B.Datasets = D;
            if B.HasTicks
                B.SelectedKeys = D.key(ismember(D.key, B.SelectedKeys));
            else
                B.SelectedKeys = D.key(B.filterKeep(D));
                B.HasTicks = true;
            end
            B.progressFinish(sprintf("%d dataset(s) found in %s", height(D), B.Root));
            clear stopper
            B.refreshAll();
            B.changed("scan");
        end

        % --- filter and ticks ----------------------------------------------------------------
        function setFilter(B, opts)
            %setFilter  Set some of the filter's terms (datasetFilter's options); the others stay.
            arguments
                B
                opts.Subjects
                opts.ExcludeSubjects
                opts.Tags
                opts.TagMode
                opts.ExcludeTags
                opts.Search
            end
            B.FilterS = DatasetBrowser.checkFilter(opts, B.FilterS);
            B.refreshFilterControls();
            B.refreshTable();
            B.changed("filter");
        end

        function clearFilter(B)
            %clearFilter  Show every dataset.
            B.Filter = [];
        end

        function tick(B, keys, tf)
            %tick  Tick (TF true, the default) or untick the datasets KEYS (keys or names).
            if nargin < 3; tf = true; end
            keys = B.keysOf(keys);
            if tf
                sel = [B.SelectedKeys; keys];
            else
                sel = B.SelectedKeys(~ismember(B.SelectedKeys, keys));
            end
            B.setTicks(sel);
        end

        function tickShown(B)
            %tickShown  Tick the datasets shown, untick those the filter hides.
            B.setTicks(B.Shown);
        end

        function untickAll(B)
            %untickAll  Untick every dataset, shown or hidden.
            B.setTicks(strings(0, 1));
        end

        function sortBy(B, column, direction)
            %sortBy  Sort the table by COLUMN (a column name), "ascend" (default) or "descend", as a header click.
            if nargin < 3; direction = "ascend"; end
            B.Sort = struct('column', string(column), 'direction', string(direction));
            B.refreshTable();
        end

        function clearSort(B)
            %clearSort  The rows in the scan's order again.
            B.Sort = TableSort.none();
            B.refreshTable();
        end

        function setListSource(B, key)
            %setListSource  The dataset whose lines and parameters the form's lists offer (a clicked row).
            k = B.keysOf(key);
            B.ListKey = k(1);
        end

        % --- the form --------------------------------------------------------------------------
        function formEdit(B, control, value)
            %formEdit  Put VALUE in the form control CONTROL (a field of Ctl or of Ctl.Align) and apply it, as an edit there.
            %   The edit is merged into the whole settings struct and checked
            %   (epochMatrixSettings); an edit that does not fit is undone in
            %   the control and its reason shown in the status line.
            control = string(control);
            if nargin > 2
                if isfield(B.Ctl.Align, control)
                    c = B.Ctl.Align.(control);
                else
                    c = B.Ctl.(control);
                end
                if isa(c, 'matlab.ui.control.ListBox')
                    c.Value = cellstr(string(value));
                elseif isa(c, 'matlab.ui.control.NumericEditField') || isa(c, 'matlab.ui.control.CheckBox') ...
                        || isa(c, 'matlab.ui.control.Spinner')
                    c.Value = value;
                else
                    c.Value = char(string(value));
                end
            end
            B.onFormEdit(control);
        end

        function fillLists(B)
            %fillLists  Offer the lines and trial parameters of one dataset in the form's lists.
            %   One source is loaded (B.source): the clicked row's dataset,
            %   else the first ticked one, else the first. Values typed or
            %   loaded that the dataset lacks stay.
            key = B.listKey();
            if key == "" || ~B.uiOk(); return; end
            try
                src = B.source(key);
            catch ME
                B.setStatus("Cannot read " + key + " for the lists: " + string(ME.message), true);
                return
            end
            AlignControls.fillItems(B.Ctl.Align, src);
            B.setStatus("Lists from " + src.name + ".");
        end

        function showEpochs(B)
            %showEpochs  The Epoch Diagram window (EpochDiagram): how the settings cut one dataset into epochs.
            %   The dataset is the one the lists come from (the clicked row's,
            %   else the first ticked). The window is redrawn on every
            %   settings edit and row click until it is closed; it closes
            %   with the browser. A second call raises it.
            B.needRunner();
            d = B.EpochWindow;
            if isempty(d) || ~isvalid(d) || ~d.isOpen()
                B.EpochWindow = EpochDiagram(Owner=B.Fig);
            else
                figure(d.Fig);
            end
            B.refreshEpochs();
        end

        function src = source(B, key)
            %source  The analysis source of dataset KEY (a key, name or index), loaded once by the runner.
            B.needRunner();
            src = B.Runner.source(key);
        end

        % --- compute ---------------------------------------------------------------------------
        function R = compute(B, opts)
            %compute  epochMatrix over the ticked datasets with Settings; the parts kept in Runs.
            arguments
                B
                opts.Recompute (1,1) logical = false
            end
            B.needRunner();
            keys = B.tickedKeys();
            if isempty(keys)
                error('DatasetBrowser:NoneTicked', 'Tick at least one dataset to compute.');
            end
            t0 = datetime('now');
            own = B.beginOwnRun(); %#ok<NASGU> cleared on return
            B.progressStart("Computing " + B.SettingsS.data);
            stopper = onCleanup(@() B.endRun("Compute stopped."));
            try
                R = epochMatrix(B.Runner, B.SettingsS, Datasets=keys, Info=B.info(keys), Runs=B.Runs, ...
                    Recompute=opts.Recompute, ProgressFcn=@(f, m) B.progress(f, m), CheckFcn=@() B.checkCancel(), ...
                    LogFcn=@(m) B.say(m), StampFcn=@(key) B.stampOf(key), Workers=B.WorkersN);
            catch ME
                if ME.identifier == "epochMatrix:Canceled"
                    B.endRun("Canceled: " + string(ME.message));
                end
                B.afterRun(t0);
                rethrow(ME);
            end
            B.setResult(R);
            B.progressFinish(B.summaryText());
            clear stopper
            B.afterRun(t0);
            B.changed("result");
        end

        function [values, T] = forEach(B, fn, opts)
            %forEach  FN(SRC) or FN(SRC, INFO) over datasets, each value kept in Runs (DatasetRuns.run).
            %   Name (default "forEach/" + func2str(FN)) names the cache, Id
            %   the identity of what FN computes (default: FN's text and what
            %   it captured; edits to code FN calls need Recompute=true),
            %   Datasets the keys (default: the ticked ones), SkipIds the error
            %   ids that mean "nothing to compute", Workers the process
            %   workers (default B.Workers; FN and what it captures are
            %   copied to them, a handle as a copy). A Cancel raises
            %   DatasetRuns:Canceled; the values finished stay in Runs.
            arguments
                B
                fn (1,1) function_handle
                opts.Name (1,1) string = "forEach/" + string(func2str(fn))
                opts.Id = []
                opts.Datasets = []
                opts.Recompute (1,1) logical = false
                opts.SkipIds (1,:) string = string.empty(1, 0)
                opts.Workers (1,1) double {mustBeInteger, mustBeNonnegative} = B.Workers
            end
            B.needRunner();
            if isempty(opts.Datasets)
                keys = B.tickedKeys();
            else
                keys = B.keysOf(opts.Datasets);
            end
            id = opts.Id;
            if isempty(id); id = DatasetRuns.defaultId(fn); end
            t0 = datetime('now');
            own = B.beginOwnRun(); %#ok<NASGU> cleared on return
            B.progressStart(opts.Name);
            stopper = onCleanup(@() B.endRun(opts.Name + " stopped."));
            try
                [values, T] = B.Runs.run(B.Runner, keys, fn, Name=opts.Name, Id=id, Info=B.info(keys), ...
                    Recompute=opts.Recompute, ProgressFcn=@(f, m) B.progress(f, m), CheckFcn=@() B.checkCancel(), ...
                    SkipIds=opts.SkipIds, StampFcn=@(key) B.stampOf(key), Workers=opts.Workers);
            catch ME
                if ME.identifier == "DatasetRuns:Canceled"
                    B.endRun("Canceled: " + string(ME.message));
                end
                B.afterRun(t0);
                rethrow(ME);
            end
            n = @(s) nnz(T.status == s);
            B.progressFinish(sprintf("%d computed, %d reused, %d skipped, %d failed", ...
                n("done"), n("cached"), n("skipped"), n("error")));
            clear stopper
            B.afterRun(t0);
        end

        function forget(B, varargin)
            %forget  Drop kept parts: forget(B), forget(B, NAME) or forget(B, NAME, KEYS) (DatasetRuns.forget).
            B.Runs.forget(varargin{:});
            B.refreshTable();
        end

        function forgetTicked(B)
            %forgetTicked  Drop the ticked datasets' parts for the current Data (the table's context menu).
            %   With nothing ticked nothing is dropped.
            if isempty(B.SelectedKeys)
                B.setStatus("Nothing is ticked: no cached parts were forgotten.");
                return
            end
            B.forget(B.PartName, B.SelectedKeys);
            B.setStatus(sprintf("Forgot the %s parts of %d ticked dataset(s).", B.SettingsS.data, numel(B.SelectedKeys)));
        end

        % --- settings files and the result file -------------------------------------------------
        function loadSettings(B, file)
            %loadSettings  Settings from a .json settings file (epochMatrixSettings(FILE)); no FILE: a file dialog.
            if nargin < 2 || string(file) == ""
                file = B.pickFile("get");
                if file == ""; return; end
            end
            file = string(file);
            B.Settings = epochMatrixSettings(file);
            B.tookFile(file);
            B.setStatus("Settings loaded from " + file + ".");
        end

        function saveSettings(B, file)
            %saveSettings  Write Settings to a .json settings file; no FILE: SettingsFile, else a file dialog.
            if nargin < 2 || string(file) == ""
                file = B.SettingsFile;
                if file == ""; B.saveSettingsAs(); return; end
            end
            file = string(file);
            epochMatrixSettings(B.SettingsS, SaveAs=file);
            B.tookFile(file);
            B.setStatus("Settings saved to " + file + ".");
        end

        function saveSettingsAs(B)
            %saveSettingsAs  Write Settings to a .json settings file picked in a file dialog.
            file = B.pickFile("put");
            if file == ""; return; end
            B.saveSettings(file);
        end

        function removeRecent(B, file)
            %removeRecent  Drop FILE (one or several) from RecentSettings (case ignored); the files stay.
            B.RecentSettings = B.RecentSettings(~ismember(lower(B.RecentSettings), lower(string(file(:)))));
            B.refreshFileMenu();
        end

        function clearRecent(B)
            %clearRecent  Empty RecentSettings; the files stay.
            B.RecentSettings = strings(0, 1);
            B.refreshFileMenu();
        end

        function tf = save(B, file)
            %save  Write the result file (default ResultFile): the state, Result and Runs. TF: written.
            if nargin < 2; file = B.ResultFileS; end
            file = string(file);
            tf = false;
            if file == ""; return; end
            R = B.Result;
            if isstruct(R) && isfield(R, 'epochs'); R.epochs = []; end   % the kept parts hold them: restoreEpochs
            payload = struct('schema', DatasetBrowser.Schema, 'version', DatasetBrowser.Version, ...
                'browser', B.browserState(), 'result', R, 'runs', B.Runs.toStruct());
            [folder, name] = fileparts(file);
            tmp = fullfile(folder, "." + name + "_saving.mat");
            try
                if folder ~= "" && ~isfolder(folder); mkdir(folder); end
                save(tmp, '-struct', 'payload', '-v7.3');
                [ok, msg] = movefile(tmp, file, 'f');
                if ~ok; error('DatasetBrowser:NotSaved', '%s', msg); end
            catch ME
                if isfile(tmp); try delete(tmp); catch; end; end
                if ~B.NotSavedWarned
                    warning('DatasetBrowser:NotSaved', 'Cannot write %s (%s): the results stay in memory only.', ...
                        file, ME.message);
                    B.NotSavedWarned = true;
                end
                B.setStatus("Not saved: " + string(ME.message), true);
                return
            end
            tf = true;
            if file == B.ResultFileS; B.SavedSig = B.stateSig(); end
        end

        function restore(B, file)
            %restore  Take the ticks, filter, settings, result and Runs from a result file (default ResultFile).
            %   A file that cannot be read, or a part of it that does not
            %   check, warns (DatasetBrowser:BadResultFile) and leaves that
            %   part at its default.
            if nargin < 2; file = B.ResultFileS; end
            B.closeSequenceDialog();
            B.restoreFile(string(file), true);
            B.refreshAll();
            if ~isempty(B.Result); B.changed("result"); end
        end

        % --- the progress strip ------------------------------------------------------------------
        function progressStart(B, title, opts)
            %progressStart  Start a run on the strip: clock reset, Cancel on, Busy, the other controls off.
            arguments
                B
                title (1,1) string = ""
                opts.Total = []
            end
            B.RunTitle = title;
            B.RunTotal = opts.Total;
            B.RunFraction = 0;
            B.CancelRequested = false;
            B.Busy = true;
            B.Clock = ProgressClock();
            B.RunStart = tic;
            B.LastPrint = -Inf;
            if B.uiOk() && ~B.Splash.isOpen()   % behind the splash it shows the progress
                B.setBar(0);
                B.Ctl.ProgMsg.Text = title;
                B.Ctl.ProgTime.Text = "";
                B.setBusyUI(true);
                drawnow limitrate
            end
        end

        function progress(B, fraction, message)
            %progress  Show FRACTION (0..1) done and MESSAGE; Cancel clicks are taken here (drawnow limitrate).
            if nargin < 3; message = ""; end
            f = double(fraction);
            if ~isfinite(f); f = B.RunFraction; end
            f = min(max(f, 0), 1);
            B.RunFraction = f;
            if isempty(B.Clock); B.Clock = ProgressClock(); B.RunStart = tic; end
            el = toc(B.RunStart);
            timeText = B.Clock.message(ProgressClock.elapsedText(el), f);
            message = string(message);
            behind = B.Splash.isOpen();
            if behind
                B.Splash.progress(f, message + " (" + timeText + ")");
            elseif B.uiOk()
                B.setBar(f);
                B.Ctl.ProgMsg.Text = message;
                B.Ctl.ProgTime.Text = timeText;
                drawnow limitrate
            end
            if ~behind && B.headless() && el - B.LastPrint >= 2
                B.LastPrint = el;
                fprintf('%s: %s (%d%%, %s)\n', B.RunTitle, message, round(100 * f), timeText);
            end
            if ~isempty(B.ProgressHook); B.ProgressHook(B, f, message); end
        end

        function progressStep(B, i, message)
            %progressStep  Step I of Total: fraction I/Total, MESSAGE prefixed "I/Total" (without Total: "I").
            if nargin < 3; message = ""; end
            if isempty(B.RunTotal)
                B.progress(B.RunFraction, sprintf("%d %s", i, message));
            else
                B.progress(i / B.RunTotal, sprintf("%d/%d %s", i, B.RunTotal, message));
            end
        end

        function checkCancel(B)
            %checkCancel  Throw DatasetBrowser:Canceled once Cancel was pressed.
            %   A script's run on the strip is ended first ("Canceled", the
            %   bar as it was, Busy off, the controls on); the browser's own
            %   scan, compute and forEach end theirs as they unwind.
            if B.uiOk() && ~B.Splash.isOpen(); drawnow limitrate; end
            if B.CancelRequested
                if B.Busy && ~B.OwnRun; B.finishRun("Canceled", false); end
                error('DatasetBrowser:Canceled', 'Canceled.');
            end
        end

        function progressFinish(B, message)
            %progressFinish  End the run: the bar full, "done in ...", Cancel off, Busy false.
            if nargin < 2; message = "Done"; end
            B.finishRun(string(message), true);
        end

        function cancel(B)
            %cancel  Ask the running scan, compute, forEach or script loop to stop (the Cancel button).
            %   Pressed again while a script's run is still open (the script
            %   stopped on an error, or never calls checkCancel), it ends
            %   that run ("Canceled") and turns the controls back on. The
            %   browser's own scan, compute and forEach are left to stop at
            %   their next check.
            if B.CancelRequested && B.Busy && ~B.OwnRun
                B.finishRun("Canceled", false);
                return
            end
            B.CancelRequested = true;
            if B.uiOk() && B.Busy
                B.Ctl.ProgMsg.Text = "Canceling ...";
            end
        end

        % --- the window ----------------------------------------------------------------------------
        function wait(B, opts)
            %wait  Block until Done is pressed or the window closes (returns at once when hidden or closed).
            arguments
                B
                opts.Timeout (1,1) double {mustBePositive} = Inf
            end
            if ~B.uiOk() || B.Fig.Visible ~= "on"; return; end
            B.DoneFlag = false;
            if isfinite(opts.Timeout)
                uiwait(B.Fig, opts.Timeout);
            else
                uiwait(B.Fig);
            end
        end

        function done(B)
            %done  The Done button: the state is saved (when it changed) and wait returns; the window stays.
            B.DoneFlag = true;
            B.saveIfChanged();
            B.changed("done");
            if B.uiOk(); uiresume(B.Fig); end
        end

        function close(B)
            %close  Close the window (its preferences and, when changed, the result file are saved); B stays.
            B.savePrefs();
            B.saveIfChanged();
            B.closeWindows();
            if B.uiOk(); delete(B.Fig); end
            B.changed("closed");
        end
    end

    methods (Static)
        function B = open(root, varargin)
            %open  The browser whose window is open on ROOT, else DatasetBrowser(ROOT, ...).
            %   An open window's browser is returned as it is (its ticks,
            %   settings and result); the options are only for a new one.
            %   ROOT "" takes any open window. Hidden browsers
            %   (Visible=false) are never returned. A script that calls it
            %   on every run keeps one window, even after a clear:
            %
            %     B = DatasetBrowser.open(root, NamePattern=namePattern);
            %     if isempty(B.Result), B.wait(); end
            %     R = B.Result;
            if nargin < 1; root = ""; end
            root = strtrim(string(root));
            figs = findall(groot, "Type", "figure", "Tag", "DatasetBrowser", "Visible", "on");
            for f = reshape(figs, 1, [])
                b = getappdata(f, "DatasetBrowser");
                if isa(b, "DatasetBrowser") && isvalid(b) && (root == "" || DatasetBrowser.sameRoot(b.Root, root))
                    B = b;
                    return
                end
            end
            B = DatasetBrowser(root, varargin{:});
        end
    end

    methods (Access = private)
        % --- building ------------------------------------------------------------------------------
        function build(B, prefs)
            f = uifigure("Name", "Dataset browser", "Position", [60 60 1380 860], "Visible", "off", ...
                "Tag", "DatasetBrowser", "CloseRequestFcn", @(~, ~) B.close());
            if B.OnTopS; f.WindowStyle = "alwaysontop"; end
            setappdata(f, "DatasetBrowser", B);   % DatasetBrowser.open finds the browser of an open window
            if isfield(prefs, 'Position') && isnumeric(prefs.Position) && numel(prefs.Position) == 4 && all(prefs.Position(3:4) > 200)
                f.Position = double(prefs.Position(:)).';
            end
            B.Fig = f;
            c = struct();

            % --- the File menu: the settings files
            c.FileMenu = uimenu(f, "Text", "File");
            uimenu(c.FileMenu, "Text", "Load settings...", "Accelerator", "O", ...
                "Tooltip", "Settings from a .json settings file.", "MenuSelectedFcn", @(~, ~) B.uiRun(@() B.loadSettings()));
            c.RecentMenu = uimenu(c.FileMenu, "Text", "Recent settings");
            uimenu(c.FileMenu, "Text", "Save settings", "Accelerator", "S", "Separator", "on", ...
                "Tooltip", "These settings to the settings file shown above the form (none yet: a file dialog).", ...
                "MenuSelectedFcn", @(~, ~) B.uiRun(@() B.saveSettings()));
            uimenu(c.FileMenu, "Text", "Save settings as...", ...
                "Tooltip", "These settings to a .json file (every field, also those the form does not show).", ...
                "MenuSelectedFcn", @(~, ~) B.uiRun(@() B.saveSettingsAs()));
            uimenu(c.FileMenu, "Text", "Close", "Separator", "on", "MenuSelectedFcn", @(~, ~) B.close());

            g = uigridlayout(f, [4 1], "RowHeight", {30, '1x', 30, 22}, "Padding", [8 8 8 6], "RowSpacing", 6);

            % --- the root and the pattern
            t = uigridlayout(g, [1 7], "ColumnWidth", {'fit', '1x', 90, 'fit', 300, 100, 'fit'}, "RowHeight", {30}, "Padding", [0 0 0 0]);
            uilabel(t, "Text", "Root");
            c.Root = uieditfield(t, "text", "Value", B.Root, "Tooltip", "The project root (or a copy of its output root); press Scan to list its datasets.");
            c.Browse = uibutton(t, "Text", "Browse...", "ButtonPushedFcn", @(~, ~) B.onBrowse());
            uilabel(t, "Text", "Pattern");
            c.Pattern = uieditfield(t, "text", "Value", B.NamePattern, "Tooltip", "The project's name pattern: the subject and date of each dataset come from its name.");
            c.Scan = uibutton(t, "Text", "Scan", "ButtonPushedFcn", @(~, ~) B.uiRun(@() B.scan(Root=string(B.Ctl.Root.Value), ...
                NamePattern=string(B.Ctl.Pattern.Value))), "Tooltip", "List the root's datasets: which outputs each has and its tags (no dataset is loaded).");
            c.OnTop = uicheckbox(t, "Text", "Keep on top", "Value", B.OnTopS, "ValueChangedFcn", @(src, ~) B.uiRun(@() B.setOnTopFrom(src.Value)), ...
                "Tooltip", "Keep this window above the other windows.");

            m = uigridlayout(g, [1 2], "ColumnWidth", {'1x', 470}, "RowHeight", {'1x'}, "Padding", [0 0 0 0]);

            % --- left: the filter, the count and the table
            L = uigridlayout(m, [4 1], "RowHeight", {30, 30, 20, '1x'}, "Padding", [0 0 0 0], "RowSpacing", 4);
            refilter = @(~, ~) B.uiRun(@() B.onFilterControls());
            r1 = uigridlayout(L, [1 6], "ColumnWidth", {'fit', 170, 'fit', 170, 'fit', '1x'}, "RowHeight", {30}, "Padding", [0 0 0 0]);
            uilabel(r1, "Text", "Subject");
            c.Subject = uidropdown(r1, "Items", {'(any)'}, "Editable", "on", "Value", '(any)', "ValueChangedFcn", refilter, ...
                "Tooltip", "Show these subjects: pick one, or type several separated by commas; * and ? are wildcards.");
            uilabel(r1, "Text", "not");
            c.NotSubject = uidropdown(r1, "Items", {'(any)'}, "Editable", "on", "Value", '(any)', "ValueChangedFcn", refilter, ...
                "Tooltip", "Leave these subjects out (comma-separated; * and ? are wildcards).");
            uilabel(r1, "Text", "Search");
            c.Search = uieditfield(r1, "text", "ValueChangedFcn", refilter, ...
                "ValueChangingFcn", @(~, evt) B.uiRun(@() B.onSearchTyping(evt.Value)), ...
                "Placeholder", "words in the name, key, subject or tags", "Tooltip", "Every word must appear (case ignored).");
            r2 = uigridlayout(L, [1 8], "ColumnWidth", {'fit', 170, 80, 'fit', 170, 'fit', 'fit', '1x'}, "RowHeight", {30}, "Padding", [0 0 0 0]);
            uilabel(r2, "Text", "Tags");
            c.Tags = uidropdown(r2, "Items", {'(any)'}, "Editable", "on", "Value", '(any)', "ValueChangedFcn", refilter, ...
                "Tooltip", "Show the datasets with these tags (any or all of them): pick one, or type several separated by commas.");
            c.TagMode = uidropdown(r2, "Items", {'any of', 'all of'}, "ItemsData", {'any', 'all'}, "Value", 'any', "ValueChangedFcn", refilter);
            uilabel(r2, "Text", "not");
            c.NotTags = uidropdown(r2, "Items", {'(any)'}, "Editable", "on", "Value", '(any)', "ValueChangedFcn", refilter, ...
                "Tooltip", "Leave out the datasets holding any of these tags.");
            c.TickShown = uibutton(r2, "Text", "Tick shown only", "ButtonPushedFcn", @(~, ~) B.uiRun(@() B.tickShown()), ...
                "Tooltip", "Tick the datasets shown and untick those the filter hides.");
            c.UntickAll = uibutton(r2, "Text", "Untick all", "ButtonPushedFcn", @(~, ~) B.uiRun(@() B.untickAll()));
            c.Count = uilabel(L, "Text", "", "FontColor", B.TextColor);
            c.Table = uitable(L, "RowName", {}, "ColumnSortable", true, ...
                "ColumnName", {'Use', 'Name', 'Subject', 'Date', 'Session', 'Tags', 'Units', 'Detected', 'Behavior', 'Signals', 'Cached', 'Key', ''}, ...
                "ColumnWidth", {42, 'auto', 100, 84, 66, 110, 52, 70, 70, 100, 100, 'auto', 1}, ...
                "CellEditCallback", @(~, evt) B.uiRun(@() B.onTableEdit(evt)), ...
                "CellSelectionCallback", @(~, evt) B.uiRun(@() B.onTableSelect(evt)), ...
                "DisplayDataChangedFcn", @(~, evt) B.onTableSorted(evt), ...
                "ContextMenu", uicontextmenu(f));
            uimenu(c.Table.ContextMenu, "Text", "Clear sort", "MenuSelectedFcn", @(~, ~) B.uiRun(@() B.clearSort()));
            uimenu(c.Table.ContextMenu, "Text", "Forget cached (ticked)", "MenuSelectedFcn", @(~, ~) B.uiRun(@() B.forgetTicked()));

            % --- right: the settings
            p = uipanel(m, "Title", "Settings");
            R = uigridlayout(p, [5 1], "RowHeight", {22, 26, '1x', 34, 48}, "Padding", [8 6 8 6], "RowSpacing", 5);
            edit = @(name) @(~, ~) B.uiRun(@() B.onFormEdit(name));
            open = @(~, ~) B.uiRun(@() B.fillLists());
            c.SettingsFile = uilabel(R, "Text", "", "FontColor", B.TextColor);
            r = row(R, {'fit', 100, '1x'});
            uilabel(r, "Text", "Data");
            c.Data = uidropdown(r, "Items", cellstr(B.DataItems), "ValueChangedFcn", edit("Data"), ...
                "Tooltip", "units: the sorted units; detected: the Spikes step's detections; LFP, MUA, SPIKE, AUX: a derived signal.");
            c.DataNote = uilabel(r, "Text", "", "FontColor", B.TextColor);
            % the event, its sequence, the window and the trial selection: the analysis app's controls (AlignControls)
            tg = uitabgroup(R);
            te = uitab(tg, "Title", "Event", "Scrollable", "on");
            eg = uigridlayout(te, [3 1], "RowHeight", {'fit', 'fit', '1x'}, "Padding", [4 4 4 4], "RowSpacing", 6);
            pr = uipanel(eg, "Title", "Event reference");
            pw = uipanel(eg, "Title", "Epoch window");
            tt = uitab(tg, "Title", "Trials", "Scrollable", "on");
            tm = uitab(tg, "Title", "Measure", "Scrollable", "on");
            A = AlignControls.build([pr pw tt], @(~) B.uiRun(@() B.onAlignEdit()), FixedWindow=true, ...
                EditSequence=@(varargin) B.uiRun(@() B.editSequence(varargin{:})), FilterHelp=@() B.uiRun(@() B.showFilterHelp()));
            set([A.Line A.StopLine A.Group1 A.Group2 A.ShiftParam A.StopShiftParam], "DropDownOpeningFcn", open);
            A.Diagram.ButtonPushedFcn = @(~, ~) B.uiRun(@() B.showEpochs());
            A.Diagram.Tooltip = "How these settings cut one dataset (the clicked row's, else the first ticked) into epochs: " + ...
                "the event, its sequence, the window and the trials kept.";
            c.Align = A;
            M = uigridlayout(tm, [4 1], "RowHeight", {26, 'fit', 'fit', 26}, "Padding", [4 4 4 4], "RowSpacing", 6);
            r = row(M, {'fit', 84, 'fit', '1x', 96});
            uilabel(r, "Text", "Normalize");
            c.Normalize = uidropdown(r, "Items", {'none', 'subtract', 'ratio', 'percent', 'zscore', 'minmax'}, ...
                "ValueChangedFcn", edit("Normalize"), "Tooltip", "Each row's trace against its baseline: " + ...
                "subtract (x - b), ratio (x / b), percent (100 (x - b) / |b|), zscore ((x - b) / SD over the baseline's bins), " + ...
                "minmax (0 to 1 over the window). Applied to the result: nothing is computed again. Not for auroc.");
            uilabel(r, "Text", "Baseline (s)");
            c.NormBaseline = uieditfield(r, "text", "ValueChangedFcn", edit("NormBaseline"), ...
                "Tooltip", "b0 b1, s from the event: the times whose mean (and SD) normalize each row.");
            c.NormScope = uidropdown(r, "Items", {'per row', 'per group'}, "ItemsData", {'row', 'group'}, ...
                "ValueChangedFcn", edit("NormScope"), "Tooltip", "per row: one baseline from all of a row's groups, " + ...
                "so the groups keep their differences; per group: each group its own.");

            sp = uipanel(M, "Title", "Spikes (units, detected)");
            sg = uigridlayout(sp, [3 4], "ColumnWidth", {'fit', '1x', 'fit', '1x'}, "RowHeight", {24, 24, 24}, "Padding", [6 4 6 4], "RowSpacing", 4);
            c.Merge = place(uicheckbox(sg, "Text", "Merge neighboring sites", "ValueChangedFcn", edit("Merge"), ...
                "Tooltip", "detected: join the channels of neighboring sites that hold one neuron (groupDetected)."), 1, [1 2]);
            place(uilabel(sg, "Text", "Shanks"), 1, 3);
            c.UnitShanks = place(uieditfield(sg, "text", "ValueChangedFcn", edit("UnitShanks"), "Placeholder", "all", ...
                "Tooltip", "e.g. 1:4 or 1 3; blank = every shank."), 1, 4);
            place(uilabel(sg, "Text", "Measure"), 2, 1);
            c.Measure = place(uidropdown(sg, "Items", {'rate', 'count', 'auroc'}, "ValueChangedFcn", edit("Measure")), 2, 2);
            place(uilabel(sg, "Text", "Bin (s)"), 2, 3);
            c.Bin = place(uieditfield(sg, "numeric", "Limits", [0 Inf], "LowerLimitInclusive", "off", "ValueChangedFcn", edit("Bin")), 2, 4);
            place(uilabel(sg, "Text", "auROC baseline (s)"), 3, [1 2]);
            c.Baseline = place(uieditfield(sg, "text", "ValueChangedFcn", edit("Baseline"), ...
                "Tooltip", "b0 b1, s from the event (measure auroc)."), 3, [3 4]);

            gp = uipanel(M, "Title", "Signals (LFP, MUA, SPIKE, AUX)");
            gg = uigridlayout(gp, [3 4], "ColumnWidth", {'fit', '1x', 'fit', '1x'}, "RowHeight", {24, 24, 24}, "Padding", [6 4 6 4], "RowSpacing", 4);
            place(uilabel(gg, "Text", "Channels"), 1, 1);
            c.Channels = place(uieditfield(gg, "text", "ValueChangedFcn", edit("Channels"), "Placeholder", "all", ...
                "Tooltip", "1-based columns of the signal, e.g. 1:16; blank = all."), 1, 2);
            place(uilabel(gg, "Text", "Shanks"), 1, 3);
            c.SigShanks = place(uieditfield(gg, "text", "ValueChangedFcn", edit("SigShanks"), "Placeholder", "all", ...
                "Tooltip", "The probe shanks kept, e.g. 1 2; blank = all."), 1, 4);
            place(uilabel(gg, "Text", "Baseline (s)"), 2, 1);
            c.SigBaseline = place(uieditfield(gg, "text", "ValueChangedFcn", edit("SigBaseline"), "Placeholder", "none", ...
                "Tooltip", "b0 b1: each epoch's mean over it is subtracted; blank = none."), 2, 2);
            place(uilabel(gg, "Text", "Statistic"), 2, 3);
            c.Statistic = place(uidropdown(gg, "Items", {'mean', 'median'}, "ValueChangedFcn", edit("Statistic")), 2, 4);
            c.Detrend = place(uicheckbox(gg, "Text", "Detrend", "ValueChangedFcn", edit("Detrend")), 3, 1);
            c.Rectify = place(uicheckbox(gg, "Text", "Rectify", "ValueChangedFcn", edit("Rectify")), 3, 2);
            c.Magnitude = place(uicheckbox(gg, "Text", "Magnitude (AUX)", "ValueChangedFcn", edit("Magnitude"), ...
                "Tooltip", "The channels' vector magnitude, one row (the accelerometer)."), 3, [3 4]);
            c.KeepEpochs = uicheckbox(M, "Text", "Keep each epoch (R.epochs)", "ValueChangedFcn", edit("KeepEpochs"), ...
                "Tooltip", "Keep every epoch before the average in B.Result.epochs: each spike's time from the event and its " + ...
                "epoch, or each epoch's signal trace (row x time x epoch). Computes every dataset once more; " + ...
                "signal epochs are large and go into the result file.");

            r = uigridlayout(R, [1 2], "ColumnWidth", {'1x', '1x'}, "RowHeight", {34}, "Padding", [0 0 0 0]);
            c.Compute = uibutton(r, "Text", "Compute", "ButtonPushedFcn", @(~, ~) B.uiRun(@() B.compute()), ...
                "Tooltip", "Compute the ticked datasets (those already computed with these settings are reused).");
            c.Done = uibutton(r, "Text", "Done", "ButtonPushedFcn", @(~, ~) B.uiRun(@() B.done()), ...
                "Tooltip", "Let the script go on with B.Result (the window stays open).");
            c.Summary = uilabel(R, "Text", "", "WordWrap", "on", "VerticalAlignment", "top");

            % --- the progress strip and the status line
            s = uigridlayout(g, [1 6], "ColumnWidth", {'1x', '1x', 'fit', 'fit', 60, 100}, "RowHeight", {30}, "Padding", [0 0 0 0]);
            c.ProgMsg = uilabel(s, "Text", "", "FontColor", B.TextColor);
            bgc = [0.92 0.92 0.94];
            bp = uipanel(s, "BorderType", "line", "BackgroundColor", bgc);
            c.Bar = uigridlayout(bp, [1 2], "Padding", [0 0 0 0], "ColumnSpacing", 0, "RowSpacing", 0, ...
                "BackgroundColor", bgc, "RowHeight", {'1x'}, "ColumnWidth", {0, '1x'});
            fill = uipanel(c.Bar, "BorderType", "none", "BackgroundColor", [0.25 0.55 0.85]);
            fill.Layout.Row = 1; fill.Layout.Column = 1;
            c.ProgTime = uilabel(s, "Text", "", "FontColor", B.TextColor);
            wTip = "Process workers that compute the datasets, several at once (Parallel Computing Toolbox). " + ...
                "0 = here, one after the other. Each worker holds one dataset in memory.";
            uilabel(s, "Text", "Workers", "Tooltip", wTip);
            c.Workers = uispinner(s, "Limits", [0 Inf], "RoundFractionalValues", "on", "Value", B.WorkersN, "Tooltip", wTip, ...
                "ValueChangedFcn", @(src, ~) B.uiRun(@() B.onWorkers(src.Value)));
            c.Cancel = uibutton(s, "Text", "Cancel", "Enable", "off", "ButtonPushedFcn", @(~, ~) B.cancel());
            c.Status = uilabel(g, "Text", "", "FontColor", B.TextColor);

            styleButton([c.Browse c.TickShown c.UntickAll]);
            styleButton([c.Scan c.Compute], "primary");
            styleButton(c.Done, "confirm");
            styleButton(c.Cancel, "danger");
            B.Ctl = c;
        end

        % --- refreshing ------------------------------------------------------------------------------
        function refreshAll(B)
            B.refreshFileMenu();
            B.refreshFilterControls();
            B.refreshForm();
            B.refreshTable();
            B.refreshSummary();
            if B.uiOk()
                B.Ctl.Root.Value = char(B.Root);
                B.Ctl.Pattern.Value = char(B.NamePattern);
            end
        end

        function T = buildTable(B)
            %buildTable  The rows shown: the filter's, in the table's sort, Idx the dataset's row of Datasets.
            D = B.Datasets;
            n = height(D);
            Use = ismember(D.key, B.SelectedKeys);
            Cached = strings(n, 1);
            if n > 0
                name = B.PartName;
                st = B.Runs.status(name, D.key, B.Id, Stamps=D.stamp);   % "old": other settings or changed outputs
                Cached(st == "skipped") = "skipped";
                Cached(st == "old") = "old";
                for k = reshape(find(st == "current"), 1, [])
                    v = B.Runs.value(name, D.key(k));
                    nr = 0;
                    if isstruct(v) && isfield(v, 'rows'); nr = height(v.rows); end
                    Cached(k) = sprintf("✓ %d rows", nr);
                end
            end
            mark = @(tf) replace(string(double(tf)), ["1" "0"], ["✓" ""]);
            Date = strings(n, 1);
            Date(~isnat(D.date)) = string(D.date(~isnat(D.date)), 'yyyy-MM-dd');
            Tags = strings(n, 1);
            for k = 1:n; Tags(k) = TagSet.toText(D.tagSet{k}, TagSet.DisplayDelimiter); end
            T = table(Use, D.name, D.subject, Date, D.session, Tags, mark(D.units), mark(D.detected), mark(D.behavior), ...
                D.signals, Cached, D.key, (1:n).', 'VariableNames', ...
                {'Use', 'Name', 'Subject', 'Date', 'Session', 'Tags', 'Units', 'Detected', 'Behavior', 'Signals', 'Cached', 'Key', 'Idx'});
            T = T(B.filterKeep(D), :);
            T = TableSort.apply(T, B.Sort);
        end

        function refreshTable(B)
            T = B.buildTable();
            if ~B.uiOk(); return; end
            c = B.Ctl;
            D = B.Datasets;
            syncItems(c.Subject, unique(D.subject(D.subject ~= "")));
            syncItems(c.NotSubject, unique(D.subject(D.subject ~= "")));
            voc = string(TagSet.vocabulary(reshape(D.tagSet, 1, [])));
            syncItems(c.Tags, voc);
            syncItems(c.NotTags, voc);
            c.Table.Data = T;
            c.Table.ColumnEditable = [true false(1, width(T) - 1)];
            n = height(D);
            nShown = height(T);
            nTicked = numel(B.SelectedKeys);
            hidden = nTicked - nnz(T.Use);
            if n == 0
                msg = "No datasets listed: press Scan.";
            elseif nShown == n
                msg = sprintf("showing all %d", n);
            else
                msg = sprintf("showing %d of %d", nShown, n);
            end
            if hidden > 0; msg = msg + sprintf(" (%d ticked hidden)", hidden); end
            if n > 0; msg = msg + sprintf(" · %d ticked", nTicked); end
            c.Count.Text = msg;
            B.refreshDataNote();
        end

        function refreshFileMenu(B)
            %refreshFileMenu  File > Recent settings from RecentSettings (a missing file grayed), and the settings file's label.
            if ~B.uiOk(); return; end
            c = B.Ctl;
            if B.SettingsFile == ""
                c.SettingsFile.Text = "Settings file: none (File > Save settings as...)";
                c.SettingsFile.Tooltip = "";
            else
                [~, n, e] = fileparts(B.SettingsFile);
                c.SettingsFile.Text = "Settings file: " + n + e;
                c.SettingsFile.Tooltip = B.SettingsFile + "  (File > Save settings writes it)";
            end
            M = c.RecentMenu;
            delete(M.Children);
            r = B.RecentSettings;
            if isempty(r)
                uimenu(M, "Text", "(none)", "Enable", "off");
                return
            end
            for k = 1:numel(r)
                f = r(k);
                if isfile(f)
                    uimenu(M, "Text", char(f), "MenuSelectedFcn", @(~, ~) B.uiRun(@() B.loadSettings(f)));
                else
                    uimenu(M, "Text", char(f + "  (not found)"), "Enable", "off");
                end
            end
            rm = uimenu(M, "Text", "Remove from list", "Separator", "on");
            for k = 1:numel(r)
                f = r(k);
                uimenu(rm, "Text", char(f), "MenuSelectedFcn", @(~, ~) B.uiRun(@() B.removeRecent(f)));
            end
            uimenu(M, "Text", "Clear list", "MenuSelectedFcn", @(~, ~) B.uiRun(@() B.clearRecent()));
        end

        function refreshFilterControls(B)
            if ~B.uiOk(); return; end
            c = B.Ctl;
            f = B.FilterS;
            setDrop(c.Subject, f.Subjects);
            setDrop(c.NotSubject, f.ExcludeSubjects);
            setDrop(c.Tags, f.Tags);
            setDrop(c.NotTags, f.ExcludeTags);
            c.TagMode.Value = char(f.TagMode);
            c.Search.Value = char(f.Search);
        end

        function refreshForm(B)
            %refreshForm  Every form control from Settings.
            if ~B.uiOk(); return; end
            c = B.Ctl;
            S = B.SettingsS;
            c.Data.Value = char(S.data);
            AlignControls.show(c.Align, S.ref, S.window, S.selection);
            c.Normalize.Value = char(S.normalize.method);
            c.NormBaseline.Value = char(numbersText(S.normalize.baseline));
            c.NormScope.Value = char(S.normalize.scope);
            c.Merge.Value = logical(S.units.merge.enabled);
            c.UnitShanks.Value = char(numbersText(S.units.shanks));
            c.Measure.Value = char(S.measure);
            c.Bin.Value = S.binSec;
            c.Baseline.Value = char(numbersText(S.baseline));
            c.Channels.Value = char(numbersText(S.signal.channels));
            c.SigShanks.Value = char(numbersText(S.signal.shanks));
            c.SigBaseline.Value = char(numbersText(S.signal.baseline));
            c.Statistic.Value = char(S.signal.statistic);
            c.Detrend.Value = S.signal.detrend;
            c.Rectify.Value = S.signal.rectify;
            c.Magnitude.Value = S.signal.magnitude;
            c.KeepEpochs.Value = S.keepEpochs;
            B.applyEnable();
            B.refreshDataNote();
        end

        function applyEnable(B)
            %applyEnable  Only the block matching Data is on (and within it what applies); all off while Busy.
            if ~B.uiOk() || B.Busy; return; end
            c = B.Ctl;
            S = B.SettingsS;
            spikes = ismember(S.data, ["units" "detected"]);
            on = @(tf) matlab.lang.OnOffSwitchState(tf);
            set([c.UnitShanks c.Measure c.Bin], "Enable", on(spikes));
            c.Merge.Enable = on(S.data == "detected");
            c.Baseline.Enable = on(spikes && S.measure == "auroc");
            auroc = spikes && S.measure == "auroc";
            c.Normalize.Enable = on(~auroc);
            c.NormBaseline.Enable = on(~auroc && ismember(S.normalize.method, ["subtract" "ratio" "percent" "zscore"]));
            c.NormScope.Enable = on(~auroc && S.normalize.method ~= "none");
            set([c.Channels c.SigBaseline c.Detrend c.Rectify c.Statistic], "Enable", on(~spikes));
            c.SigShanks.Enable = on(~spikes && S.data ~= "AUX");
            c.Magnitude.Enable = on(S.data == "AUX");
            AlignControls.syncEnable(c.Align);
            c.Compute.Enable = on(~isempty(B.Runner));
        end

        function refreshDataNote(B)
            %refreshDataNote  For a signal: how many ticked datasets lack it (they are skipped).
            if ~B.uiOk(); return; end
            d = B.SettingsS.data;
            txt = "";
            if ~ismember(d, ["units" "detected"]) && height(B.Datasets) > 0
                D = B.Datasets(ismember(B.Datasets.key, B.SelectedKeys), :);
                lack = nnz(~contains(" " + D.signals + " ", " " + d + " "));
                if lack > 0
                    txt = sprintf("%d of %d ticked lack %s (skipped)", lack, height(D), d);
                end
            elseif d == "units" && height(B.Datasets) > 0
                D = B.Datasets(ismember(B.Datasets.key, B.SelectedKeys), :);
                lack = nnz(~D.units);
                if lack > 0; txt = sprintf("%d of %d ticked have no sorting", lack, height(D)); end
            end
            B.Ctl.DataNote.Text = txt;
        end

        function refreshSummary(B)
            if ~B.uiOk(); return; end
            B.Ctl.Summary.Text = B.summaryText();
        end

        function s = summaryText(B)
            %summaryText  "812 units × 200 bins × 5 groups from 32 of 34 datasets; 1 computed, 33 reused", or why it is out of date.
            R = B.Result;
            if isempty(R)
                s = "No result yet: tick datasets and press Compute.";
                return
            end
            noun = ternary(R.rowKind == "unit", "units", "channels");
            tnoun = ternary(R.rowKind == "unit", "bins", "samples");
            st = R.datasets.status;
            s = sprintf("%d %s × %d %s × %d groups from %d of %d datasets; %d computed, %d reused", ...
                height(R.rows), noun, numel(R.t), tnoun, numel(R.groupLabels), numel(R.keys), height(R.datasets), ...
                nnz(st == "done"), nnz(st == "cached"));
            other = nnz(~ismember(st, ["done" "cached"]));
            if other > 0; s = s + sprintf(", %d skipped or failed", other); end
            if isfield(R, 'epochs') && ~isempty(R.epochs)
                s = s + sprintf("; %d epochs kept (R.epochs)", sum(arrayfun(@(e) height(e.E), R.epochs)));
            end
            if isfield(R, 'labels') && isstruct(R.labels) && isfield(R.labels, 'normalization') && R.labels.normalization ~= ""
                s = s + "; " + R.labels.normalization;
                nBad = nnz(any(R.normalization.undefined, 2));
                if nBad > 0; s = s + sprintf(" (%d %s NaN: a zero or flat baseline)", nBad, noun); end
            end
            [current, why] = B.resultState();
            if ~current; s = "Out of date: " + why + ". (" + s + ")"; end
        end

        function [tf, why] = resultState(B)
            %resultState  Whether Result matches the settings and the ticks, and what differs.
            tf = false;
            why = "";
            R = B.Result;
            if isempty(R); why = "no result"; return; end
            parts = strings(1, 0);
            if B.ResultIdText ~= B.IdText || ~sameNormalize(R.settings, B.SettingsS); parts(end+1) = "settings"; end
            if ~isequal(sort(string(R.datasets.key)), sort(B.SelectedKeys)); parts(end+1) = "ticks"; end
            tf = isempty(parts);
            if ~tf; why = strjoin(parts, " and ") + " changed"; end
        end

        % --- callbacks -----------------------------------------------------------------------------
        function uiRun(B, fcn)
            %uiRun  Run a control's action; its error goes to the status line.
            try
                fcn();
            catch ME
                if ~isvalid(B); return; end
                if endsWith(string(ME.identifier), ":Canceled")
                    B.setStatus("Canceled: " + string(ME.message));
                else
                    B.setStatus(string(ME.message), true);
                end
            end
        end

        function onWorkers(B, n)
            B.Workers = n;
            if n == 0
                B.setStatus("Compute works here, one dataset after the other.");
            else
                B.setStatus(sprintf("Compute works on up to %d process workers.", n));
            end
        end

        function onBrowse(B)
            start0 = char(B.Ctl.Root.Value);
            if isempty(start0) || ~isfolder(start0); start0 = pwd; end
            d = uigetdir(start0, "Choose the project root");
            if B.uiOk(); figure(B.Fig); end
            if isequal(d, 0); return; end
            B.Ctl.Root.Value = d;
        end

        function onFilterControls(B)
            c = B.Ctl;
            B.setFilter(Subjects=string(c.Subject.Value), ExcludeSubjects=string(c.NotSubject.Value), ...
                Tags=string(c.Tags.Value), TagMode=string(c.TagMode.Value), ExcludeTags=string(c.NotTags.Value), ...
                Search=string(c.Search.Value));
        end

        function onSearchTyping(B, text)
            %onSearchTyping  The search as typed (the field itself is left alone while it is being edited).
            B.FilterS = DatasetBrowser.checkFilter(struct('Search', string(text)), B.FilterS);
            B.refreshTable();
            B.changed("filter");
        end

        function onTableEdit(B, evt)
            %onTableEdit  A Use tick: the row's dataset (through Idx), whatever the sort.
            T = B.Ctl.Table.Data;
            if isempty(evt.Indices) || evt.Indices(1, 2) ~= 1; return; end
            k = T.Idx(evt.Indices(1, 1));
            B.tick(B.Datasets.key(k), logical(evt.NewData));
        end

        function onTableSelect(B, evt)
            if isempty(evt.Indices); return; end
            T = B.Ctl.Table.Data;
            r = evt.Indices(1, 1);
            if r < 1 || r > height(T); return; end
            key = B.Datasets.key(T.Idx(r));
            if key == B.ListKey; return; end
            B.ListKey = key;
            B.refreshEpochs();
        end

        function onTableSorted(B, evt)
            B.Sort = TableSort.fromEvent(B.Ctl.Table, evt, B.Sort);
        end

        function onFormEdit(B, name)
            %onFormEdit  Merge one control's value into the settings and check them; undo it when they do not fit.
            if isfield(B.Ctl.Align, name); B.onAlignEdit(); return; end
            try
                S = B.applyControl(B.SettingsS, name, B.Ctl.(name).Value);
                B.setSettings(S, true);
                B.setStatus("");
            catch ME
                B.refreshForm();
                B.setStatus("Not applied: " + string(ME.message), true);
            end
        end

        function S = applyControl(~, S, name, v)
            %applyControl  S with control NAME's value V put in its field (the other fields as they were).
            if iscell(v); v = v{1}; end
            switch name
                case "Data";     S.data = string(v);
                case "Normalize"; S.normalize.method = string(v);
                case "NormBaseline"; S.normalize.baseline = parseNumbers(v, "Normalize baseline");
                case "NormScope"; S.normalize.scope = string(v);
                case "Merge";    S.units.merge.enabled = logical(v);
                case "UnitShanks"; S.units.shanks = parseNumbers(v, "Shanks");
                case "Measure";  S.measure = string(v);
                case "Bin";      S.binSec = double(v);
                case "Baseline"; S.baseline = parseNumbers(v, "auROC baseline");
                case "Channels"; S.signal.channels = parseNumbers(v, "Channels");
                case "SigShanks"; S.signal.shanks = parseNumbers(v, "Shanks");
                case "SigBaseline"; S.signal.baseline = parseNumbers(v, "Baseline");
                case "Statistic"; S.signal.statistic = string(v);
                case {"Detrend", "Rectify", "Magnitude"}; S.signal.(lower(name)) = logical(v);
                case "KeepEpochs"; S.keepEpochs = logical(v);
                otherwise
                    error('DatasetBrowser:BadValue', 'No form control "%s".', name);
            end
        end

        % --- state -----------------------------------------------------------------------------------
        function setSettings(B, S, announce)
            %setSettings  Check S (epochMatrixSettings) and take it: the form, the Cached column, the summary.
            [S, ID, name] = epochMatrixSettings(S);
            B.takeSettings(S, ID, name);
            renormalized = B.renormalize();
            B.refreshForm();
            B.refreshTable();
            B.refreshSummary();
            B.refreshEpochs();
            if announce; B.changed("settings"); end
            if renormalized; B.changed("result"); end
        end

        function tf = renormalize(B)
            %renormalize  A result of these settings but for normalize: normalized again in place (nothing computed).
            R = B.Result;
            tf = ~isempty(R) && B.ResultIdText == B.IdText && ~sameNormalize(R.settings, B.SettingsS);
            if tf; B.Result = epochMatrixNormalize(R, B.SettingsS.normalize); end
        end

        function takeSettings(B, S, ID, name)
            B.SettingsS = S;
            B.Id = ID;
            B.IdText = DatasetRuns.idText(ID);
            B.PartName = name;
        end

        function setTicks(B, keys)
            keys = unique(reshape(string(keys), [], 1), 'stable');
            D = B.Datasets;
            if height(D) > 0
                keys = [D.key(ismember(D.key, keys)); keys(~ismember(keys, D.key))];   % in the datasets' order
            end
            B.SelectedKeys = keys;
            B.HasTicks = true;
            B.refreshTable();
            B.refreshSummary();
            B.changed("ticks");
        end

        function setResult(B, R)
            B.Result = R;
            B.ResultIdText = "";
            try
                [~, IDr] = epochMatrixSettings(R.settings);
                B.ResultIdText = DatasetRuns.idText(IDr);
            catch
            end
            B.refreshTable();
            B.refreshSummary();
        end

        function switchRoot(B, root)
            %switchRoot  Take another root: its own result file when ResultFile follows the root.
            B.Root = root;
            if ~B.DefaultFile; return; end
            B.ResultFileS = DatasetBrowser.defaultFile(root);
            B.Runner = [];
            B.Datasets = DatasetBrowser.emptyDatasets();
            B.Runs = DatasetRuns();
            B.Result = [];
            B.ResultIdText = "";
            B.SelectedKeys = strings(0, 1);
            B.HasTicks = false;
            B.SavedSig = "";
            if B.ResultFileS ~= "" && isfile(B.ResultFileS)
                B.restoreFile(B.ResultFileS, true);
            end
            B.refreshAll();
        end

        function restoreFile(B, file, takeRoot)
            %restoreFile  Read a result file; TAKEROOT: also its root when B has none.
            try
                L = load(file);
                if ~(isfield(L, 'schema') && string(L.schema) == DatasetBrowser.Schema && isfield(L, 'browser') ...
                        && isfield(L, 'version') && L.version <= DatasetBrowser.Version)
                    error('DatasetBrowser:BadResultFile', 'not a dataset-browser result file (schema "%s")', DatasetBrowser.Schema);
                end
            catch ME
                warning('DatasetBrowser:BadResultFile', 'Cannot restore from %s (%s): the defaults are used.', file, ME.message);
                return
            end
            s = L.browser;
            if isfield(s, 'namePattern') && string(s.namePattern) ~= ""; B.NamePattern = string(s.namePattern); end
            if isfield(s, 'outputRoot'); B.OutputRoot = string(s.outputRoot); end
            if isfield(s, 'recordings') && string(s.recordings) ~= ""; B.Recordings = string(s.recordings); end
            if takeRoot && B.Root == "" && isfield(s, 'root'); B.Root = string(s.root); end
            if isfield(s, 'ticked')
                B.SelectedKeys = unique(reshape(string(s.ticked), [], 1), 'stable');
                B.HasTicks = true;
            end
            if isfield(s, 'filter')
                try
                    B.FilterS = DatasetBrowser.checkFilter(s.filter, DatasetBrowser.noFilter());
                catch ME
                    warning('DatasetBrowser:BadResultFile', '%s: the filter is not used (%s).', file, ME.message);
                end
            end
            if isfield(s, 'settings')
                try
                    [S, ID, name] = epochMatrixSettings(s.settings);
                    B.takeSettings(S, ID, name);
                    if isfield(s, 'settingsFile'); B.SettingsFile = string(s.settingsFile); end
                catch ME
                    warning('DatasetBrowser:BadResultFile', '%s: the settings are not used (%s).', file, ME.message);
                end
            end
            if isfield(L, 'runs')
                try
                    B.Runs = DatasetRuns.fromStruct(L.runs);
                catch ME
                    warning('DatasetBrowser:BadResultFile', '%s: the kept parts are not used (%s).', file, ME.message);
                end
            end
            if isfield(L, 'result') && ~isempty(L.result)
                R = L.result;
                if isstruct(R) && isscalar(R) && all(isfield(R, {'data', 'rows', 't', 'groupLabels', 'settings', 'datasets', 'keys'}))
                    try
                        R.labels = epochMatrixLabels(R);
                    catch ME
                        warning('DatasetBrowser:BadResultFile', '%s: the result has no labels (%s).', file, ME.message);
                    end
                    R = B.restoreEpochs(R, file);
                    B.setResult(R);
                else
                    warning('DatasetBrowser:BadResultFile', '%s: the result is not used (it lacks fields).', file);
                end
            end
            if file == B.ResultFileS; B.SavedSig = B.stateSig(); end
        end

        function R = restoreEpochs(B, R, file)
            %restoreEpochs  R.epochs again from the kept parts (save leaves them out of the result, as the parts hold them).
            %   The parts of R's datasets are assembled again (epochMatrix's
            %   assembly only) for their epochs. When a part is missing or of
            %   other settings, R.epochs stays [] with a warning.
            if ~isfield(R, 'epochs'); R.epochs = []; end
            if ~isempty(R.epochs) || ~(isfield(R.settings, 'keepEpochs') && isequal(R.settings.keepEpochs, true)); return; end
            try
                [S, ID, name] = epochMatrixSettings(R.settings);
                keys = string(R.datasets.key(ismember(R.datasets.key, R.keys)));
                st = B.Runs.status(name, keys, ID);
                if ~all(st == "current")
                    error('DatasetBrowser:BadResultFile', 'the kept parts of %d dataset(s) are missing or of other settings', nnz(st ~= "current"));
                end
                parts = cell(numel(keys), 1);
                for k = 1:numel(keys)
                    parts{k} = B.Runs.value(name, keys(k));
                    parts{k}.key = keys(k);
                end
                info = R.datasets(ismember(R.datasets.key, keys), {'key', 'name', 'subject', 'date'});
                A = epochMatrix(parts, S, Info=info);
                if height(A.rows) ~= height(R.rows)
                    error('DatasetBrowser:BadResultFile', 'the kept parts give %d rows, the result %d', height(A.rows), height(R.rows));
                end
                R.epochs = A.epochs;
            catch ME
                warning('DatasetBrowser:BadResultFile', '%s: the result''s epochs are not restored (%s); Compute again for them.', ...
                    file, ME.message);
            end
        end

        function s = browserState(B)
            s = struct('root', B.Root, 'outputRoot', B.OutputRoot, 'namePattern', B.NamePattern, ...
                'recordings', B.Recordings, 'ticked', B.SelectedKeys, 'filter', B.FilterS, 'settings', B.SettingsS, ...
                'settingsFile', B.SettingsFile);
        end

        function sig = stateSig(B)
            %stateSig  The text of what the result file holds, to tell whether it changed.
            E = B.Runs.Entries;
            stamp = "";
            if ~isempty(E); stamp = string(max([E.created]), 'yyyy-MM-dd HH:mm:ss.SSS'); end
            created = "";
            if ~isempty(B.Result) && isfield(B.Result, 'created'); created = string(B.Result.created, 'yyyy-MM-dd HH:mm:ss.SSS'); end
            s = B.browserState();
            s.runs = sprintf('%d %s', numel(E), stamp);
            s.result = created;
            sig = DatasetRuns.idText(s);
        end

        function saveIfChanged(B)
            if B.ResultFileS == "" || ~B.HasTicks; return; end
            if B.stateSig() ~= B.SavedSig; B.save(); end
        end

        function afterRun(B, t0)
            %afterRun  After a compute or forEach: the table's Cached column; the result file when parts were added.
            E = B.Runs.Entries;
            if ~isempty(E) && any([E.created] >= t0)
                B.save();
            end
            B.refreshTable();
            B.refreshSummary();
        end

        function tookFile(B, file)
            %tookFile  FILE was loaded or saved: SettingsFile, its folder, the top of RecentSettings.
            [ok, a] = fileattrib(file);
            if ok; file = string(a.Name); end   % the full path of a relative one
            B.SettingsFile = file;
            B.SettingsFolder = string(fileparts(file));
            r = B.RecentSettings;
            r = [file; r(lower(r) ~= lower(file))];
            B.RecentSettings = r(1:min(B.MaxRecent, end));
            B.refreshFileMenu();
        end

        function setOnTopFrom(B, tf)
            B.OnTop = logical(tf);
        end

        function savePrefs(B)
            g = DatasetBrowser.PrefGroup;
            try
                AppPrefs.setpref(g, "Root", char(B.Root));
                AppPrefs.setpref(g, "NamePattern", char(B.NamePattern));
                AppPrefs.setpref(g, "Sort", TableSort.toPref(B.Sort));
                AppPrefs.setpref(g, "SettingsFolder", char(B.SettingsFolder));
                AppPrefs.setpref(g, "RecentSettings", cellstr(B.RecentSettings));
                AppPrefs.setpref(g, "Workers", B.WorkersN);
                AppPrefs.setpref(g, "OnTop", B.OnTopS);
                if B.uiOk(); AppPrefs.setpref(g, "Position", B.Fig.Position); end
            catch
                % preferences are a convenience
            end
        end

        % --- the progress strip's parts ------------------------------------------------------------------
        function setBar(B, f)
            %setBar  The bar: two weighted columns (setRunBar's drawing).
            w = round(1000 * min(max(f, 0), 1));
            if w <= 0
                B.Ctl.Bar.ColumnWidth = {0, '1x'};
            elseif w >= 1000
                B.Ctl.Bar.ColumnWidth = {'1x', 0};
            else
                B.Ctl.Bar.ColumnWidth = {sprintf('%dx', w), sprintf('%dx', 1000 - w)};
            end
        end

        function setBusyUI(B, tf)
            c = B.Ctl;
            for name = B.Controls
                if isfield(c, name) && isvalid(c.(name)); c.(name).Enable = ternary(tf, 'off', 'on'); end   % a uitable takes text only
            end
            for h = struct2cell(c.Align).'
                if isprop(h{1}, 'Enable'); h{1}.Enable = ternary(tf, 'off', 'on'); end
            end
            c.Cancel.Enable = matlab.lang.OnOffSwitchState(tf);
            if ~tf; B.applyEnable(); end
        end

        function finishRun(B, message, full)
            %finishRun  End the strip's run: FULL fills the bar; the time taken; Busy off.
            el = 0;
            if ~isempty(B.RunStart); el = toc(B.RunStart); end
            timeText = "done in " + ProgressClock.durationText(el);
            B.Busy = false;
            behind = B.Splash.isOpen();
            if B.uiOk()
                if full; B.setBar(1); end
                B.Ctl.ProgMsg.Text = message;
                B.Ctl.ProgTime.Text = timeText;
                if ~behind   % the splash left the controls as built
                    B.setBusyUI(false);
                    drawnow limitrate
                end
            end
            if B.headless() && ~behind
                fprintf('%s: %s (%s)\n', B.RunTitle, message, timeText);
            end
        end

        function endRun(B, message)
            %endRun  A run that ends early (an error, a cancel): its bar stays, Busy off.
            if isvalid(B) && B.Busy; B.finishRun(string(message), false); end
        end

        function c = beginOwnRun(B)
            %beginOwnRun  Mark the strip's run as the browser's own until C is cleared (scan, compute, forEach).
            prev = B.OwnRun;
            B.OwnRun = true;
            c = onCleanup(@() B.endOwnRun(prev));
        end

        function endOwnRun(B, prev)
            if isvalid(B); B.OwnRun = prev; end
        end

        function s = stampOf(B, key)
            %stampOf  The stamp of dataset KEY's outputs at the last scan ("" for a key not listed).
            s = "";
            k = find(B.Datasets.key == string(key), 1);
            if ~isempty(k); s = B.Datasets.stamp(k); end
        end

        function scanProgress(B, f, m)
            B.progress(f, m);
            if B.CancelRequested
                error('EphysAnalysisRunner:Canceled', 'The scan was canceled.');
            end
        end

        function D = readDatasets(B, r)
            %readDatasets  One row per dataset of the runner: which outputs it has, its subject, day, tags and outputs' stamp.
            %   Subject and day come from runnerIdentity, as epochMatrix's R.rows.
            n = numel(r.Keys);
            names = reshape(r.Names, [], 1);
            keys = reshape(r.Keys, [], 1);
            [subject, date] = runnerIdentity(r, keys);
            [units, detected, behavior] = deal(false(n, 1));
            signals = strings(n, 1);
            tagSet = cell(n, 1);
            tags = strings(n, 1);
            stamp = strings(n, 1);
            for k = 1:n
                B.progress(0.5 + 0.5 * (k - 1) / max(n, 1), sprintf("Reading %d/%d: %s", k, n, names(k)));
                B.checkCancel();
                out = r.Outputs(k);
                [stamp(k), units(k)] = outputsStamp(out);   % its listing of the sorting folder is has("sorting")
                detected(k) = out.has("spikes");
                behavior(k) = out.has("behavior");
                t = DatasetOutputs.SignalTypes;
                hasSig = arrayfun(@(s) out.has(s), t);
                signals(k) = strjoin(t(hasSig), " ");
                tagSet{k} = outputTags(out);
                tags(k) = TagSet.toText(tagSet{k}, TagSet.ExportDelimiter);
            end
            session = sessionNumbers(subject, date);
            D = table(keys, names, subject, date, session, tags, tagSet, units, detected, behavior, signals, stamp, ...
                'VariableNames', {'key', 'name', 'subject', 'date', 'session', 'tags', 'tagSet', 'units', 'detected', ...
                'behavior', 'signals', 'stamp'});
        end

        % --- helpers ----------------------------------------------------------------------------------------
        function keep = filterKeep(B, D)
            if height(D) == 0; keep = false(0, 1); return; end
            f = B.FilterS;
            text = D.name + " " + D.key + " " + D.subject + " " + D.tags;
            keep = datasetFilter(D.subject, reshape(D.tagSet, [], 1), Subjects=f.Subjects, ExcludeSubjects=f.ExcludeSubjects, ...
                Tags=f.Tags, TagMode=f.TagMode, ExcludeTags=f.ExcludeTags, Search=f.Search, Text=text);
        end

        function keys = keysOf(B, keys)
            %keysOf  Dataset keys of KEYS (keys, names or indices of Datasets); unknown ones raise UnknownDataset once scanned.
            D = B.Datasets;
            if isnumeric(keys)
                if any(keys < 1 | keys > height(D) | keys ~= round(keys))
                    error('DatasetBrowser:UnknownDataset', 'Dataset index out of range 1..%d.', height(D));
                end
                keys = D.key(keys(:));
                return
            end
            keys = reshape(string(keys), [], 1);
            if height(D) == 0; return; end
            for j = 1:numel(keys)
                if any(D.key == keys(j)); continue; end
                k = find(D.name == keys(j), 1);
                if isempty(k)
                    error('DatasetBrowser:UnknownDataset', 'No dataset "%s".', keys(j));
                end
                keys(j) = D.key(k);
            end
        end

        function keys = tickedKeys(B)
            keys = B.Datasets.key(ismember(B.Datasets.key, B.SelectedKeys));
        end

        function I = info(B, keys)
            [~, loc] = ismember(keys, B.Datasets.key);
            I = B.Datasets(loc(loc > 0), {'key', 'name', 'subject', 'date', 'tags'});
        end

        function key = listKey(B)
            key = "";
            D = B.Datasets;
            if isempty(B.Runner) || height(D) == 0; return; end
            if B.ListKey ~= "" && any(D.key == B.ListKey)
                key = B.ListKey;
            elseif ~isempty(B.tickedKeys())
                k = B.tickedKeys();
                key = k(1);
            else
                key = D.key(1);
            end
        end

        function needRunner(B)
            if isempty(B.Runner)
                error('DatasetBrowser:NotScanned', 'Scan the root first (B.scan()).');
            end
        end

        function file = pickFile(B, how)
            file = "";
            if ~B.uiOk() || B.Fig.Visible ~= "on"
                error('DatasetBrowser:NoFile', 'Pass the settings file.');
            end
            start0 = B.SettingsFolder;
            if start0 == "" || ~isfolder(start0); start0 = B.Root; end
            if start0 == "" || ~isfolder(start0); start0 = string(pwd); end
            if how == "get"
                [f, p] = uigetfile({'*.json', 'Settings (*.json)'}, "Load settings", char(start0));
            else
                name = "settings.json";
                if B.SettingsFile ~= ""; [~, n, e] = fileparts(B.SettingsFile); name = n + e; end
                [f, p] = uiputfile({'*.json', 'Settings (*.json)'}, "Save settings as", char(fullfile(start0, name)));
            end
            if B.uiOk(); figure(B.Fig); end
            if isequal(f, 0); return; end
            file = string(fullfile(p, f));
        end

        function tf = uiOk(B)
            tf = ~isempty(B.Fig) && isvalid(B.Fig);
        end

        function tf = headless(B)
            tf = ~B.uiOk() || B.Fig.Visible ~= "on";
        end

        function setStatus(B, text, isError)
            if nargin < 3; isError = false; end
            if ~B.uiOk(); return; end
            B.Ctl.Status.Text = string(text);
            B.Ctl.Status.FontColor = ternary(isError, B.ErrorColor, B.TextColor);
        end

        function say(B, msg)
            %say  epochMatrix's line per dataset: the status line.
            B.setStatus(string(msg));
        end

        % --- the event, window and trial-selection controls (AlignControls) -----------------------
        function onAlignEdit(B)
            %onAlignEdit  The event, window and selection the controls show into the settings, checked; undone when they do not fit.
            try
                S = B.SettingsS;
                [S.ref, S.window, S.selection] = AlignControls.read(B.Ctl.Align, S.ref, S.window, S.selection);
                B.setSettings(S, true);
                B.setStatus("");
            catch ME
                B.refreshForm();
                B.setStatus("Not applied: " + string(ME.message), true);
            end
        end

        function editSequence(B, holder, lineCtl, edgeCtl, done)
            %editSequence  The Event sequence window on HOLDER's steps, its lines from one dataset (fillLists).
            B.fillLists();
            B.closeSequenceDialog();
            B.SequenceDialog = AlignControls.editSequence(holder, lineCtl, edgeCtl, done);
        end

        function showFilterHelp(B)
            %showFilterHelp  What a trial filter can use, with the trial columns of the lists' dataset.
            src = [];
            key = B.listKey();
            if key ~= ""
                try
                    src = B.source(key);
                catch
                end
            end
            uialert(B.Fig, AlignControls.filterHelpText(src), "Trial filter", "Icon", "info");
        end

        function refreshEpochs(B)
            %refreshEpochs  Redraw the Epoch Diagram window, when open, with the settings and the lists' dataset.
            d = B.EpochWindow;
            if isempty(d) || ~isvalid(d) || ~d.isOpen(); return; end
            key = B.listKey();
            if key == ""; return; end
            try
                src = B.source(key);
            catch ME
                B.setStatus("Cannot read " + key + " for the epoch diagram: " + string(ME.message), true);
                return
            end
            S = B.SettingsS;
            d.update(src, S.ref, S.window, S.selection, Title=src.name);
        end

        function closeSequenceDialog(B)
            if ~isempty(B.SequenceDialog) && isvalid(B.SequenceDialog); delete(B.SequenceDialog); end
            B.SequenceDialog = [];
        end

        function closeWindows(B)
            %closeWindows  The Event sequence and Epoch Diagram windows go.
            B.closeSequenceDialog();
            d = B.EpochWindow;
            if ~isempty(d) && isvalid(d); d.close(); end
            B.EpochWindow = [];
        end

        function changed(B, what)
            if isempty(B.OnChange); return; end
            try
                B.OnChange(B, string(what));
            catch ME
                warning('DatasetBrowser:OnChange', 'OnChange(%s) failed: %s', what, ME.message);
            end
        end
    end

    methods (Static, Access = private)
        function D = emptyDatasets()
            D = table(strings(0, 1), strings(0, 1), strings(0, 1), NaT(0, 1), zeros(0, 1), strings(0, 1), cell(0, 1), ...
                false(0, 1), false(0, 1), false(0, 1), strings(0, 1), strings(0, 1), 'VariableNames', ...
                {'key', 'name', 'subject', 'date', 'session', 'tags', 'tagSet', 'units', 'detected', 'behavior', ...
                'signals', 'stamp'});
        end

        function f = noFilter()
            f = struct('Subjects', "", 'ExcludeSubjects', "", 'Tags', "", 'TagMode', "any", 'ExcludeTags', "", 'Search', "");
        end

        function f = checkFilter(in, f)
            %checkFilter  F with the terms of IN (a struct of setFilter's options) put in, as text.
            if ~(isstruct(in) && isscalar(in))
                error('DatasetBrowser:BadFilter', 'A filter is a struct of Subjects, ExcludeSubjects, Tags, TagMode, ExcludeTags and Search.');
            end
            names = string(fieldnames(DatasetBrowser.noFilter())).';
            bad = setdiff(string(fieldnames(in)).', names);
            if ~isempty(bad)
                error('DatasetBrowser:BadFilter', 'Unknown filter field(s): %s.', strjoin(bad, ", "));
            end
            for n = string(fieldnames(in)).'
                v = in.(n);
                if isempty(v); v = ""; end
                v = strjoin(reshape(string(v), 1, []), ", ");
                v = strtrim(v);
                if v == "(any)"; v = ""; end
                if n == "TagMode"
                    v = lower(v);
                    if v == ""; v = "any"; end
                    if ~ismember(v, ["any" "all"])
                        error('DatasetBrowser:BadFilter', 'TagMode must be "any" or "all" (got "%s").', v);
                    end
                end
                f.(n) = v;
            end
        end

        function file = defaultFile(root)
            file = "";
            if root ~= ""; file = string(fullfile(root, "DatasetBrowser_results.mat")); end
        end

        function tf = sameRoot(a, b)
            %sameRoot  A and B name one folder: / or \, a trailing separator and (on Windows) case ignored.
            a = regexprep(strrep(strtrim(string(a)), "/", "\"), "\\+$", "");
            b = regexprep(strrep(strtrim(string(b)), "/", "\"), "\\+$", "");
            if ispc; a = lower(a); b = lower(b); end
            tf = a == b;
        end

        function n = openPoolWorkers()
            %openPoolWorkers  Workers of the open process pool (0 when none is open or the toolbox is missing).
            n = 0;
            try
                if ~isempty(ver('parallel')) && license('test', 'Distrib_Computing_Toolbox')
                    p = gcp('nocreate');
                    if isa(p, 'parallel.ProcessPool'); n = p.NumWorkers; end
                end
            catch
            end
        end

        function p = readPrefs()
            p = struct();
            try
                p = AppPrefs.getpref(DatasetBrowser.PrefGroup);
            catch
            end
            if ~isstruct(p); p = struct(); end
        end
    end
end


function [steps, weights] = startupSteps()
%startupSteps  The constructor's steps on the splash (AppSplash) and the seconds each takes (measured warm).
%   "scan" is the root's scan (its progress fills the step); "show" is the
%   hidden window's first draw, the longest part.
S = { ...
    "settings", 0.2; "window", 2.3; "restore", 0.2; "scan", 3.0; "show", 6.0};
steps = [S{:, 1}];
weights = [S{:, 2}];
end


function r = row(parent, widths)
%row  A one-row grid of WIDTHS in the next row of PARENT.
r = uigridlayout(parent, [1 numel(widths)], "ColumnWidth", widths, "RowHeight", {'1x'}, "Padding", [0 0 0 0], "ColumnSpacing", 6);
end


function h = place(h, r, c)
%place  Put H in row R, column(s) C of its grid.
h.Layout.Row = r;
h.Layout.Column = c;
end


function syncItems(dd, inUse)
%syncItems  A filter drop-down lists '(any)' and the values IN USE; its value (picked or typed) stays.
v = dd.Value;
dd.Items = [{'(any)'}, cellstr(reshape(string(inUse), 1, []))];
dd.Value = v;
end


function setDrop(dd, text)
%setDrop  A filter drop-down's value: TEXT, or '(any)' when blank.
if text == ""; text = "(any)"; end
dd.Value = char(text);
end


function v = parseNumbers(txt, name)
%parseNumbers  Numbers typed as "1:4", "1 3", "[-1 -0.5]", "1, 2" (blank = []); never eval.
t = strtrim(string(txt));
v = [];   % blank: [] (= all / none), as a settings file gives it back
if t == ""; return; end
v = zeros(1, 0);
t = regexprep(t, '[\[\]\(\)]', ' ');
t = regexprep(t, '[,;]', ' ');
t = regexprep(t, '\s*:\s*', ':');
parts = split(strtrim(t));
for p = reshape(parts(parts ~= ""), 1, [])
    q = split(p, ":");
    x = str2double(q);
    if any(isnan(x)) || numel(q) > 3
        error('DatasetBrowser:BadValue', '%s: "%s" is not a number or a range a:b.', name, p);
    end
    switch numel(q)
        case 1; v = [v x]; %#ok<AGROW>
        case 2; v = [v x(1):x(2)]; %#ok<AGROW>
        case 3; v = [v x(1):x(2):x(3)]; %#ok<AGROW>
    end
end
end


function s = numbersText(v)
%numbersText  Numbers as the form shows them: "1:4" for a run of 3 or more whole numbers, else "1 3".
v = reshape(double(v), 1, []);
if isempty(v); s = ""; return; end
if numel(v) > 2 && all(v == round(v)) && all(diff(v) == 1)
    s = sprintf("%g:%g", v(1), v(end));
else
    s = strjoin(compose("%g", v), " ");
end
end


function tf = sameNormalize(a, b)
%sameNormalize  Settings A and B normalize alike (A from a result that may predate normalize).
tf = isfield(a, 'normalize') && isequal(a.normalize, b.normalize);
end


function s = sessionNumbers(subject, date)
%sessionNumbers  Per subject, 1, 2, ... for each recording day in order (NaN for NaT).
s = NaN(numel(subject), 1);
subject = string(subject);
for sub = unique(subject).'
    m = subject == sub & ~isnat(date);
    if ~any(m); continue; end
    [~, ~, r] = unique(date(m));
    s(m) = r;
end
end


function v = ternary(c, a, b)
if c; v = a; else; v = b; end
end
