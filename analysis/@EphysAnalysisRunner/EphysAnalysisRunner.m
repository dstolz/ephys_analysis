classdef EphysAnalysisRunner < handle
    % EphysAnalysisRunner  Draw, export and report an analysis config's plots.
    %   r = EphysAnalysisRunner(cfg) finds the config's datasets (an
    %   EphysProject's recordings, or a list of output folders) and runs its
    %   plots over them. It has no GUI: EphysAnalysisApp drives one for its
    %   previews and runs, and EphysAnalysisScript writes out the same steps
    %   as a script.
    %
    %     r = EphysAnalysisRunner(EphysAnalysisConfig.load("am.json"));
    %     disp(r.plan());          % dataset x plot, and why a plot is skipped
    %     R = r.run();             % compute, render, export, report
    %
    %   One plot on one dataset is always the same sequence of public calls
    %   (see computePlot, runDataset):
    %     src = loadAnalysisSource(out)
    %     [E, G] = epochTable(src, spec.ref, Window=, Selection=, Baseline=)
    %     [st, meta] = selectUnits(src, spec.units, Ref=, Selection=)   (or selectChannels)
    %     R = spikePSTH / evokedPotential / firingRate (+ tuningCurve) /
    %         unitSummary + probeMapValues
    %     per page, one at a time:
    %       fig = newExportFigure(cfg.Export, R, spec, Page=p); h = renderPlot(R, spec, fig, Page=p)
    %       exportFigure(fig, <folder>/<plotFileName(...)>, Format=, Dpi=)
    %       reportImage(fig, report, Title=h.title, Files=)   (HTML report)
    %       reportPdfPage(fig, report, Files=)                (PDF report)
    %     addReportFigure(report, spec, R, Files=, Images=, Pages=)
    %   and then writeHtmlReport / writePdfReport. The app previews a page
    %   with renderPlotFigures.
    %
    %   Properties
    %     Config        the EphysAnalysisConfig
    %     ProgressFcn   ProgressFcn(fraction, message), called before each
    %                   dataset and plot; FRACTION is how far the whole run
    %                   is (dataset j of n spans [(j-1)/n, j/n], its plots
    %                   share it). cancel() makes the next call throw
    %                   EphysAnalysisRunner:Canceled
    %     PollFcn       PollFcn() called at computePlot's checkpoints (between
    %                   its stages and per unit, epoch or channel inside the
    %                   long ones); the app's preview sets it to let a Cancel
    %                   button act while a plot computes. cancel() then makes
    %                   the next checkpoint throw EphysAnalysisRunner:Canceled.
    %                   While it is empty (a run, a script) there are no
    %                   checkpoints
    %     LogFcn        LogFcn(message) per line (default: print); [] = quiet
    %     SearchDirs    further folders each dataset's outputs are searched in
    %                   (DatasetOutputs SearchDirs), e.g. a pipeline's
    %                   Signals / Spikes OutputDir; set before datasets()
    %     Outputs       DatasetOutputs per dataset (CacheData=true)
    %     Keys, Names   dataset keys (root-relative, or the folder) and names
    %     Sources       containers.Map key -> loadAnalysisSource struct
    %     Results       last run: Dataset, Plot, Kind, Status (done |
    %                   skipped | error | canceled), Message, Files, Seconds
    %     Report        the last run's report struct (newAnalysisReport)
    %     ReportFiles   the report files the last run wrote
    %     RunRecordFile the run record the last run wrote: the config, the code
    %                   version, MATLAB, host, user and the Results rows, in
    %                   <report folder>/analysis_runs (see run)
    %
    %   Session plots (Config.SessionPlots) draw a base plot over several
    %   datasets: computeSessionPlot computes the base plot on each dataset
    %   (cachedPlot) and merges the results (sessionResults,
    %   combineSessions); runSessionPlot exports and reports them; run does
    %   both after its datasets. sessionData gathers a session plot's data
    %   (the merged and per-session results, the epoched spikes or signals)
    %   into one struct for writeAnalysisData or the workspace; run writes it
    %   with Export.Data.Enabled. The per-dataset results a session plot
    %   needs are kept in a cache:
    %     ResultCache   containers.Map cacheKey -> struct(R, bytes)
    %     CacheMaxMB    its size limit (default 512); the oldest entries go
    %                   first when it is passed
    %     CacheBytes    its size now
    %     CacheWanted   the keys runDataset puts in the cache as it computes
    %                   them (run sets them: the enabled session plots' keys
    %                   of every dataset it runs), so a session plot reuses
    %                   the per-dataset run's results
    %
    %   See also EphysAnalysisConfig, EphysAnalysisScript, EphysAnalysisApp.

    properties
        Config EphysAnalysisConfig = EphysAnalysisConfig()
        ProgressFcn = []
        PollFcn = []
        LogFcn = @(msg) fprintf('%s\n', msg)
        SearchDirs (1,:) string = string.empty(1, 0)
        CacheMaxMB (1,1) double {mustBeNonnegative} = 512
        CacheWanted (1,:) string = string.empty(1, 0)
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
        ResultCache = []                  % containers.Map: cacheKey -> struct('R', R, 'bytes', n)
        CacheBytes (1,1) double = 0       % the bytes ResultCache holds
    end

    properties (Hidden, SetAccess = protected)
        CacheOrder (1,:) string = string.empty(1, 0)   % ResultCache's keys, oldest first
    end

    methods
        % --- methods defined in separate files ---
        outs = datasets(obj)
        src = source(obj, k)
        T = plan(obj, opts)
        [R, E, G] = computePlot(obj, src, spec, opts)
        h = renderPlotFigures(obj, R, spec, opts)
        rows = runDataset(obj, k, opts)
        T = run(obj, opts)
        cancel(obj)
        clearCancel(obj)
        progress(obj, fraction, message)
        checkpoint(obj)
        log(obj, fmt, varargin)
        S = sessionTable(obj, idx)
        R = cachedPlot(obj, k, spec, opts)
        cachePut(obj, key, R)
        clearResultCache(obj)
        [res, sessions, spec, Rs] = computeSessionPlot(obj, sp, idx, opts)
        rows = runSessionPlot(obj, sp, idx, opts)
        S = sessionData(obj, sp, idx, opts)

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
            obj.ResultCache = containers.Map('KeyType', 'char', 'ValueType', 'any');
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

        function clearSources(obj)
            %clearSources  Forget the loaded sources, every dataset's cached data and the cached results.
            if ~isempty(obj.Sources); remove(obj.Sources, keys(obj.Sources)); end
            for k = 1:numel(obj.Outputs); obj.Outputs(k).clearCache(); end
            if ~isempty(obj.ResultCache); obj.clearResultCache(); end
        end
    end

    methods (Static)
        % --- methods defined in separate files ---
        key = cacheKey(datasetKey, spec)

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
    end
end
