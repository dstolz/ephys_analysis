classdef EphysAnalysisScript
    % EphysAnalysisScript  Generate MATLAB scripts that reproduce an analysis config's run.
    %   Two forms, as EphysPipelineScript writes for pipeline configs:
    %     compact(cfg, ConfigFile=)   a short script that loads the saved JSON
    %                                 config and runs EphysAnalysisRunner:
    %                                 plan, then run. Keep the config next to it.
    %     standalone(cfg)             every setting written out as MATLAB
    %                                 literals: the datasets, one fully
    %                                 resolved spec per plot (ref, window and
    %                                 selection expanded), then per dataset
    %                                 and plot the calls the runner makes --
    %                                 loadAnalysisSource, epochTable,
    %                                 selectUnits / selectChannels, spikePSTH
    %                                 / evokedPotential / firingRate /
    %                                 tuningCurve / unitCorrelation / unitSummary +
    %                                 probeMapValues, newExportFigure,
    %                                 renderPlot, exportFigure, the report
    %                                 calls. It never uses EphysAnalysisRunner,
    %                                 so it documents exactly what a run does.
    %   Both return the script text; pass File= to write it.
    %
    %   See also EphysAnalysisConfig, EphysAnalysisRunner, EphysPipelineScript.

    methods (Static)
        function txt = compact(cfg, opts)
            %compact  Script that loads the config JSON and drives EphysAnalysisRunner.
            arguments
                cfg (1,1) EphysAnalysisConfig
                opts.ConfigFile (1,1) string = ""
                opts.File (1,1) string = ""
            end
            configFile = opts.ConfigFile;
            if configFile == ""; configFile = cfg.File; end
            if configFile == ""
                error('EphysAnalysisScript:NoConfigFile', ...
                    'The compact script needs the config saved to a file: pass ConfigFile= or save the config first.');
            end
            lit = @EphysPipelineScript.literal;
            L = strings(0, 1);
            L(end+1, 1) = "%% Analysis: " + cfg.Name;
            L(end+1, 1) = "% Generated " + string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm')) + " by EphysAnalysisScript.compact.";
            L(end+1, 1) = "% Loads the saved analysis config and runs it: compute every enabled plot on";
            L(end+1, 1) = "% every dataset, export the figures and write the report. Edit the JSON (or";
            L(end+1, 1) = "% set fields on cfg below) and run again.";
            if cfg.Description ~= ""; L(end+1, 1) = "% " + cfg.Description; end
            L(end+1, 1) = "";
            L(end+1, 1) = "cfg = EphysAnalysisConfig.load(" + lit(configFile) + ");";
            L(end+1, 1) = "";
            L(end+1, 1) = "% --- overrides (uncomment to change without editing the JSON) ---";
            L(end+1, 1) = "% cfg.Export.Formats = " + lit(cfg.Export.Formats) + ";";
            L(end+1, 1) = "% cfg.Report.Format = ""both"";";
            L(end+1, 1) = "% cfg.Defaults.Selection.groupBy = " + lit(cfg.Defaults.Selection.groupBy) + ";";
            L(end+1, 1) = "";
            L(end+1, 1) = "r = EphysAnalysisRunner(cfg);      % finds the datasets";
            L(end+1, 1) = "disp(r.plan());                    % dataset x plot, and why any is skipped";
            L(end+1, 1) = "R = r.run();                       % compute, render, export, report";
            L(end+1, 1) = "disp(R);";
            L(end+1, 1) = "disp(r.ReportFiles);";
            txt = strjoin(L, newline) + newline;
            if opts.File ~= ""
                EphysAnalysisScript.write(opts.File, txt);
            end
        end

        function txt = standalone(cfg, opts)
            %standalone  Script with every setting written out; no config file, no runner.
            arguments
                cfg (1,1) EphysAnalysisConfig
                opts.File (1,1) string = ""
            end
            lit = @EphysPipelineScript.literal;
            S = cfg.Source;
            X = cfg.Export;
            P = cfg.Report;
            L = strings(0, 1);
            L(end+1, 1) = "%% Analysis: " + cfg.Name + " (standalone)";
            L(end+1, 1) = "% Generated " + string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm')) + " by EphysAnalysisScript.standalone.";
            L(end+1, 1) = "% Every setting is written out below; the script calls the analysis functions";
            L(end+1, 1) = "% directly (not through the runner) and needs no config file. The config it";
            L(end+1, 1) = "% came from, for reference:";
            for jl = splitlines(cfg.toJson()).'
                if strlength(jl) > 0; L(end+1, 1) = "%   " + jl; end %#ok<AGROW>
            end
            L(end+1, 1) = "";

            % --- datasets --------------------------------------------------------
            L(end+1, 1) = "%% Datasets";
            if S.Mode == "project"
                L(end+1, 1) = "root = " + lit(S.Root) + ";";
                L(end+1, 1) = "P = EphysProject(root, OutputRoot=" + lit(S.OutputRoot) + ", NamePattern=" + lit(S.NamePattern) + ...
                    ", ReaderOptions=struct('OpenEphys', struct('Recordings', " + lit(S.Recordings) + ")));";
                if S.Selection == "list"
                    L(end+1, 1) = "idx = P.findByKey(" + lit(S.Datasets) + ");   % root-relative dataset keys";
                    L(end+1, 1) = "idx = idx(idx > 0);";
                else
                    L(end+1, 1) = "idx = 1:P.NumDatasets;             % every recording under the root";
                end
                L(end+1, 1) = "outs = DatasetOutputs.empty(1, 0); keys = strings(1, 0); folders = strings(1, 0);";
                L(end+1, 1) = "for k = idx";
                L(end+1, 1) = "    d = P.Datasets(k);";
                L(end+1, 1) = "    outs(end+1) = d.outputs('CacheData', true);   % its processed files, loaded on demand";
                L(end+1, 1) = "    keys(end+1) = P.datasetKey(k);";
                L(end+1, 1) = "    folders(end+1) = string(d.outputFolder());";
                L(end+1, 1) = "end";
            else
                L(end+1, 1) = "root = " + lit(S.Root) + ";";
                L(end+1, 1) = "folders = " + lit(S.Folders) + ";   % the datasets' output folders";
                L(end+1, 1) = "outs = DatasetOutputs.empty(1, 0);";
                L(end+1, 1) = "for f = folders";
                L(end+1, 1) = "    outs(end+1) = DatasetOutputs(f, CacheData=true);";
                L(end+1, 1) = "end";
                L(end+1, 1) = "keys = folders;";
            end
            L(end+1, 1) = "outputRoot = " + lit(S.OutputRoot) + ";";
            L(end+1, 1) = "if outputRoot == """"; outputRoot = root; end";
            L(end+1, 1) = "if outputRoot == """" && ~isempty(folders); outputRoot = string(fileparts(folders(1))); end";
            L(end+1, 1) = "";

            % --- plot specs --------------------------------------------------------
            ids = cfg.enabledPlots();
            L(end+1, 1) = "%% Plot specs (every ""default"" resolved from the config's Defaults)";
            for k = 1:numel(ids)
                L = [L; EphysPipelineScript.structLiteral("spec" + k, cfg.plotFor(ids(k)))]; %#ok<AGROW>
            end
            L(end+1, 1) = "";
            L(end+1, 1) = "%% Export and report settings";
            L = [L; EphysPipelineScript.structLiteral("exportOpts", X)];
            L = [L; EphysPipelineScript.structLiteral("reportOpts", P)];
            doReport = P.Enabled;
            if doReport
                L = [L; EphysAnalysisScript.chunkedLiteral("configJson", cfg.toJson(Pretty=false))];
                L(end+1, 1) = "config = EphysAnalysisConfig.fromStruct(jsondecode(configJson)).toStruct();   % printed in the report";
                L(end+1, 1) = "title = replace(reportOpts.Title, [""{Name}"" ""{Date}""], [" + lit(cfg.Name) + ...
                    " string(datetime('now', 'Format', 'yyyy-MM-dd'))]);";
                L(end+1, 1) = "reportFiles = strings(1, 0);";
                if ~P.PerDataset
                    L(end+1, 1) = "report = newAnalysisReport(Title=title, Config=config, Export=exportOpts, Options=reportOpts);";
                end
            end
            L(end+1, 1) = "";

            % --- run -------------------------------------------------------------------
            L(end+1, 1) = "%% Run: every plot on every dataset";
            L(end+1, 1) = "for k = 1:numel(outs)";
            L(end+1, 1) = "    src = loadAnalysisSource(outs(k), Key=keys(k));   % events, trials, what exists; no bulk data";
            L(end+1, 1) = "    name = src.name;";
            if doReport
                if P.PerDataset
                    L(end+1, 1) = "    report = newAnalysisReport(Title=title, Config=config, Export=exportOpts, Options=reportOpts);";
                end
                L(end+1, 1) = "    report = addReportDataset(report, src);";
            end
            L(end+1, 1) = "    folder = figureFileName(exportOpts.Folder, struct('OutputFolder', folders(k), 'OutputRoot', outputRoot, ...";
            L(end+1, 1) = "        'Root', root, 'Name', name), Kind=""folder"");";
            for k = 1:numel(ids)
                spec = cfg.plotFor(ids(k));
                L(end+1, 1) = ""; %#ok<AGROW>
                L(end+1, 1) = "    % --- " + spec.id + " (" + spec.kind + ") ---"; %#ok<AGROW>
                L(end+1, 1) = "    spec = spec" + k + ";"; %#ok<AGROW>
                L(end+1, 1) = "    reason = plotSkipReason(src, spec);   % what the dataset lacks for this plot"; %#ok<AGROW>
                L(end+1, 1) = "    if reason == """""; %#ok<AGROW>
                L(end+1, 1) = "        try"; %#ok<AGROW>
                L = [L; "            " + EphysAnalysisScript.computeLines(spec)]; %#ok<AGROW>
                L(end+1, 1) = "            R.dataset = src.name;"; %#ok<AGROW>
                L(end+1, 1) = "            R.spec = spec;"; %#ok<AGROW>
                L(end+1, 1) = "            files = strings(1, 0);"; %#ok<AGROW>
                if X.Enabled
                    L(end+1, 1) = "            n = plotPageCount(R, spec);"; %#ok<AGROW>
                    L(end+1, 1) = "            for p = 1:n"; %#ok<AGROW>
                    L(end+1, 1) = "                fig = newExportFigure(exportOpts);"; %#ok<AGROW>
                    L(end+1, 1) = "                renderPlot(R, spec, fig, Page=p);"; %#ok<AGROW>
                    L(end+1, 1) = "                base = fullfile(folder, plotFileName(exportOpts.FilenamePattern, name, spec, R, p, n));"; %#ok<AGROW>
                    L(end+1, 1) = "                want = base + ""."" + exportOpts.Formats;"; %#ok<AGROW>
                    L(end+1, 1) = "                if ~exportOpts.Overwrite && all(isfile(want))"; %#ok<AGROW>
                    L(end+1, 1) = "                    files = [files want]; %#ok<AGROW>"; %#ok<AGROW>
                    L(end+1, 1) = "                else"; %#ok<AGROW>
                    L(end+1, 1) = "                    files = [files exportFigure(fig, base, Format=exportOpts.Formats, Dpi=exportOpts.Dpi)]; %#ok<AGROW>"; %#ok<AGROW>
                    L(end+1, 1) = "                end"; %#ok<AGROW>
                    L(end+1, 1) = "                close(fig);"; %#ok<AGROW>
                    L(end+1, 1) = "            end"; %#ok<AGROW>
                end
                if doReport
                    L(end+1, 1) = "            report = addReportFigure(report, spec, R, Files=files);"; %#ok<AGROW>
                end
                L(end+1, 1) = "            fprintf('%s: %s done (%d file(s))\n', name, spec.id, numel(files));"; %#ok<AGROW>
                L(end+1, 1) = "        catch ME"; %#ok<AGROW>
                if doReport
                    L(end+1, 1) = "            report = addReportFigure(report, spec, [], Status=""error"", Message=string(ME.message));"; %#ok<AGROW>
                end
                L(end+1, 1) = "            fprintf(2, '%s: %s FAILED: %s\n', name, spec.id, ME.message);"; %#ok<AGROW>
                L(end+1, 1) = "        end"; %#ok<AGROW>
                L(end+1, 1) = "    else"; %#ok<AGROW>
                if doReport
                    L(end+1, 1) = "        report = addReportFigure(report, spec, [], Status=""skipped"", Message=reason);"; %#ok<AGROW>
                end
                L(end+1, 1) = "        fprintf('%s: %s skipped (%s)\n', name, spec.id, reason);"; %#ok<AGROW>
                L(end+1, 1) = "    end"; %#ok<AGROW>
            end
            L(end+1, 1) = "    src.outputs.clearCache();   % free this dataset's spikes and signals";
            if doReport && P.PerDataset
                L = [L; "    " + EphysAnalysisScript.reportLines("folders(k)", "name", true)];
            end
            L(end+1, 1) = "end";
            if doReport && ~P.PerDataset
                L(end+1, 1) = "";
                L(end+1, 1) = "%% Report";
                L(end+1, 1) = "if ~isempty(outs)";
                L = [L; "    " + EphysAnalysisScript.reportLines("folders(1)", "report.datasets(1).name", false)];
                L(end+1, 1) = "end";
                L(end+1, 1) = "disp(reportFiles.');";
            end
            txt = strjoin(L, newline) + newline;
            if opts.File ~= ""
                EphysAnalysisScript.write(opts.File, txt);
            end
        end

        function write(file, txt)
            %write  Write script text to FILE (creating the folder).
            EphysPipelineScript.write(file, txt);
        end
    end

    methods (Static, Access = private)
        function L = chunkedLiteral(name, txt)
            %chunkedLiteral  NAME = one long string, written as short pieces joined.
            n = 96;
            s = char(txt);
            parts = strings(0, 1);
            for i = 1:n:numel(s)
                parts(end+1, 1) = string(s(i:min(end, i + n - 1))); %#ok<AGROW>
            end
            L = name + " = strjoin([ ...";
            L = [L; "    " + arrayfun(@(p) EphysPipelineScript.literal(p), parts) + " ..."];
            L(end+1, 1) = "    ], """");";
        end

        function L = computeLines(spec)
            %computeLines  The compute calls of one plot, as EphysAnalysisRunner.computePlot makes them.
            lit = @EphysPipelineScript.literal;
            w = lit([spec.window.pre spec.window.post]);
            b = "[]";
            if spec.baseline.Mode ~= "none"; b = lit(spec.baseline.Window); end
            epochs = "[E, G] = epochTable(src, spec.ref, Window=spec.window, Selection=spec.selection);";
            isSignal = ismember(spec.source, EphysAnalysisConfig.SignalSources);
            L = strings(0, 1);
            switch spec.kind
                case {"psth" "raster" "heatmap"}
                    L(end+1, 1) = epochs;
                    if isSignal
                        L(end+1, 1) = "[Y, fs, meta] = selectChannels(src, " + lit(spec.source) + ", Channels=" + lit(spec.channels) + ");";
                        L(end+1, 1) = "R = evokedPotential(Y, fs, E, Window=" + w + ", Baseline=" + b + ", Groups=G, Meta=meta, Units=meta.units(1));";
                    else
                        raster = spec.kind == "raster" || (spec.kind == "psth" && spec.withRaster);
                        L(end+1, 1) = "[st, meta] = selectUnits(src, spec.units);";
                        L(end+1, 1) = "R = spikePSTH(st, E, Window=" + w + ", BinSec=" + lit(spec.bins.BinSec) + ...
                            ", SmoothSec=" + lit(spec.bins.SmoothSec) + ", Baseline=" + b + ", BaselineMode=" + lit(spec.baseline.Mode) + ", ...";
                        L(end+1, 1) = "    MaskAfterStop=" + lit(spec.maskAfterStop) + ", Raster=" + lit(raster) + ", Groups=G, Meta=meta);";
                    end
                case "evoked"
                    L(end+1, 1) = epochs;
                    L(end+1, 1) = "[Y, fs, meta] = selectChannels(src, " + lit(spec.source) + ", Channels=" + lit(spec.channels) + ");";
                    L(end+1, 1) = "R = evokedPotential(Y, fs, E, Window=" + w + ", Baseline=" + b + ", Groups=G, Meta=meta, Units=meta.units(1));";
                case "rate"
                    L(end+1, 1) = epochs;
                    L(end+1, 1) = "[st, meta] = selectUnits(src, spec.units);";
                    L(end+1, 1) = "R = firingRate(st, E, Baseline=" + b + ", Normalize=" + lit(spec.baseline.Mode) + ", Groups=G, Meta=meta);";
                case "tuning"
                    cols = [spec.param spec.seriesParam];
                    cols = cols(cols ~= "");
                    L(end+1, 1) = "[E, G] = epochTable(src, spec.ref, Window=spec.window, Selection=spec.selection, Columns=" + lit(cols) + ");";
                    L(end+1, 1) = "[st, meta] = selectUnits(src, spec.units);";
                    L(end+1, 1) = "F = firingRate(st, E, Baseline=" + b + ", Normalize=" + lit(spec.baseline.Mode) + ", Groups=G, Meta=meta);";
                    series = "[]";
                    if spec.seriesParam ~= ""; series = "E.(" + lit(spec.seriesParam) + ")"; end
                    L(end+1, 1) = "R = tuningCurve(F.rate, E.(" + lit(spec.param) + "), Series=" + series + ", Param=" + lit(spec.param) + ...
                        ", SeriesParam=" + lit(spec.seriesParam) + ", Meta=meta, Units=F.units);";
                case "corrmap"
                    L(end+1, 1) = epochs;
                    L(end+1, 1) = "[st, meta] = selectUnits(src, spec.units);";
                    L(end+1, 1) = "R = unitCorrelation(st, E, Metric=" + lit(spec.metric) + ", Type=" + lit(spec.correlation) + ...
                        ", BinSec=" + lit(spec.bins.BinSec) + ", SmoothSec=" + lit(spec.bins.SmoothSec) + ", ...";
                    L(end+1, 1) = "    Baseline=" + b + ", BaselineMode=" + lit(spec.baseline.Mode) + ", Groups=G, Meta=meta);";
                case "probemap"
                    L(end+1, 1) = "T = unitSummary(src, Source=" + lit(spec.source) + ", Units=spec.units);";
                    L(end+1, 1) = "R = probeMapValues(T, src.probe, Value=" + lit(spec.value) + ");";
                    L(end+1, 1) = "E = [];";
            end
            L(end+1, 1) = "R.epochs = E;";
        end

        function L = reportLines(folderExpr, nameExpr, perDataset)
            %reportLines  Write the report as the runner does (html / pdf / both).
            L = strings(0, 1);
            L(end+1, 1) = "reportFolder = figureFileName(reportOpts.Folder, struct('OutputFolder', " + folderExpr + ", ...";
            L(end+1, 1) = "    'OutputRoot', outputRoot, 'Root', root, 'Name', " + nameExpr + "), Kind=""folder"");";
            L(end+1, 1) = "base = fullfile(reportFolder, reportOpts.FileName);";
            if perDataset
                L(end+1, 1) = "base = base + ""_"" + regexprep(" + nameExpr + ", '[^\w\-\.]', '_');";
            end
            L(end+1, 1) = "if ismember(reportOpts.Format, [""html"" ""both""]); reportFiles(end+1) = writeHtmlReport(report, base + "".html""); end";
            L(end+1, 1) = "if ismember(reportOpts.Format, [""pdf"" ""both""]); reportFiles(end+1) = writePdfReport(report, base + "".pdf""); end";
        end
    end
end
