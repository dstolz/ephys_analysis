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
    %   (see computePlot, renderPlotFigures, runDataset):
    %     src = loadAnalysisSource(out)
    %     [E, G] = epochTable(src, spec.ref, Window=, Selection=)
    %     [st, meta] = selectUnits(src, spec.units)      (or selectChannels)
    %     R = spikePSTH / evokedPotential / firingRate (+ tuningCurve) /
    %         unitSummary + probeMapValues
    %     fig = newExportFigure(cfg.Export); renderPlot(R, spec, fig, Page=p)
    %     exportFigure(fig, <folder>/<figureFileName(...)>, Format=, Dpi=)
    %     addReportFigure(report, spec, R, Files=)
    %   and then writeHtmlReport / writePdfReport.
    %
    %   Properties
    %     Config        the EphysAnalysisConfig
    %     ProgressFcn   ProgressFcn(fraction, message), called before each
    %                   plot; cancel() makes the next call throw
    %                   EphysAnalysisRunner:Cancelled
    %     LogFcn        LogFcn(message) per line (default: print); [] = quiet
    %     Outputs       DatasetOutputs per dataset (CacheData=true)
    %     Keys, Names   dataset keys (root-relative, or the folder) and names
    %     Sources       containers.Map key -> loadAnalysisSource struct
    %     Results       last run: Dataset, Plot, Kind, Status (done |
    %                   skipped | error | cancelled), Message, Files, Seconds
    %     Report        the last run's report struct (newAnalysisReport)
    %     ReportFiles   the report files the last run wrote
    %
    %   See also EphysAnalysisConfig, EphysAnalysisScript, EphysAnalysisApp.

    properties
        Config EphysAnalysisConfig = EphysAnalysisConfig()
        ProgressFcn = []
        LogFcn = @(msg) fprintf('%s\n', msg)
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
    end

    methods
        % --- methods defined in separate files ---
        outs = datasets(obj)
        src = source(obj, k)
        T = plan(obj, opts)
        [R, E, G] = computePlot(obj, src, spec)
        figs = renderPlotFigures(obj, R, spec, opts)
        rows = runDataset(obj, k, opts)
        T = run(obj, opts)
        cancel(obj)
        progress(obj, fraction, message)
        log(obj, fmt, varargin)

        function obj = EphysAnalysisRunner(cfg, opts)
            %EphysAnalysisRunner  Find the config's datasets (Scan=false: later, with datasets()).
            arguments
                cfg (1,1) EphysAnalysisConfig = EphysAnalysisConfig()
                opts.ProgressFcn = []
                opts.LogFcn = @(msg) fprintf('%s\n', msg)
                opts.Scan (1,1) logical = true
            end
            obj.Config = cfg;
            obj.ProgressFcn = opts.ProgressFcn;
            obj.LogFcn = opts.LogFcn;
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

        function clearSources(obj)
            %clearSources  Forget the loaded sources and every dataset's cached data.
            if ~isempty(obj.Sources); remove(obj.Sources, keys(obj.Sources)); end
            for k = 1:numel(obj.Outputs); obj.Outputs(k).clearCache(); end
        end
    end

    methods (Static)
        function T = emptyResults()
            T = table(strings(0, 1), strings(0, 1), strings(0, 1), strings(0, 1), strings(0, 1), strings(0, 1), zeros(0, 1), ...
                'VariableNames', {'Dataset', 'Plot', 'Kind', 'Status', 'Message', 'Files', 'Seconds'});
        end
    end
end
