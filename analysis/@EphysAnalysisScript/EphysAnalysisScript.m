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
    %                                 figureCaption. After the datasets, a
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
                L = [L; EphysAnalysisScript.figureLines(fids(k), k, X.Enabled, doReport, withImages, withPages)]; %#ok<AGROW>
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
                    D(end+1, 1) = "h = renderFigure(e.F, fspec, fig);";
                else
                    D(end+1, 1) = "renderFigure(e.F, fspec, fig);";
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
                C(end+1, 1) = "    report = addReportFigure(report, rspec, E(q).F, " + drawn + ", Caption=figureCaption(fspec, obsT(E(q).rows, :), Sessions=E(q).F.sessions));";
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

        function L = figureLines(id, k, doExport, doReport, withImages, withPages)
            %figureLines  One figure on one dataset, a page per observation, as EphysAnalysisRunner.runDataset draws it.
            %   The figure's spec is fspec<K> (written above); figureCompute is
            %   what the runner's computeFigure calls, without its checkpoints.
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
                    B(end+1, 1) = "            h = renderFigure(fres, fspec, fig);";
                else
                    B(end+1, 1) = "            renderFigure(fres, fspec, fig);";
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
                B(end+1, 1) = "        report = addReportFigure(report, fspecKind, fres, " + drawn + ", Caption=figureCaption(fspec, obsT, Dataset=name, Auroc=acalls));";
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
