classdef EphysAnalysisRunner < handle
    % EphysAnalysisRunner  Draw, export and report an analysis config's figures.
    %   r = EphysAnalysisRunner(cfg) finds the config's datasets (an
    %   EphysProject's recordings, or a list of output folders) and runs its
    %   figures over them. It has no GUI: EphysAnalysisApp drives one for its
    %   previews and runs, and EphysAnalysisScript writes out the same steps
    %   as a script.
    %
    %     r = EphysAnalysisRunner(EphysAnalysisConfig.load("am.json"));
    %     disp(r.plan());          % dataset x figure, and why a figure is skipped
    %     R = r.run();             % compute, render, export, report
    %
    %   A figure (Config.Figures; one observation's panels) is drawn once
    %   per observation, a page each; run draws the enabled figures on each
    %   dataset (runDataset, Figures=), and plan lists them. One figure on
    %   one dataset is always the same sequence of public calls:
    %     src = loadAnalysisSource(out)
    %     spec = cfg.figureFor(id)
    %     [reason, layerReasons] = figureSkipReason(src, spec)
    %     T = figureObservations(src, spec)          (its units, channels, or the dataset)
    %     per observation, one at a time:
    %       F = r.computeFigure(src, spec, Observation=T(i,:))   (figureCompute)
    %       fig = newExportFigure(cfg.Export, F, spec); h = renderFigure(F, spec, fig)
    %       exportFigure(fig, <folder>/<figureOutputName(...)>, Format=, Dpi=)
    %       reportImage(fig, report, Title=h.title, Files=)   (HTML report)
    %       reportPdfPage(fig, report, Files=)                (PDF report)
    %     addReportFigure(report, spec, F, Files=, Images=, Pages=, Caption=figureCaption(spec, T, Auroc=<figureAurocCalls of each F>))
    %   and then writeHtmlReport / writePdfReport. computeFigure reads only
    %   the observation's data (one unit's spike train, one extract column)
    %   where a layer follows it, and stops at its checkpoints while PollFcn
    %   is set. Figures= and SessionFigures= of run and plan (Figures= of
    %   runDataset): [] (the default) = the enabled ones (plan: all of
    %   them), string.empty(1, 0) = none, else the ids (idList).
    %
    %   Properties
    %     Config        the EphysAnalysisConfig
    %     ProgressFcn   ProgressFcn(fraction, message), called before each
    %                   dataset, figure and observation; FRACTION is how far
    %                   the whole run is (dataset j of n spans [(j-1)/n,
    %                   j/n], its figures share it). cancel() makes the next
    %                   call throw EphysAnalysisRunner:Canceled
    %     PollFcn       PollFcn() called at computeFigure's checkpoints
    %                   (between its panels and inside the long ones); the
    %                   app's preview sets it to let a Cancel button act
    %                   while a figure computes. cancel() then makes the
    %                   next checkpoint throw EphysAnalysisRunner:Canceled.
    %                   While it is empty (a run, a script) there are no
    %                   checkpoints
    %     LogFcn        LogFcn(message) per line (default: print); [] = quiet
    %     SearchDirs    further folders each dataset's outputs are searched in
    %                   (DatasetOutputs SearchDirs), e.g. a pipeline's
    %                   Signals / Spikes OutputDir; set before datasets()
    %     Outputs       DatasetOutputs per dataset (CacheData=true)
    %     Keys, Names   dataset keys (root-relative, or the folder) and names
    %     Sources       containers.Map key -> loadAnalysisSource struct
    %     Results       last run: Dataset ("sessions: <label>" for a session
    %                   figure), Plot (the figure's id), Kind ("figure"),
    %                   Status (done | skipped | error | canceled), Message,
    %                   Files, Seconds
    %     Report        the last run's report struct (newAnalysisReport)
    %     ReportFiles   the report files the last run wrote
    %     RunRecordFile the run record the last run wrote: the config, the code
    %                   version, MATLAB, host, user and the Results rows, in
    %                   <report folder>/analysis_runs (see run)
    %     BatchYLim     the last run's shared y ranges: a struct row (figure,
    %                   id, lim, n) per panel with options.yLimMode "batch"
    %                   (batchYLimits: lim the union of the y extents of the
    %                   run's every observation of that figure, n how many;
    %                   a session figure's over its matched observations)
    %
    %   A figure with a panel whose options.yLimMode is "batch" is measured
    %   first: run() computes and draws (hidden) every observation of the
    %   run on every dataset (batchYLimits: figureYExtents, figureBatchYLim)
    %   and then draws each page at the union (renderFigure BatchYLim=), so
    %   every observation of the run is on one scale; a figure computed
    %   while measuring is kept for its page while the kept ones stay under
    %   BatchCacheMB, else computed again. runDataset alone measures its own
    %   dataset.
    %
    %   Session figures (a figure whose sessions.enabled is true) are drawn
    %   across the datasets, never per dataset: sessionFigureObservations
    %   matches the observed unit (site or mapping cell), channel or
    %   dataset across them, computeSessionFigure computes one observation
    %   per dataset and merges each layer (figureSessionCompute),
    %   runSessionFigure exports and reports every observation (and, with
    %   Export.Data.Enabled, writes its data file); run does it after the
    %   datasets.
    %
    %   See also EphysAnalysisConfig, EphysAnalysisScript, EphysAnalysisApp.

    properties
        Config EphysAnalysisConfig = EphysAnalysisConfig()
        ProgressFcn = []
        PollFcn = []
        LogFcn = @(msg) fprintf('%s\n', msg)
        SearchDirs (1,:) string = string.empty(1, 0)
    end

    properties (SetAccess = protected)
        CancelRequested (1,1) logical = false
        Outputs = DatasetOutputs.empty(1, 0)
        Keys (1,:) string = string.empty(1, 0)
        Names (1,:) string = string.empty(1, 0)
        Sources = []
        Project = []
        Results table = EphysAnalysisRunner.emptyResults()
        Report = []
        ReportFiles (1,:) string = string.empty(1, 0)
        RunRecordFile (1,1) string = ""   % the run record the last run wrote ("" = none)
        BatchYLim = struct('figure', cell(1, 0), 'id', cell(1, 0), 'lim', cell(1, 0), 'n', cell(1, 0))   % the last run's shared y ranges
    end

    properties (Hidden, SetAccess = protected)
        BatchCache = []                  % containers.Map 'k|figure|i' -> F: figures computed while measuring, for their pages
        BatchCacheUsedMB (1,1) double = 0
    end

    properties (Constant, Hidden)
        BatchCacheMB = 512               % the most computed figures batchYLimits keeps for the drawing pass, MB
    end

    methods
        % --- methods defined in separate files ---
        outs = datasets(obj)
        src = source(obj, k)
        T = plan(obj, opts)
        F = computeFigure(obj, src, spec, opts)
        rows = runDataset(obj, k, opts)
        T = run(obj, opts)
        cancel(obj)
        clearCancel(obj)
        progress(obj, fraction, message)
        checkpoint(obj)
        log(obj, fmt, varargin)
        S = sessionTable(obj, idx)
        idx = sessionFigureIndices(obj, spec, idx)
        [T, sessions, sources] = sessionFigureObservations(obj, fig, idx)
        [res, sessions, spec, Fs] = computeSessionFigure(obj, fig, idx, opts)
        rows = runSessionFigure(obj, id, idx, opts)
        B = batchYLimits(obj, idx, spec, opts)

        function obj = EphysAnalysisRunner(cfg, opts)
            %EphysAnalysisRunner  Find the config's datasets (Scan=false: later, with datasets()).
            arguments
                cfg (1,1) EphysAnalysisConfig = EphysAnalysisConfig()
                opts.ProgressFcn = []
                opts.LogFcn = @(msg) fprintf('%s\n', msg)
                opts.SearchDirs (1,:) string = string.empty(1, 0)
                opts.Scan (1,1) logical = true
            end
            obj.Config = cfg;
            obj.ProgressFcn = opts.ProgressFcn;
            obj.LogFcn = opts.LogFcn;
            obj.SearchDirs = opts.SearchDirs;
            obj.Sources = containers.Map('KeyType', 'char', 'ValueType', 'any');
            if opts.Scan
                obj.datasets();
            end
        end

        function k = index(obj, key)
            %index  Dataset index of a key, a name or an index (0 = none).
            if isnumeric(key)
                k = key;
                if k < 1 || k > numel(obj.Outputs); k = 0; end
                return
            end
            k = find(obj.Keys == string(key), 1);
            if isempty(k); k = find(obj.Names == string(key), 1); end
            if isempty(k); k = 0; end
        end

        function root = outputRoot(obj)
            %outputRoot  The {OutputRoot} token: Source.OutputRoot, else Root,
            %   else the folder above the first dataset's output folder.
            S = obj.Config.Source;
            root = S.OutputRoot;
            if root == ""; root = S.Root; end
            if root == "" && ~isempty(obj.Outputs)
                root = string(fileparts(obj.datasetFolder(1)));
            end
        end

        function f = datasetFolder(obj, k)
            %datasetFolder  The {OutputFolder} token of dataset K: its output folder.
            out = obj.Outputs(k);
            if ~isempty(out.Dataset)
                f = string(out.Dataset.outputFolder());
            else
                f = out.Folder;
            end
        end

        function F = takeBatchFigure(obj, k, id, i)
            %takeBatchFigure  The figure batchYLimits kept for dataset K, figure ID, observation I (and forget it); [] = none.
            F = [];
            key = sprintf('%d|%s|%d', k, id, i);
            if isempty(obj.BatchCache) || ~isKey(obj.BatchCache, key); return; end
            F = obj.BatchCache(key);
            w = whos('F');
            obj.BatchCacheUsedMB = max(0, obj.BatchCacheUsedMB - w.bytes / 2^20);
            remove(obj.BatchCache, key);
        end

        function clearBatchCache(obj, k, id)
            %clearBatchCache  Forget the figures batchYLimits kept: every one, or those of dataset K and figure ID.
            if isempty(obj.BatchCache); return; end
            if nargin < 2
                obj.BatchCache = [];
                obj.BatchCacheUsedMB = 0;
                return
            end
            stale = keys(obj.BatchCache);
            stale = stale(startsWith(stale, sprintf('%d|%s|', k, id)));
            for s = stale
                F = obj.BatchCache(s{1}); %#ok<NASGU>
                w = whos('F');
                obj.BatchCacheUsedMB = max(0, obj.BatchCacheUsedMB - w.bytes / 2^20);
                remove(obj.BatchCache, s{1});
            end
        end

        function clearSources(obj)
            %clearSources  Forget the loaded sources and every dataset's cached data.
            if ~isempty(obj.Sources); remove(obj.Sources, keys(obj.Sources)); end
            for k = 1:numel(obj.Outputs); obj.Outputs(k).clearCache(); end
        end
    end

    methods (Static)
        function ids = idList(sel, all)
            %idList  The ids a Figures= / SessionFigures= option names.
            %   IDS = EphysAnalysisRunner.idList(SEL, ALL): [] (an empty
            %   numeric, the options' default) = ALL() (e.g. the enabled
            %   ones); any empty string (string.empty(1, 0)) = none; else
            %   SEL's ids as a string row ("" dropped).
            if isnumeric(sel) && isempty(sel)
                ids = reshape(string(all()), 1, []);
                return
            end
            ids = reshape(string(sel), 1, []);
            ids = ids(ids ~= "");
        end

        function T = emptyResults()
            T = table(strings(0, 1), strings(0, 1), strings(0, 1), strings(0, 1), strings(0, 1), strings(0, 1), zeros(0, 1), ...
                'VariableNames', {'Dataset', 'Plot', 'Kind', 'Status', 'Message', 'Files', 'Seconds'});
        end

        function files = reportFiles(cfg, tokens)
            %reportFiles  The report file(s) a run writes, for one dataset's folder tokens.
            %   FILES = EphysAnalysisRunner.reportFiles(CFG, TOKENS):
            %   Report.Folder filled with TOKENS (OutputFolder, OutputRoot,
            %   Root, Name; figureFileName Kind "folder"), Report.FileName,
            %   "_<Name>" with Report.PerDataset, then ".html" and / or ".pdf"
            %   as Report.Format says. TOKENS are those of the first dataset
            %   for a report over all of them (run).
            arguments
                cfg (1,1) EphysAnalysisConfig
                tokens (1,1) struct
            end
            P = cfg.Report;
            base = fullfile(figureFileName(P.Folder, tokens, Kind="folder"), P.FileName);
            if P.PerDataset; base = base + "_" + regexprep(tokens.Name, '[^\w\-\.]', '_'); end
            files = string.empty(1, 0);
            if ismember(P.Format, ["html" "both"]); files(end+1) = base + ".html"; end
            if ismember(P.Format, ["pdf" "both"]); files(end+1) = base + ".pdf"; end
        end

        function f = sessionOutputName(pattern, spec, row, facet, group, i, n)
            %sessionOutputName  The file name (no extension) of a session figure's observation.
            %   F = EphysAnalysisRunner.sessionOutputName(PATTERN, SPEC, ROW,
            %   FACET, GROUP, I, N): figureOutputName for observation I of N
            %   (ROW, a row of sessionFigureObservations' table) of the
            %   session figure SPEC, {Name} the FACET's label and {Group}
            %   GROUP. Its {Unit}: "site_ch<N>" (units matched by site), the
            %   mapping's cell, "ch<N>" or "dataset". runSessionFigure adds
            %   "_2", "_3", ... when two observations' names meet.
            switch string(row.kind)
                case "unit"
                    if spec.sessions.match == "mapping"
                        unit = string(row.label);
                    else
                        unit = "site_ch" + row.channel;
                    end
                case "channel"
                    unit = "ch" + row.channel;
                    if ~isfinite(row.channel); unit = string(row.label); end
                otherwise
                    unit = "dataset";
            end
            obs = struct('kind', row.kind, 'label', row.label, 'unitId', NaN, 'channel', row.channel, 'column', row.column, ...
                'meta', table(unit, "", 'VariableNames', {'label', 'class'}), 'groupLabel', group);
            f = figureOutputName(pattern, facet, spec, obs, i, n);
        end
    end
end
