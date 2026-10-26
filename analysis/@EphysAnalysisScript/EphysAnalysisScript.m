classdef EphysAnalysisScript
    % EphysAnalysisScript  Generate MATLAB scripts that reproduce an analysis config's run.
    %   Two forms, as EphysPipelineScript writes for pipeline configs:
    %     compact(cfg, ConfigFile=)   a short script that loads the saved JSON
    %                                 config and runs EphysAnalysisRunner:
    %                                 plan, then run. Keep the config next to it.
    %     standalone(cfg)             every setting written out as MATLAB
    %                                 literals: the datasets, one fully
    %                                 resolved spec per enabled figure
    %                                 (fspec<k>, figureFor written out: ref,
    %                                 window and selection expanded), then
    %                                 per dataset and figure the calls the
    %                                 runner makes -- loadAnalysisSource,
    %                                 figureSkipReason, figureObservations
    %                                 and, a page per observation,
    %                                 figureCompute, newExportFigure,
    %                                 renderFigure, exportFigure
    %                                 (figureOutputName), reportImage and
    %                                 reportPdfPage, the report entry with
    %                                 figureCaption. A figure with a
    %                                 panel of yLimMode "batch" is measured
    %                                 first over every dataset
    %                                 (figureYExtents, figureBatchYLim:
    %                                 batchYLim<k>) and drawn at that range
    %                                 (renderFigure BatchYLim=), a session
    %                                 figure over its observations, as the
    %                                 runner does. After the datasets, a
    %                                 "Session figures" block per enabled
    %                                 session figure (sfspec<j>):
    %                                 sessionTable, a source per session,
    %                                 figureSessionSkipReason, then per
    %                                 matched observation
    %                                 figureSessionCompute, the figures into
    %                                 Export.SessionsFolder, the "Across
    %                                 sessions" report section and, with
    %                                 Export.Data.Enabled, the data file
    %                                 (writeAnalysisData). It never uses
    %                                 EphysAnalysisRunner, so it documents
    %                                 exactly what a run does.
    %     preview(cfg, id, Datasets=)  one figure for one observation, as the
    %                                 analysis app's Figures-tab preview draws
    %                                 it (its Export code button): the
    %                                 dataset, the figure's spec written out,
    %                                 the observation, the data in the
    %                                 preview's epochs as plain variables
    %                                 (every event and spike train, the
    %                                 trials, figureEpochs, epochSpikes,
    %                                 epochEvents), then figureCompute (or
    %                                 figureSessionCompute) and renderFigure
    %                                 into a figure window.
    %   Each returns the script text; pass File= to write it.
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
            L(end+1, 1) = "% Loads the saved analysis config and runs it: draw every enabled figure on";
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
            L(end+1, 1) = "disp(r.plan());                    % dataset x figure, and why any is skipped";
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
            sfids = cfg.enabledSessionFigures();   % the session figures, drawn across the datasets after the loop
            across = ~isempty(sfids);
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
                if across
                    L(end+1, 1) = "names = strings(1, 0); acq = NaT(1, 0);   % for the session figures: each dataset's name and start";
                end
                L(end+1, 1) = "for k = idx";
                L(end+1, 1) = "    d = P.Datasets(k);";
                L(end+1, 1) = "    outs(end+1) = d.outputs('CacheData', true);   % its processed files, loaded on demand";
                L(end+1, 1) = "    keys(end+1) = P.datasetKey(k);";
                L(end+1, 1) = "    folders(end+1) = string(d.outputFolder());";
                if across
                    L(end+1, 1) = "    names(end+1) = d.Name;";
                    L(end+1, 1) = "    a = d.AcqDate;   % the recording's own start, for the session figures' dates";
                    L(end+1, 1) = "    if isdatetime(a) && ~isempty(a); acq(end+1) = a(1); else; acq(end+1) = NaT; end";
                end
                L(end+1, 1) = "end";
            else
                L(end+1, 1) = "root = " + lit(S.Root) + ";";
                L(end+1, 1) = "folders = " + lit(S.Folders) + ";   % the datasets' output folders";
                L(end+1, 1) = "outs = DatasetOutputs.empty(1, 0);";
                if across
                    L(end+1, 1) = "names = strings(1, 0); acq = NaT(1, 0);   % folders carry no acquisition date";
                end
                L(end+1, 1) = "for f = folders";
                L(end+1, 1) = "    outs(end+1) = DatasetOutputs(f, CacheData=true);";
                if across
                    L(end+1, 1) = "    names(end+1) = outs(end).Name;";
                    L(end+1, 1) = "    acq(end+1) = NaT;";
                end
                L(end+1, 1) = "end";
                L(end+1, 1) = "keys = folders;";
            end
            L(end+1, 1) = "outputRoot = " + lit(S.OutputRoot) + ";";
            L(end+1, 1) = "if outputRoot == """"; outputRoot = root; end";
            L(end+1, 1) = "if outputRoot == """" && ~isempty(folders); outputRoot = string(fileparts(folders(1))); end";
            L(end+1, 1) = "";

            % --- figure specs ------------------------------------------------------
            fids = cfg.enabledFigures();
            if ~isempty(fids)
                L(end+1, 1) = "%% Figure specs (Figures: every ""default"" resolved, as figureFor gives them)";
                for k = 1:numel(fids)
                    L = [L; EphysPipelineScript.structLiteral("fspec" + k, cfg.figureFor(fids(k)))]; %#ok<AGROW>
                end
                L(end+1, 1) = "";
            end
            if ~isempty(sfids)
                L(end+1, 1) = "%% Session figure specs (figures drawn across the datasets: figureFor, enabled as asked)";
                for j = 1:numel(sfids)
                    sf = cfg.figureFor(sfids(j));
                    sf.enabled = true;   % as runSessionFigure draws it
                    L = [L; EphysPipelineScript.structLiteral("sfspec" + j, sf)]; %#ok<AGROW>
                end
                L(end+1, 1) = "";
            end
            L(end+1, 1) = "%% Export and report settings";
            L = [L; EphysPipelineScript.structLiteral("exportOpts", X)];
            L = [L; EphysPipelineScript.structLiteral("reportOpts", P)];
            doReport = P.Enabled;
            withImages = doReport && P.Format ~= "pdf";   % the HTML report embeds each exported page
            withPages = doReport && P.Format ~= "html";   % the PDF report holds each exported page
            if doReport || (~isempty(sfids) && X.Data.Enabled)
                L = [L; EphysAnalysisScript.chunkedLiteral("configJson", cfg.toJson(Pretty=false))];
                L(end+1, 1) = "config = EphysAnalysisConfig.fromStruct(jsondecode(configJson)).toStruct();   % printed in the report and saved with the session figures' data";
            end
            if doReport
                L(end+1, 1) = "title = replace(reportOpts.Title, [""{Name}"" ""{Date}""], [" + lit(cfg.Name) + ...
                    " string(datetime('now', 'Format', 'yyyy-MM-dd'))]);";
                L(end+1, 1) = "reportFiles = strings(1, 0);";
                if ~P.PerDataset
                    L(end+1, 1) = "report = newAnalysisReport(Title=title, Config=config, Export=exportOpts, Options=reportOpts);";
                end
            end
            L(end+1, 1) = "";

            % --- shared y ranges ---------------------------------------------------------
            drawsAny = X.Enabled || withImages || withPages;
            batchFig = false(1, numel(fids));
            for k = 1:numel(fids)
                batchFig(k) = drawsAny && ~isempty(figureBatchPanels(cfg.figureFor(fids(k))));
                if ~batchFig(k); continue; end
                L(end+1, 1) = "%% Shared y range of " + fids(k) + " (yLimMode ""batch""): every observation on every dataset measured first";
                L(end+1, 1) = "yext = {};";
                L(end+1, 1) = "for k = 1:numel(outs)";
                L(end+1, 1) = "    src = loadAnalysisSource(outs(k), Key=keys(k));";
                L(end+1, 1) = "    if figureSkipReason(src, fspec" + k + ") == """"";
                L(end+1, 1) = "        obsT = figureObservations(src, fspec" + k + ");";
                L(end+1, 1) = "        for i = 1:height(obsT)   % each observation drawn hidden: its y extent";
                L(end+1, 1) = "            yext{end+1} = figureYExtents(figureCompute(src, fspec" + k + ", Observation=obsT(i, :)), fspec" + k + "); %#ok<SAGROW>";
                L(end+1, 1) = "        end";
                L(end+1, 1) = "    end";
                L(end+1, 1) = "    src.outputs.clearCache();";
                L(end+1, 1) = "end";
                L(end+1, 1) = "batchYLim" + k + " = figureBatchYLim(yext);   % the union: every page of " + fids(k) + " on one scale";
                L(end+1, 1) = "";
            end

            % --- run -------------------------------------------------------------------
            L(end+1, 1) = "%% Run: every figure on every dataset";
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
            for k = 1:numel(fids)
                L = [L; EphysAnalysisScript.figureLines(fids(k), k, X.Enabled, doReport, withImages, withPages, batchFig(k))]; %#ok<AGROW>
            end
            L(end+1, 1) = "    src.outputs.clearCache();   % free this dataset's spikes and signals";
            if doReport && P.PerDataset
                L = [L; "    " + EphysAnalysisScript.reportLines("folders(k)", "name", true)];
            end
            L(end+1, 1) = "end";
            if ~isempty(sfids)
                L(end+1, 1) = "";
                L = [L; EphysAnalysisScript.sessionLines(cfg, sfids, withImages, withPages)];
            end
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

        function txt = preview(cfg, id, opts)
            %preview  Script that draws one figure for one observation, as the analysis app's preview does.
            %   TXT = EphysAnalysisScript.preview(CFG, ID, Datasets=KEY,
            %   Observation=OBS) for the figure ID of CFG makes the preview's
            %   calls (refreshFigurePreview) without the runner or the app:
            %   the dataset KEY (as the runner keys it: the root-relative key
            %   in project mode, the output folder in folders mode),
            %   loadAnalysisSource, the figure's spec (figureFor, enabled set,
            %   written out), figureSkipReason, figureObservations and the row
            %   OBS is (found again by its unit id, column or kind, and its
            %   trial group; [] = the first row), then the data in the
            %   figure's epochs as plain variables (dataLines): every event
            %   line (events, lineNames), the trials, the artifact periods,
            %   every spike train of the figure's source (spikes, units;
            %   units.observed: those the figure is drawn for), the epochs
            %   and trial groups the preview draws (E, G: figureEpochs, every
            %   group), each unit's spikes in each epoch (spikesIn:
            %   epochSpikes), each line's onsets and offsets in each epoch
            %   (onsets, offsets: epochEvents) and, for a figure of channels,
            %   its signal cut into the epochs (signalIn, signalTime,
            %   channels, fs), then figureCompute and renderFigure into a
            %   figure() window of Size= px in the design Design= ("" = the
            %   user's design when the script runs).
            %   A figure across sessions (sessions.enabled) is drawn over the
            %   datasets KEY (several): their sessionTable, a source each,
            %   figureSessionObservations and the row labeled as OBS, the data
            %   of each session as data(j) (the variables above, without
            %   units.observed), figureSessionCompute, and the figure of its result labeled
            %   Entry= ("" = the first: one per subject or trial group).
            %   Errors: EphysAnalysisScript:NoFigure, EphysAnalysisScript:NoDataset.
            arguments
                cfg (1,1) EphysAnalysisConfig
                id (1,1) string
                opts.Datasets (1,:) string = string.empty(1, 0)
                opts.Observation = []
                opts.Entry (1,1) string = ""
                opts.Design (1,1) string = ""
                opts.Size (1,2) double {mustBePositive} = [900 600]
                opts.File (1,1) string = ""
            end
            if cfg.figureIndex(id) == 0
                error('EphysAnalysisScript:NoFigure', 'The config has no figure "%s".', id);
            end
            keys = opts.Datasets;
            if isempty(keys)
                error('EphysAnalysisScript:NoDataset', 'The preview script needs the dataset: pass Datasets=.');
            end
            lit = @EphysPipelineScript.literal;
            S = cfg.Source;
            spec = cfg.figureFor(id);
            spec.enabled = true;   % a figure that is off is still previewed
            across = spec.sessions.enabled;
            if ~across; keys = keys(1); end
            obs = opts.Observation;
            what = id;
            if istable(obs) && height(obs) > 0
                obs = obs(1, :);
                what = what + ": " + string(obs.label);
            end
            L = strings(0, 1);
            L(end+1, 1) = "%% Figure " + what;
            L(end+1, 1) = "% Generated " + string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm')) + " by EphysAnalysisScript.preview.";
            L(end+1, 1) = "% Loads the " + ternary(across, "datasets", "dataset") + " and arranges the data in the epochs the analysis";
            L(end+1, 1) = "% app's preview draws -- every event, every spike train, the trials, each";
            L(end+1, 1) = "% unit's spikes and each line's events in every epoch -- as plain variables";
            L(end+1, 1) = "% to analyze" + ternary(across, " (data(j): session j)", "") + ". Then it draws the figure as the preview does, with the";
            L(end+1, 1) = "% analysis functions themselves: " + ternary(across, "figureSessionCompute", "figureCompute") + " and renderFigure. Change";
            L(end+1, 1) = "% spec (or pick another row of obsT) and run it again.";
            L(end+1, 1) = "";

            % --- the dataset(s) --------------------------------------------------------
            if across
                L(end+1, 1) = "%% The datasets: the sessions it is drawn across";
            else
                L(end+1, 1) = "%% The dataset";
            end
            if S.Mode == "project"
                L(end+1, 1) = "root = " + lit(S.Root) + ";";
                L(end+1, 1) = "P = EphysProject(root, OutputRoot=" + lit(S.OutputRoot) + ", NamePattern=" + lit(S.NamePattern) + ...
                    ", ReaderOptions=struct('OpenEphys', struct('Recordings', " + lit(S.Recordings) + ")));";
            end
            if ~across
                if S.Mode == "project"
                    L(end+1, 1) = "key = " + lit(keys) + ";   % its root-relative key";
                    L(end+1, 1) = "k = P.findByKey(key);";
                    L(end+1, 1) = "if k == 0; error('No dataset %s under %s.', key, root); end";
                    L(end+1, 1) = "outs = P.Datasets(k).outputs('CacheData', true);   % its processed files, loaded on demand";
                else
                    L(end+1, 1) = "key = " + lit(keys) + ";   % its output folder";
                    L(end+1, 1) = "outs = DatasetOutputs(key, CacheData=true);   % its processed files, loaded on demand";
                end
                L(end+1, 1) = "src = loadAnalysisSource(outs, Key=key);   % events, trials, what exists; no bulk data";
            else
                L(end+1, 1) = "keys = " + lit(keys) + ";   % " + ternary(S.Mode == "project", "root-relative keys", "output folders");
                L(end+1, 1) = "n = numel(keys);";
                L(end+1, 1) = "outs = DatasetOutputs.empty(1, 0); names = strings(1, n); folders = strings(1, n); acq = NaT(1, n);";
                L(end+1, 1) = "for j = 1:n";
                if S.Mode == "project"
                    L(end+1, 1) = "    k = P.findByKey(keys(j));";
                    L(end+1, 1) = "    if k == 0; error('No dataset %s under %s.', keys(j), root); end";
                    L(end+1, 1) = "    d = P.Datasets(k);";
                    L(end+1, 1) = "    outs(j) = d.outputs('CacheData', true);";
                    L(end+1, 1) = "    names(j) = d.Name;";
                    L(end+1, 1) = "    folders(j) = string(d.outputFolder());";
                    L(end+1, 1) = "    a = d.AcqDate;   % the recording's own start: the sessions' dates";
                    L(end+1, 1) = "    if isdatetime(a) && ~isempty(a); acq(j) = a(1); end";
                else
                    L(end+1, 1) = "    outs(j) = DatasetOutputs(keys(j), CacheData=true);";
                    L(end+1, 1) = "    names(j) = outs(j).Name;";
                    L(end+1, 1) = "    folders(j) = keys(j);   % folders carry no recording date";
                end
                L(end+1, 1) = "end";
                L(end+1, 1) = "sessions = sessionTable(names(:), keys(:), NamePattern=" + lit(S.NamePattern) + ...
                    ", AcqDates=acq(:), Folders=folders(:), Index=(1:n).', Sort=true);   % by date, then name";
                L(end+1, 1) = "sessions.status = repmat(""done"", n, 1);";
                L(end+1, 1) = "sessions.message = strings(n, 1);";
                L(end+1, 1) = "sources = cell(1, n);   % each session's analysis source, in session order";
                L(end+1, 1) = "for j = 1:n";
                L(end+1, 1) = "    q = sessions.index(j);";
                L(end+1, 1) = "    try";
                L(end+1, 1) = "        sources{j} = loadAnalysisSource(outs(q), Key=keys(q));";
                L(end+1, 1) = "    catch ME";
                L(end+1, 1) = "        sessions.status(j) = ""error""; sessions.message(j) = ""cannot read the dataset: "" + string(ME.message);";
                L(end+1, 1) = "    end";
                L(end+1, 1) = "end";
            end
            L(end+1, 1) = "";

            % --- the figure's spec -------------------------------------------------------
            L(end+1, 1) = "%% The figure (every ""default"" resolved, as figureFor gives it)";
            L = [L; EphysPipelineScript.structLiteral("spec", spec)];
            L(end+1, 1) = "";

            % --- the observation -----------------------------------------------------------
            if across
                L(end+1, 1) = "%% The observation, matched across the sessions";
                L(end+1, 1) = "obsT = figureSessionObservations(sources, spec);   % the sites, cells or channels enough sessions hold";
            else
                L(end+1, 1) = "%% The observation";
                L(end+1, 1) = "reason = figureSkipReason(src, spec);   % what the dataset lacks for this figure";
                L(end+1, 1) = "if reason ~= """"; error('%s cannot be drawn for %s: %s.', spec.id, src.name, reason); end";
                L(end+1, 1) = "obsT = figureObservations(src, spec);   % its units, channels, or the dataset, in probe order";
            end
            if istable(obs) && height(obs) > 0
                L(end+1, 1) = "i = find(" + EphysAnalysisScript.observationTest(obs, across) + ", 1);   % " + string(obs.label);
                L(end+1, 1) = "if isempty(i); error('The observation previewed is not in obsT: pick one of its rows.'); end";
            else
                L(end+1, 1) = "if height(obsT) == 0; error('%s has no observation to draw.', spec.id); end";
                L(end+1, 1) = "i = 1;   % the first";
            end
            L(end+1, 1) = "obs = obsT(i, :);";
            L(end+1, 1) = "";

            % --- the data, in the preview's epochs ------------------------------------------
            L = [L; EphysAnalysisScript.dataLines(spec, across)];
            L(end+1, 1) = "";

            % --- compute and draw --------------------------------------------------------
            L(end+1, 1) = "%% Compute and draw";
            if across
                L(end+1, 1) = "res = figureSessionCompute(sources, sessions, spec, Observation=obs);   % a figure per subject or trial group when spec asks";
                if opts.Entry ~= ""
                    L(end+1, 1) = "q = find(string({res.label}) == " + lit(opts.Entry) + ", 1);   % the figure picked under the preview";
                    L(end+1, 1) = "if isempty(q); q = 1; end";
                    L(end+1, 1) = "e = res(q);";
                else
                    L(end+1, 1) = "e = res(1);";
                end
                L(end+1, 1) = "if e.status ~= ""done""; error('%s (%s) is not drawn across the sessions: %s', spec.id, e.label, e.message); end";
                L(end+1, 1) = "F = e.F;";
            else
                L(end+1, 1) = "F = figureCompute(src, spec, Observation=obs);   % that observation's data only";
            end
            L(end+1, 1) = "fig = figure(""Name"", spec.id + "": "" + string(F.observation.label) + "" ("" + string(F.dataset) + "")"", ...";
            L(end+1, 1) = "    ""NumberTitle"", ""off"", ""Position"", [60 60 " + strjoin(string(round(opts.Size)), " ") + "]);";
            if opts.Design == ""
                L(end+1, 1) = "h = renderFigure(F, spec, fig);   % in your design (PlotDesign.current); right-click to change the looks";
            else
                L(end+1, 1) = "h = renderFigure(F, spec, fig, Design=" + lit(opts.Design) + ");   % the preview's design; right-click to change the looks";
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
        function test = observationTest(obs, across)
            %observationTest  The condition on obsT that finds the observation OBS again: its unit id, column or kind, and trial group.
            %   Across sessions (and wherever the number is missing) by its label.
            lit = @EphysPipelineScript.literal;
            if ~across && obs.kind == "unit" && isfinite(obs.unitId)
                test = "obsT.unitId == " + lit(obs.unitId);
            elseif ~across && obs.kind == "channel" && isfinite(obs.column)
                test = "obsT.column == " + lit(obs.column);
            elseif ~across && obs.kind == "dataset"
                test = "obsT.kind == ""dataset""";
            else
                test = "obsT.label == " + lit(string(obs.label));
            end
            if ~across && isfinite(obs.group)
                test = test + " & obsT.group == " + lit(obs.group);
            end
        end

        function L = dataLines(spec, across)
            %dataLines  The preview script's data section: the dataset's events, trials and spike trains, each cut into the figure's epochs.
            %   For one dataset (src, obsT) plain variables: events, lineNames,
            %   trials, artifacts, spikes and units (every unit of the figure's
            %   source, units.observed marking those the figure is drawn for;
            %   a figure of channels or of the dataset: every sorted unit, else
            %   every detection channel), the figure's epochs E and groups G
            %   (figureEpochs), spikesIn (epochSpikes), onsets and offsets
            %   (epochEvents) and, for a figure of channels, its signal cut
            %   into the epochs (selectChannels, evokedPotential: signalIn,
            %   signalTime, channels). ACROSS: the same per session (sources,
            %   sessions), kept as data(j).
            lit = @EphysPipelineScript.literal;
            ob = spec.observe;
            B = strings(0, 1);
            B(end+1, 1) = "events = src.events;   % every digital line and derived event: [onset offset] s, a row per interval";
            B(end+1, 1) = "lineNames = string(fieldnames(events)).';";
            B(end+1, 1) = "trials = src.trials;   % a row per trial: its parameters, TrialOnset / TrialOffset s (none without behavior)";
            B(end+1, 1) = "artifacts = src.artifacts;   % [start stop) s: the periods the Signals step erased";
            if ob.kind == "unit"
                what = ternary(ob.units.source == "detected", "detection channel", "sorted unit, whatever its class");
                B(end+1, 1) = "[spikes, units] = selectUnits(src, struct('source', " + lit(ob.units.source) + ...
                    ", 'classes', string.empty(1, 0)));   % every " + what + ": spikes{u} s; units a row each";
                if ~across
                    B(end+1, 1) = "units.observed = ismember(units.unitId, obsT.unitId);   % those the figure is drawn for (spec.observe.units)";
                end
            else
                B(end+1, 1) = "spikes = cell(0, 1); units = table();   % every sorted unit, else every detection channel: spikes{u} s; units a row each";
                B(end+1, 1) = "if src.hasUnits";
                B(end+1, 1) = "    [spikes, units] = selectUnits(src, struct('source', ""units"", 'classes', string.empty(1, 0)));";
                B(end+1, 1) = "elseif src.hasDetected";
                B(end+1, 1) = "    [spikes, units] = selectUnits(src, struct('source', ""detected""));";
                B(end+1, 1) = "end";
            end
            B(end+1, 1) = "[E, G] = figureEpochs(src, spec);   % the preview's epochs, a row each: t0, t0Continuous, tStart, tStop, trial, groupIndex, group";
            if ~across && ob.perGroup
                B(end+1, 1) = "% (every trial group's: the preview draws obs.groupLabel's, E.group == obs.groupLabel)";
            end
            B(end+1, 1) = "spikesIn = epochSpikes(spikes, E);   % {epoch, unit}: the unit's spikes in the epoch's window, s from its event";
            B(end+1, 1) = "M = epochEvents(src, E, Lines=lineNames, Edge=""both"");   % each line's onsets, then its offsets, in every window";
            B(end+1, 1) = "onsets = struct(); offsets = struct();   % onsets.(line){e}: the line's onsets in epoch e, s from its event";
            B(end+1, 1) = "for q = 1:numel(lineNames)";
            B(end+1, 1) = "    onsets.(lineNames(q)) = accumarray(M(2*q - 1).epoch, M(2*q - 1).t, [height(E) 1], @(x) {x}, {zeros(0, 1)});";
            B(end+1, 1) = "    offsets.(lineNames(q)) = accumarray(M(2*q).epoch, M(2*q).t, [height(E) 1], @(x) {x}, {zeros(0, 1)});";
            B(end+1, 1) = "end";
            keep = ["events" "lineNames" "trials" "artifacts" "spikes" "units" "E" "G" "spikesIn" "onsets" "offsets"];
            if ob.kind == "channel"
                sig = upper(ob.data);
                B(end+1, 1) = "[Y, fs, channels] = selectChannels(src, " + lit(sig) + ", Channels=spec.observe.channels);   % the figure's " + ...
                    sig + " channels: Y(k, :) at (k-1)/fs s";
                B(end+1, 1) = "R = evokedPotential(Y, fs, E, Window=[min(E.tStart - E.t0) max(E.tStop - E.t0)], KeepEpochs=true, Incomplete=""nan"", Meta=channels);";
                B(end+1, 1) = "signalIn = R.data;   % [time x channel x epoch], single: NaN outside the recording";
                B(end+1, 1) = "signalTime = R.t;    % s from each epoch's event";
                B(end+1, 1) = "clear Y R";
                keep = [keep "channels" "fs" "signalIn" "signalTime"];
            end
            if ~across
                L = ["%% The data, in the epochs the preview draws"
                    "% Times are s of the recording: the events on their clock (t = row/Fs), the spikes and"
                    "% signals on the continuous clock (row k at (k-1)/Fs), where E.t0Continuous is each event."
                    B];
                return
            end
            L = ["%% The data of each session, in the epochs the preview draws"
                "% data(j) is session j's (sessions(j, :)), as one dataset's script holds it. Times are s of"
                "% the recording: the events on their clock (t = row/Fs), the spikes and signals on the"
                "% continuous clock (row k at (k-1)/Fs), where E.t0Continuous is each event."
                "data = repmat(cell2struct(cell(" + (numel(keep) + 2) + ", 1), cellstr(" + lit(["session" "name" keep]) + "), 1), 1, n);   % empty where a session has none"
                "for j = 1:n"
                "    src = sources{j};"
                "    if isempty(src); continue; end"
                "    try"
                "        " + B
                "    catch ME"
                "        fprintf(2, '%s: no data in the figure''s epochs: %s\n', sessions.label(j), ME.message);"
                "        continue"
                "    end"
                "    d = struct('session', sessions.label(j), 'name', string(src.name));"];
            L = [L; "    d." + keep.' + " = " + keep.' + ";"];
            L(end+1, 1) = "    data(j) = d;";
            L(end+1, 1) = "end";
        end

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

        function L = sessionLines(cfg, sfids, withImages, withPages)
            %sessionLines  The "Session figures" block: each session figure across the datasets, as EphysAnalysisRunner.run makes it.
            %   SFIDS: the enabled session figures, whose literals sfspec<j> the
            %   script already holds. Mirrors run (the "Across sessions" report
            %   section, its own report with Report.PerDataset), then each
            %   session figure (sessionFigureLines).
            lit = @EphysPipelineScript.literal;
            S = cfg.Source;
            P = cfg.Report;
            doReport = P.Enabled;
            B = strings(0, 1);   % the body, inside "if ~isempty(outs)"
            if doReport
                B(end+1, 1) = "sessionsAll = sessionTable(names(:), keys(:), NamePattern=" + lit(S.NamePattern) + ...
                    ", AcqDates=acq(:), Folders=folders(:), Index=(1:numel(outs)).', Sort=true);";
                if P.PerDataset
                    B(end+1, 1) = "report = newAnalysisReport(Title=title, Config=config, Export=exportOpts, Options=reportOpts);   % the session figures' own report";
                end
                B(end+1, 1) = "report = addReportSection(report, ""Across sessions"", Summary=struct('sessions', table(sessionsAll.label, ...";
                B(end+1, 1) = "    sessionsAll.subject, sessionsAll.dateText, sessionsAll.name, sessionsAll.key, ...";
                B(end+1, 1) = "    'VariableNames', {'Session', 'Subject', 'Date', 'Dataset', 'Key'})));";
            end
            for j = 1:numel(sfids)
                B = [B; EphysAnalysisScript.sessionFigureLines(cfg, sfids(j), j, withImages, withPages)]; %#ok<AGROW>
            end
            if doReport && P.PerDataset
                B = [B; ""; EphysAnalysisScript.reportLines("folders(1)", """sessions""", true)];
            end
            L = ["%% Session figures"; "if ~isempty(outs)"; "    " + B; "end"];
            L = regexprep(L, '^    $', '');
        end

        function B = sessionFigureLines(cfg, id, j, withImages, withPages)
            %sessionFigureLines  One session figure across the datasets, as EphysAnalysisRunner.runSessionFigure draws it.
            %   Its spec is sfspec<J> (written above). Mirrors sessionFigureObservations
            %   (sessionTable, a source per session), figureSessionSkipReason, then per
            %   observation figureSessionCompute (each dataset's figureCompute, every
            %   layer merged by combineSessions), renderFigure, exportFigure into
            %   Export.SessionsFolder, a report entry per facet / trial group and the
            %   data file. Lines at the level of sessionLines' body.
            lit = @EphysPipelineScript.literal;
            S = cfg.Source;
            P = cfg.Report;
            X = cfg.Export;
            doReport = P.Enabled;
            doExport = X.Enabled;
            withData = X.Data.Enabled;
            fg = cfg.Figures(cfg.figureIndex(id));
            ss = fg.sessions;
            okind = EphysAnalysisConfig.observeKind(fg);
            B = strings(0, 1);
            B(end+1, 1) = "";
            B(end+1, 1) = "% --- " + id + " (figure across sessions) ---";
            B(end+1, 1) = "fspec = sfspec" + j + ";";
            B(end+1, 1) = "fspecKind = fspec; fspecKind.kind = ""figure"";   % the report entry's kind";
            if ss.datasets == "list"
                B(end+1, 1) = "sel = zeros(1, numel(fspec.sessions.datasetKeys));   % the listed datasets, by key or name";
                B(end+1, 1) = "for q = 1:numel(fspec.sessions.datasetKeys)";
                B(end+1, 1) = "    m = find(keys == fspec.sessions.datasetKeys(q), 1);";
                B(end+1, 1) = "    if isempty(m); m = find(names == fspec.sessions.datasetKeys(q), 1); end";
                B(end+1, 1) = "    if ~isempty(m); sel(q) = m; end";
                B(end+1, 1) = "end";
                B(end+1, 1) = "sel = sel(sel > 0);";
            else
                B(end+1, 1) = "sel = 1:numel(outs);   % the run's datasets";
            end
            B(end+1, 1) = "sessions = sessionTable(names(sel).', keys(sel).', NamePattern=" + lit(S.NamePattern) + ...
                ", AcqDates=acq(sel).', Folders=folders(sel).', Index=sel.', Sort=true);   % by date, then name";
            B(end+1, 1) = "sessions.status = repmat(""done"", height(sessions), 1);";
            B(end+1, 1) = "sessions.message = strings(height(sessions), 1);";
            B(end+1, 1) = "sources = cell(1, height(sessions));   % each session's source (sessionFigureObservations)";
            B(end+1, 1) = "reasons = strings(1, height(sessions));";
            B(end+1, 1) = "for j = 1:height(sessions)";
            B(end+1, 1) = "    k = sessions.index(j);";
            B(end+1, 1) = "    try";
            B(end+1, 1) = "        sources{j} = loadAnalysisSource(outs(k), Key=keys(k));";
            B(end+1, 1) = "        reasons(j) = figureSkipReason(sources{j}, fspec);";
            B(end+1, 1) = "    catch ME";
            B(end+1, 1) = "        sessions.status(j) = ""error""; sessions.message(j) = ""cannot read the dataset: "" + string(ME.message);";
            B(end+1, 1) = "        reasons(j) = sessions.message(j);";
            B(end+1, 1) = "    end";
            B(end+1, 1) = "end";
            B(end+1, 1) = "obsT = figureSessionObservations(sources, fspec);   % matched across the sessions: a page each";
            B(end+1, 1) = "reason = figureSessionSkipReason(fspec, reasons, Labels=reshape(sessions.label, 1, []));";
            B(end+1, 1) = "if reason == """" && height(obsT) == 0; reason = ""no "" + fspec.observe.kind + "" is matched across the sessions""; end";
            B(end+1, 1) = "if reason ~= """"";
            if doReport
                B(end+1, 1) = "    report = addReportFigure(report, fspecKind, [], Status=""skipped"", Message=reason);";
            end
            B(end+1, 1) = "    fprintf('sessions: %s skipped (%s)\n', fspec.id, reason);";
            B(end+1, 1) = "else";
            C = strings(0, 1);   % the body of the else
            C(end+1, 1) = "k1 = sessions.index(1);";
            C(end+1, 1) = "tokens = struct('OutputFolder', folders(k1), 'OutputRoot', outputRoot, 'Root', root, 'Name', names(k1));";
            C(end+1, 1) = "folder = figureFileName(exportOpts.SessionsFolder, tokens, Kind=""folder"");";
            C(end+1, 1) = "nObs = height(obsT);";
            C(end+1, 1) = "E = struct('label', {}, 'files', {}, 'images', {}, 'pages', {}, 'done', {}, 'why', {}, 'nError', {}, 'F', {}, 'rows', {});";
            C(end+1, 1) = "usedNames = strings(1, 0);   % the file names written: a sanitized name met again gets ""_2"", ""_3"", ...";
            if withData
                C(end+1, 1) = "results = struct('index', {}, 'observation', {}, 'facet', {}, 'group', {}, 'label', {}, 'status', {}, 'message', {}, 'F', {});";
                C(end+1, 1) = "perSession = cell(nObs, height(sessions));   % each dataset's own figure, per observation";
            end
            batch = (doExport || withImages || withPages) && ~isempty(figureBatchPanels(cfg.figureFor(id)));
            bArg = "";
            yArg = "";
            if batch   % yLimMode "batch": every observation measured first (runSessionFigure holds them; here they are computed again)
                C(end+1, 1) = "yext = {};   % yLimMode ""batch"": every observation measured first, then drawn at the union of their y extents";
                C(end+1, 1) = "for i = 1:nObs";
                C(end+1, 1) = "    try";
                C(end+1, 1) = "        res = figureSessionCompute(sources, sessions, fspec, Observation=obsT(i, :));";
                C(end+1, 1) = "        for e = reshape(res, 1, [])";
                C(end+1, 1) = "            if e.status == ""done""; yext{end+1} = figureYExtents(e.F, fspec); end %#ok<SAGROW>";
                C(end+1, 1) = "        end";
                C(end+1, 1) = "    catch";
                C(end+1, 1) = "    end";
                C(end+1, 1) = "end";
                C(end+1, 1) = "batchYLim = figureBatchYLim(yext);";
                bArg = ", BatchYLim=batchYLim";
                yArg = ", YShared=max([batchYLim.n])";
            end
            C(end+1, 1) = "lastSessions = sessions;";
            C(end+1, 1) = "for i = 1:nObs";
            C(end+1, 1) = "    try";
            C(end+1, 1) = "        [res, lastSessions, Fs] = figureSessionCompute(sources, sessions, fspec, Observation=obsT(i, :));";
            C(end+1, 1) = "    catch ME";
            C(end+1, 1) = "        res = struct('facet', ""all"", 'group', """", 'label', ""all"", 'F', [], 'status', ""error"", 'message', string(ME.message));";
            C(end+1, 1) = "        Fs = cell(1, height(sessions));";
            C(end+1, 1) = "    end";
            if withData
                C(end+1, 1) = "    perSession(i, :) = Fs;";
            end
            switch okind   % the file name's {Unit} (runSessionFigure's fileLabel)
                case "unit"
                    if ss.match == "mapping"
                        C(end+1, 1) = "    fl = string(obsT.label(i));   % the mapping's cell";
                    else
                        C(end+1, 1) = "    fl = ""site_ch"" + obsT.channel(i);";
                    end
                case "channel"
                    C(end+1, 1) = "    fl = ""ch"" + obsT.channel(i);";
                    C(end+1, 1) = "    if ~isfinite(obsT.channel(i)); fl = string(obsT.label(i)); end";
                otherwise
                    C(end+1, 1) = "    fl = ""dataset"";";
            end
            C(end+1, 1) = "    for e = reshape(res, 1, [])";
            C(end+1, 1) = "        q = find(string({E.label}) == e.label, 1);";
            C(end+1, 1) = "        if isempty(q)";
            C(end+1, 1) = "            E(end+1) = struct('label', e.label, 'files', strings(1, 0), 'images', {cell(1, 0)}, 'pages', strings(1, 0), ...";
            C(end+1, 1) = "                'done', 0, 'why', strings(1, 0), 'nError', 0, 'F', [], 'rows', zeros(1, 0)); %#ok<AGROW>";
            C(end+1, 1) = "            q = numel(E);";
            C(end+1, 1) = "        end";
            if withData
                C(end+1, 1) = "        results(end+1) = struct('index', i, 'observation', string(obsT.label(i)), 'facet', e.facet, 'group', e.group, ...";
                C(end+1, 1) = "            'label', e.label, 'status', e.status, 'message', e.message, 'F', e.F); %#ok<AGROW>";
            end
            C(end+1, 1) = "        if e.status ~= ""done""";
            C(end+1, 1) = "            E(q).why(end+1) = string(obsT.label(i)) + "": "" + e.message;";
            C(end+1, 1) = "            E(q).nError = E(q).nError + (e.status == ""error"");";
            C(end+1, 1) = "            continue";
            C(end+1, 1) = "        end";
            C(end+1, 1) = "        try";
            C(end+1, 1) = "            nameObs = struct('kind', obsT.kind(i), 'label', obsT.label(i), 'unitId', NaN, 'channel', obsT.channel(i), ...";
            C(end+1, 1) = "                'column', obsT.column(i), 'meta', table(fl, """", 'VariableNames', {'label', 'class'}), 'groupLabel', e.group);";
            C(end+1, 1) = "            fname = figureOutputName(exportOpts.FilenamePattern, e.facet, fspec, nameObs, i, nObs);";
            C(end+1, 1) = "            fbase = fname; kk = 1;";
            C(end+1, 1) = "            while any(lower(usedNames) == lower(fname)); kk = kk + 1; fname = fbase + ""_"" + kk; end";
            C(end+1, 1) = "            usedNames(end+1) = fname; %#ok<AGROW>";
            C(end+1, 1) = "            base = fullfile(folder, fname);";
            draws = doExport || withImages || withPages;
            if doExport
                C(end+1, 1) = "            want = base + ""."" + exportOpts.Formats;";
                C(end+1, 1) = "            kept = ~exportOpts.Overwrite && all(isfile(want));   % its files exist: not written again";
                C(end+1, 1) = "            if kept; E(q).files = [E(q).files want]; end";
            end
            if draws
                if doExport && ~withImages && ~withPages
                    C(end+1, 1) = "            if ~kept";
                    ind = "    ";
                else
                    ind = "";
                end
                D = strings(0, 1);
                D(end+1, 1) = "fig = newExportFigure(exportOpts, e.F, fspec);";
                D(end+1, 1) = "closer = onCleanup(@() close(fig));   % closes the page on a failure too";
                if withImages
                    D(end+1, 1) = "h = renderFigure(e.F, fspec, fig" + bArg + ");";
                else
                    D(end+1, 1) = "renderFigure(e.F, fspec, fig" + bArg + ");";
                end
                D(end+1, 1) = "written = strings(1, 0);";
                if doExport
                    D(end+1, 1) = "if ~kept";
                    D(end+1, 1) = "    written = exportFigure(fig, base, Format=exportOpts.Formats, Dpi=exportOpts.Dpi);";
                    D(end+1, 1) = "    E(q).files = [E(q).files written];";
                    D(end+1, 1) = "end";
                end
                if withImages
                    D(end+1, 1) = "E(q).images{end+1} = reportImage(fig, report, Title=h.title, Files=written);";
                end
                if withPages
                    D(end+1, 1) = "E(q).pages(end+1) = reportPdfPage(fig, report, Files=written);";
                end
                D(end+1, 1) = "clear closer";
                C = [C; "            " + ind + D];
                if ind ~= ""
                    C(end+1, 1) = "            end";
                end
            end
            C(end+1, 1) = "            E(q).done = E(q).done + 1;";
            C(end+1, 1) = "            E(q).rows(end+1) = i;";
            C(end+1, 1) = "            E(q).F = e.F;";
            C(end+1, 1) = "        catch ME";
            if draws
                C(end+1, 1) = "            clear closer   % the page a failure left open";
            end
            C(end+1, 1) = "            E(q).why(end+1) = string(obsT.label(i)) + "": "" + string(ME.message);";
            C(end+1, 1) = "            E(q).nError = E(q).nError + 1;";
            C(end+1, 1) = "        end";
            C(end+1, 1) = "    end";
            C(end+1, 1) = "end";
            C(end+1, 1) = "for q = 1:numel(E)";
            C(end+1, 1) = "    rspec = fspecKind;   % listed in the report under the figure's id (and the figure label)";
            C(end+1, 1) = "    if numel(E) > 1; rspec.id = fspec.id + "" ("" + E(q).label + "")""; end";
            C(end+1, 1) = "    if E(q).done == 0";
            C(end+1, 1) = "        msg = strjoin(E(q).why, ""; "");";
            C(end+1, 1) = "        if msg == """"; msg = ""no observation was drawn""; end";
            C(end+1, 1) = "        status = ""skipped"";";
            C(end+1, 1) = "        if E(q).nError > 0 && E(q).nError == numel(E(q).why); status = ""error""; end";
            if doReport
                C(end+1, 1) = "        report = addReportFigure(report, rspec, [], Status=status, Message=msg);";
            end
            C(end+1, 1) = "        fprintf('sessions: %s: %s %s (%s)\n', E(q).label, fspec.id, status, msg);";
            C(end+1, 1) = "        continue";
            C(end+1, 1) = "    end";
            if doReport
                drawn = "Files=E(q).files";
                if withImages; drawn = drawn + ", Images=E(q).images"; end
                if withPages; drawn = drawn + ", Pages=E(q).pages"; end
                C(end+1, 1) = "    report = addReportFigure(report, rspec, E(q).F, " + drawn + ", Caption=figureCaption(fspec, obsT(E(q).rows, :), Sessions=E(q).F.sessions" + yArg + "));";
            end
            C(end+1, 1) = "    fprintf('sessions: %s: %s done (%d observation(s), %d file(s))\n', E(q).label, fspec.id, E(q).done, numel(E(q).files));";
            C(end+1, 1) = "end";
            if withData
                C(end+1, 1) = "% --- the data file (Export.Data): every observation's merged and per-dataset figures ---";
                C(end+1, 1) = "if any([E.done] > 0)";
                C(end+1, 1) = "    try";
                C(end+1, 1) = "        S = struct('schema', ""ephys-analysis-session-figure/1"", 'figure', fspec.id, 'spec', fspec, 'sessions', lastSessions, ...";
                C(end+1, 1) = "            'observations', obsT, 'results', results, 'perSession', {perSession}, 'config', config, ...";
                C(end+1, 1) = "            'created', string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));";
                C(end+1, 1) = "        dname = figureFileName(exportOpts.Data.FilenamePattern, struct('Name', ""all"", 'Plot', fspec.id, 'Kind', ""figure"", ...";
                C(end+1, 1) = "            'Group', ""all"", 'Unit', ""all"", 'Index', 1));";
                C(end+1, 1) = "        dfile = fullfile(figureFileName(exportOpts.Data.Folder, tokens, Kind=""folder""), dname + "".mat"");";
                C(end+1, 1) = "        writeAnalysisData(dfile, S, MatVersion=exportOpts.Data.MatVersion, Overwrite=exportOpts.Overwrite);";
                C(end+1, 1) = "        fprintf('sessions: %s data file %s\n', fspec.id, dfile);";
                C(end+1, 1) = "    catch ME";
                C(end+1, 1) = "        fprintf(2, 'sessions: %s data file FAILED: %s\n', fspec.id, ME.message);";
                C(end+1, 1) = "    end";
                C(end+1, 1) = "end";
            end
            B = [B; "    " + C];
            B(end+1, 1) = "end";
            B(end+1, 1) = "for j = 1:numel(sources)   % free the sessions' spikes and signals";
            B(end+1, 1) = "    if ~isempty(sources{j}); sources{j}.outputs.clearCache(); end";
            B(end+1, 1) = "end";
            B = regexprep(B, '^\s+$', '');
        end

        function L = figureLines(id, k, doExport, doReport, withImages, withPages, batch)
            %figureLines  One figure on one dataset, a page per observation, as EphysAnalysisRunner.runDataset draws it.
            %   The figure's spec is fspec<K> (written above); figureCompute is
            %   what the runner's computeFigure calls, without its checkpoints.
            %   BATCH (default false): its "batch" panels are drawn at
            %   batchYLim<K> (measured above), its caption says so.
            if nargin < 7; batch = false; end
            bArg = "";
            yArg = "";
            if batch
                bArg = ", BatchYLim=batchYLim" + k;
                yArg = ", YShared=max([batchYLim" + k + ".n])";
            end
            B = strings(0, 1);
            B(end+1, 1) = "";
            B(end+1, 1) = "% --- " + id + " (figure) ---";
            B(end+1, 1) = "fspec = fspec" + k + ";";
            if doReport
                B(end+1, 1) = "fspecKind = fspec; fspecKind.kind = ""figure"";   % the report entry's kind";
            end
            B(end+1, 1) = "reason = figureSkipReason(src, fspec);   % what the dataset lacks for this figure";
            B(end+1, 1) = "if reason == """"";
            B(end+1, 1) = "    obsT = figureObservations(src, fspec);   % its units, channels, or the dataset: a page each";
            B(end+1, 1) = "    if height(obsT) == 0; reason = ""no observation""; end";
            B(end+1, 1) = "end";
            B(end+1, 1) = "if reason == """"";
            B(end+1, 1) = "    try";
            B(end+1, 1) = "        files = strings(1, 0);";
            if withImages; B(end+1, 1) = "        images = cell(1, 0);   % each observation's page as the HTML report embeds it"; end
            if withPages; B(end+1, 1) = "        pages = strings(1, 0);   % ... and as the PDF report holds it"; end
            B(end+1, 1) = "        nObs = height(obsT);";
            if doReport
                B(end+1, 1) = "        acalls = {};   % each observation's auROC calls, for the caption";
            end
            B(end+1, 1) = "        for i = 1:nObs";
            B(end+1, 1) = "            base = fullfile(folder, figureOutputName(exportOpts.FilenamePattern, name, fspec, obsT(i, :), i, nObs));";
            draws = doExport || withImages || withPages;
            if doExport
                B(end+1, 1) = "            want = base + ""."" + exportOpts.Formats;";
                B(end+1, 1) = "            kept = ~exportOpts.Overwrite && all(isfile(want));   % its files exist: not written again";
                B(end+1, 1) = "            if kept; files = [files want]; end %#ok<AGROW>";
                if ~withImages && ~withPages
                    B(end+1, 1) = "            if kept; continue; end   % ... nor computed";
                end
            end
            B(end+1, 1) = "            fres = figureCompute(src, fspec, Observation=obsT(i, :));   % that observation's data only";
            if doReport
                B(end+1, 1) = "            ac = figureAurocCalls(fres);";
                B(end+1, 1) = "            if ~isempty(ac); acalls{end+1} = ac; end %#ok<AGROW>";
            end
            if draws
                B(end+1, 1) = "            fig = newExportFigure(exportOpts, fres, fspec);   % a page grows with the arrangement's rows";
                B(end+1, 1) = "            closer = onCleanup(@() close(fig));   % closes the page on a failure too";
                if withImages
                    B(end+1, 1) = "            h = renderFigure(fres, fspec, fig" + bArg + ");";
                else
                    B(end+1, 1) = "            renderFigure(fres, fspec, fig" + bArg + ");";
                end
                B(end+1, 1) = "            written = strings(1, 0);";
                if doExport
                    B(end+1, 1) = "            if ~kept";
                    B(end+1, 1) = "                written = exportFigure(fig, base, Format=exportOpts.Formats, Dpi=exportOpts.Dpi);";
                    B(end+1, 1) = "                files = [files written]; %#ok<AGROW>";
                    B(end+1, 1) = "            end";
                end
                if withImages
                    B(end+1, 1) = "            images{end+1} = reportImage(fig, report, Title=h.title, Files=written); %#ok<AGROW>";
                end
                if withPages
                    B(end+1, 1) = "            pages(end+1) = reportPdfPage(fig, report, Files=written); %#ok<AGROW>";
                end
                B(end+1, 1) = "            clear closer";
            end
            B(end+1, 1) = "        end";
            if doReport
                drawn = "Files=files";
                if withImages; drawn = drawn + ", Images=images"; end
                if withPages; drawn = drawn + ", Pages=pages"; end
                B(end+1, 1) = "        report = addReportFigure(report, fspecKind, fres, " + drawn + ", Observations=obsT, ...   % each page's observation: Report.Order";
                B(end+1, 1) = "            Caption=figureCaption(fspec, obsT, Dataset=name, Auroc=acalls" + yArg + "));";
            end
            B(end+1, 1) = "        fprintf('%s: %s done (%d observation(s), %d file(s))\n', name, fspec.id, nObs, numel(files));";
            B(end+1, 1) = "    catch ME";
            if draws
                B(end+1, 1) = "        clear closer   % the page a failure left open";
            end
            if doReport
                B(end+1, 1) = "        report = addReportFigure(report, fspecKind, [], Status=""error"", Message=string(ME.message));";
            end
            B(end+1, 1) = "        fprintf(2, '%s: %s FAILED: %s\n', name, fspec.id, ME.message);";
            B(end+1, 1) = "    end";
            B(end+1, 1) = "else";
            if doReport
                B(end+1, 1) = "    report = addReportFigure(report, fspecKind, [], Status=""skipped"", Message=reason);";
            end
            B(end+1, 1) = "    fprintf('%s: %s skipped (%s)\n', name, fspec.id, reason);";
            B(end+1, 1) = "end";
            L = "    " + B;
            L(1) = "";
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
