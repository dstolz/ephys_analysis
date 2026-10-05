function issues = validate(obj, opts)
%validate  Check an analysis config for problems before it runs.
%   ISSUES = cfg.validate() returns a table (Section, Field, Severity,
%   Message); Severity "error" means the run cannot start, "warning" that
%   part of it may not do what is meant. An empty table means clean.
%
%   Checked
%     Source    Mode; Root exists (project) or every folder does (folders);
%               NamePattern parses; a "list" selection names datasets
%     Defaults  the event reference, window and selection are valid (a
%               filter that does not parse is a warning: it is checked
%               against each dataset's trials when it runs)
%     Plots     at least one enabled; ids stay distinct as file names
%               ({Plot} replaces characters outside A-Z a-z 0-9 _ - . by
%               "_", and Windows ignores case); kind is one of Kinds; source fits the
%               kind (units / detected for spike kinds, LFP / MUA / SPIKE /
%               AUX for signal kinds); layout fits the kind; "between"
%               windows only for rate / tuning / corrmap, and with a stop
%               event; tuning names its parameter; groupBy <= 2; BinSec > 0;
%               pre <= post; baseline mode fits the kind and its window is
%               [b0 b1] with b0 < b1; psth histStyle, normalize,
%               fillAlpha (0-1 or NaN) and stackSpacing (> 0); probemap value;
%               heatmap order ("modulation" with an auROC baseline);
%               corrmap metric and correlation; a baseline Mode "auroc"
%               (psth and heatmap of spikes) and its auroc settings
%               (method, windows, whole-bin window and step, modulation
%               window, cutoff, threshold, test, nResamples, correction,
%               alpha, modulatedOnly with a cutoff, the toolbox); an
%               enabled units.response test (test, param, windows,
%               direction, correction, alpha, test "auroc"'s settings, and
%               the Statistics and Machine Learning Toolbox it needs);
%               a waveform mode other than off: its location, scale (0-3)
%               and maxSpikes, and a warning when the plot draws no unit
%               tiles (a raster, a PSTH or tuning grid of spikes); style
%               values
%     Export    formats are png / eps / svg / pdf; Dpi, FigureSizeCm; the
%               folder and file-name patterns use known tokens; a warning
%               when the files of two enabled plots, or of two datasets,
%               would get the same names (no {Plot} -- or {Kind} for plots
%               of different kinds -- no {Name} / {OutputFolder})
%     Report    Format html / pdf / both; EmbedFormat png / svg; Dpi;
%               FileName; the folder pattern
%
%   Options: CheckPaths (default true) also checks that folders exist.
%
%   See also EphysAnalysisConfig, EphysAnalysisRunner.plan, figureFileName.

arguments
    obj (1,1) EphysAnalysisConfig
    opts.CheckPaths (1,1) logical = true
end

Section = strings(0, 1); Field = strings(0, 1); Severity = strings(0, 1); Message = strings(0, 1);
    function add(sec, field, sev, msg)
        Section(end+1, 1) = sec; Field(end+1, 1) = field; Severity(end+1, 1) = sev; Message(end+1, 1) = msg;
    end

% --- Source ------------------------------------------------------------------------
S = obj.Source;
if ~ismember(S.Mode, ["project" "folders"])
    add("Source", "Mode", "error", "Mode must be ""project"" or ""folders"".");
elseif S.Mode == "project"
    if S.Root == ""
        add("Source", "Root", "error", "The project root is empty.");
    elseif opts.CheckPaths && ~isfolder(S.Root)
        add("Source", "Root", "error", "The project root does not exist: " + S.Root);
    end
    if S.OutputRoot ~= "" && opts.CheckPaths && ~isfolder(S.OutputRoot)
        add("Source", "OutputRoot", "warning", "The output root does not exist: " + S.OutputRoot);
    end
    if ~ismember(S.Selection, ["all" "list"])
        add("Source", "Selection", "error", "Selection must be ""all"" or ""list"".");
    elseif S.Selection == "list" && isempty(S.Datasets)
        add("Source", "Datasets", "warning", "Selection is ""list"" but no datasets are listed; nothing will run.");
    end
    try
        parseNameTokens("", S.NamePattern);
    catch ME
        add("Source", "NamePattern", "error", string(ME.message));
    end
    if ~ismember(S.Recordings, ["concatenate" "separate" "single"])
        add("Source", "Recordings", "error", "Recordings must be ""concatenate"", ""separate"" or ""single"".");
    end
else
    if isempty(S.Folders)
        add("Source", "Folders", "error", "Mode is ""folders"" but no folders are listed.");
    elseif opts.CheckPaths
        for f = S.Folders
            if ~isfolder(f); add("Source", "Folders", "error", "Folder not found: " + f); end
        end
    end
end

% --- Defaults ------------------------------------------------------------------------
D = obj.Defaults;
checkRef(D.EventRef, "Defaults", "EventRef");
checkWindow(D.Window, "Defaults", "Window");
checkSelection(D.Selection, "Defaults", "Selection");

% --- Plots -----------------------------------------------------------------------------
K = EphysAnalysisConfig.plotKinds();
if isempty(obj.Plots) || ~any([obj.Plots.enabled])
    add("Plots", "enabled", "error", "No plot is enabled.");
end
ids = obj.plotIds();
key = lower(regexprep(ids, '[^\w\-\.]', '_'));   % the id as {Plot} writes it (figureFileName), case-blind (Windows)
for u = unique(key)
    same = ids(key == u);
    if numel(same) > 1
        add("Plots", same(end) + ".id", "error", "Plot ids " + strjoin("""" + same + """", " and ") + ...
            " name the same files: {Plot} replaces characters outside A-Z a-z 0-9 _ - . by ""_"", and Windows ignores case.");
    end
end
for k = 1:numel(obj.Plots)
    p = obj.Plots(k);
    f0 = p.id;
    if ~ismember(p.kind, EphysAnalysisConfig.Kinds)
        add("Plots", f0 + ".kind", "error", "Unknown kind """ + p.kind + """ (kinds: " + strjoin(EphysAnalysisConfig.Kinds, ", ") + ").");
        continue
    end
    row = K(K.Kind == p.kind, :);
    if ~ismember(p.source, row.Sources{1})
        add("Plots", f0 + ".source", "error", sprintf("A %s plot reads %s, not ""%s"".", p.kind, strjoin(row.Sources{1}, " / "), p.source));
    end
    if p.layout ~= "" && ~ismember(p.layout, row.Layouts{1})
        add("Plots", f0 + ".layout", "error", sprintf("A %s plot has layouts %s, not ""%s"".", p.kind, strjoin(row.Layouts{1}, " / "), p.layout));
    end
    if row.Aligned
        if isstruct(p.ref); checkRef(p.ref, "Plots", f0 + ".ref"); end
        if isstruct(p.window); checkWindow(p.window, "Plots", f0 + ".window"); end
        if isstruct(p.selection); checkSelection(p.selection, "Plots", f0 + ".selection"); end
        w = p.window;
        if isequal(w, "default"); w = D.Window; end
        if ~ismember(w.mode, row.WindowModes{1})
            between = K.Kind(cellfun(@(m) ismember("between", m), K.WindowModes));
            add("Plots", f0 + ".window", "error", sprintf("A %s plot needs a fixed window (""between"" windows are for %s plots).", ...
                p.kind, strjoin(between, " / ")));
        end
    end
    if ~ismember(p.measure, ["rate" "count" "probability"])
        add("Plots", f0 + ".measure", "error", "The measure is rate, count or probability.");
    end
    if p.kind == "tuning" && strtrim(p.param) == ""
        add("Plots", f0 + ".param", "error", "A tuning plot needs param: the trial parameter on its x axis.");
    end
    if ismember(p.kind, ["psth" "raster"]) || (p.kind == "heatmap" && ismember(p.source, EphysAnalysisConfig.SpikeSources)) ...
            || (p.kind == "corrmap" && p.metric == "peak")
        if ~(p.bins.BinSec > 0); add("Plots", f0 + ".bins.BinSec", "error", "BinSec must be positive."); end
        if ~(p.bins.SmoothSec >= 0); add("Plots", f0 + ".bins.SmoothSec", "error", "SmoothSec must be >= 0."); end
    end
    switch p.kind
        case {"psth" "raster" "heatmap"}
            modes = ["none" "subtract" "zscore" "percent"];
            if p.kind ~= "raster"; modes(end+1) = "auroc"; end
            if ismember(p.source, EphysAnalysisConfig.SignalSources); modes = ["none" "subtract"]; end
        case {"rate" "tuning"}
            modes = ["none" "subtract" "ratio" "zscore"];
        case {"evoked" "corrmap"}
            modes = ["none" "subtract"];
        otherwise
            modes = "none";
    end
    bm = p.baseline;
    if ~ismember(bm.Mode, modes)
        add("Plots", f0 + ".baseline.Mode", "error", sprintf("A %s plot's baseline Mode is one of %s, not ""%s"".", p.kind, strjoin(modes, ", "), bm.Mode));
    elseif bm.Mode ~= "none" && ~(numel(bm.Window) == 2 && bm.Window(2) > bm.Window(1))
        add("Plots", f0 + ".baseline.Window", "error", "The baseline window must be [b0 b1] with b0 < b1.");
    end
    if bm.Mode == "auroc" && ismember(bm.Mode, modes)
        checkAuroc(p.auroc, p.bins.BinSec, "Plots", f0 + ".auroc", true);
    end
    if p.kind == "psth"
        if ~ismember(p.histStyle, ["bar" "line"])
            add("Plots", f0 + ".histStyle", "error", "A PSTH is drawn as bar or line.");
        end
        if ~ismember(p.normalize, ["none" "unitPeak" "groupPeak"])
            add("Plots", f0 + ".normalize", "error", "A PSTH's normalize is none, unitPeak or groupPeak.");
        end
        if ~(isnan(p.fillAlpha) || (p.fillAlpha >= 0 && p.fillAlpha <= 1))
            add("Plots", f0 + ".fillAlpha", "error", "fillAlpha is an opacity from 0 to 1 (NaN = automatic).");
        end
        if ~(p.stackSpacing > 0 && isfinite(p.stackSpacing))
            add("Plots", f0 + ".stackSpacing", "error", "stackSpacing must be positive (1 = the tallest PSTH reaches the next row).");
        end
    end
    if p.kind == "probemap" && ~ismember(p.value, ["rate" "nSpikes" "nUnits"])
        add("Plots", f0 + ".value", "error", "A probe map shows rate, nSpikes or nUnits.");
    end
    if p.kind == "heatmap" && ~ismember(p.order, ["probe" "peak" "modulation"])
        add("Plots", f0 + ".order", "error", "A heatmap orders its rows by probe (the style's sort options), peak or modulation.");
    elseif p.kind == "heatmap" && p.order == "modulation" && bm.Mode ~= "auroc"
        add("Plots", f0 + ".order", "error", "A heatmap's rows go in modulation order only with the auROC baseline (baseline Mode ""auroc"").");
    end
    if p.kind == "corrmap"
        if ~ismember(p.metric, ["mean" "peak"])
            add("Plots", f0 + ".metric", "error", "A unit correlation map correlates each epoch's mean or peak rate.");
        end
        if ~ismember(p.correlation, ["pearson" "spearman"])
            add("Plots", f0 + ".correlation", "error", "A unit correlation map's correlation is pearson or spearman.");
        end
    end
    if ~(p.units.maxUnits >= 1)
        add("Plots", f0 + ".units.maxUnits", "error", "maxUnits must be >= 1 (Inf = all).");
    end
    rs = p.units.response;
    if rs.enabled && ismember(p.source, EphysAnalysisConfig.SpikeSources)
        r0 = f0 + ".units.response";
        if ~ismember(rs.test, ["evoked" "tuning" "either" "both" "auroc"])
            add("Plots", r0 + ".test", "error", "The response test is evoked, tuning, either, both or auroc.");
        elseif rs.test == "auroc"
            checkAuroc(rs.auroc, rs.auroc.binSec, "Plots", r0 + ".auroc", false);
        elseif rs.test ~= "evoked" && rs.param == ""
            add("Plots", r0 + ".param", "error", "The tuning test needs the trial parameter (param).");
        end
        for wf = ["baseline" "window"]
            if ~(numel(rs.(wf)) == 2 && all(isfinite(rs.(wf))) && rs.(wf)(2) > rs.(wf)(1))
                add("Plots", r0 + "." + wf, "error", "The response test's " + wf + " must be [from to] with from < to (s from the event).");
            end
        end
        if ~ismember(rs.direction, ["any" "excited" "suppressed"])
            add("Plots", r0 + ".direction", "error", "The response direction is any, excited or suppressed.");
        end
        if ~ismember(rs.correction, ["bh" "holm" "bonferroni" "none"])
            add("Plots", r0 + ".correction", "error", "The correction is bh, holm, bonferroni or none.");
        end
        if ~(rs.alpha > 0 && rs.alpha <= 1)
            add("Plots", r0 + ".alpha", "error", "alpha must be in (0, 1].");
        end
        if ~(license('test', 'Statistics_Toolbox') && exist('signrank', 'file'))
            add("Plots", r0 + ".enabled", "error", "The response test needs the Statistics and Machine Learning Toolbox (signrank, kruskalwallis).");
        end
    end
    wv = p.waveform;
    w0 = f0 + ".waveform";
    if ~ismember(wv.mode, ["off" "mean" "subsample" "both"])
        add("Plots", w0 + ".mode", "error", "The waveform mode is off, mean, subsample or both.");
    elseif wv.mode ~= "off"
        if ~ismember(wv.location, EphysAnalysisConfig.WaveformLocations)
            add("Plots", w0 + ".location", "error", "The waveform location is one of " + ...
                strjoin(EphysAnalysisConfig.WaveformLocations, ", ") + ".");
        end
        if ~(wv.scale > 0 && wv.scale <= 3)
            add("Plots", w0 + ".scale", "error", "The waveform scale is above 0 and at most 3 (1 = a third of the tile).");
        end
        if ~(wv.maxSpikes >= 1 && wv.maxSpikes == round(wv.maxSpikes))
            add("Plots", w0 + ".maxSpikes", "error", "maxSpikes is a whole number of spikes, at least 1.");
        end
        if ~(ismember(p.source, EphysAnalysisConfig.SpikeSources) && (p.kind == "raster" || ...
                (ismember(p.kind, ["psth" "tuning"]) && p.layout ~= "overlay")))
            add("Plots", w0 + ".mode", "warning", "Unit waveforms are drawn in the tiles of a raster, or of a " + ...
                "PSTH or tuning grid, of spikes; this plot draws none.");
        end
    end
    st = p.style;
    if ~(st.MaxTiles >= 1); add("Plots", f0 + ".style.MaxTiles", "error", "MaxTiles must be >= 1."); end
    if ~ismember(st.TileSpacing, ["loose" "compact" "tight" "none"])
        add("Plots", f0 + ".style.TileSpacing", "error", "TileSpacing is loose, compact, tight or none.");
    end
    if ~(st.FontSize > 0);  add("Plots", f0 + ".style.FontSize", "error", "FontSize must be positive."); end
    if ~(st.LineWidth > 0); add("Plots", f0 + ".style.LineWidth", "error", "LineWidth must be positive."); end
    if ~(st.SiteSize > 0);  add("Plots", f0 + ".style.SiteSize", "error", "SiteSize must be positive."); end
    for cm = ["Colormap" "HeatColormap"]
        if ~(cm == "Colormap" && (st.(cm) == "lines" || isColor(st.(cm)))) && ~(cm == "HeatColormap" && st.(cm) == "") ...
                && ~ismember(exist(char(st.(cm))), [2 5]) %#ok<EXIST>
            what = "colormap function";
            if cm == "Colormap"; what = "colormap function or colour"; end
            add("Plots", f0 + ".style." + cm, "warning", "No " + what + " """ + st.(cm) + """; the default is used.");
        end
    end
end

% --- Export -----------------------------------------------------------------------------
X = obj.Export;
if X.Enabled && isempty(X.Formats)
    add("Export", "Formats", "error", "Export is enabled but no format is chosen (png, eps, svg, pdf).");
end
bad = setdiff(X.Formats, ["png" "eps" "svg" "pdf"]);
if ~isempty(bad)
    add("Export", "Formats", "error", "Unknown format(s) " + strjoin(bad, ", ") + " (png, eps, svg, pdf).");
end
if ~(X.Dpi > 0); add("Export", "Dpi", "error", "Dpi must be positive."); end
if ~(numel(X.FigureSizeCm) == 2 && all(X.FigureSizeCm > 0))
    add("Export", "FigureSizeCm", "error", "FigureSizeCm must be [width height] > 0.");
end
checkPattern(X.FilenamePattern, "file", "Export", "FilenamePattern");
checkPattern(X.Folder, "folder", "Export", "Folder");
on = obj.Plots([obj.Plots.enabled]);
if numel(on) > 1 && ~contains(X.FilenamePattern, "{Plot}") ...
        && ~(contains(X.FilenamePattern, "{Kind}") && numel(unique([on.kind])) == numel(on))
    add("Export", "FilenamePattern", "warning", sprintf("The file-name pattern has no {Plot}, so the %d enabled plots' files overwrite each other.", numel(on)));
end
if ~contains(X.Folder, ["{OutputFolder}" "{Name}"]) && ~contains(X.FilenamePattern, "{Name}") ...
        && ~(S.Mode == "folders" && numel(S.Folders) <= 1)
    add("Export", "Folder", "warning", "Neither the export folder nor the file-name pattern names the dataset ({OutputFolder} or {Name}), so the datasets' files overwrite each other.");
end

% --- Report -------------------------------------------------------------------------------
P = obj.Report;
if ~ismember(P.Format, ["html" "pdf" "both"])
    add("Report", "Format", "error", "Format must be html, pdf or both.");
end
if ~ismember(P.EmbedFormat, ["png" "svg"])
    add("Report", "EmbedFormat", "error", "EmbedFormat must be png or svg.");
end
if ~(P.Dpi > 0); add("Report", "Dpi", "error", "Dpi must be positive."); end
if strtrim(P.FileName) == "" || ~isempty(regexp(P.FileName, '[\\/:*?"<>|]', 'once'))
    add("Report", "FileName", "error", "FileName must be a plain file name (no folder, no \ / : * ? "" < > |).");
end
checkPattern(P.Folder, "folder", "Report", "Folder");
if ~P.PerDataset && contains(P.Folder, "{OutputFolder}")
    add("Report", "Folder", "warning", "{OutputFolder} is one dataset's folder; a report over every dataset goes to the first dataset's.");
end

issues = table(Section, Field, Severity, Message);

    function checkRef(r, sec, field)
        try
            eventRef(r);
        catch ME
            add(sec, field, "error", string(ME.message));
        end
    end

    function checkWindow(w, sec, field)
        try
            epochWindow(w);
        catch ME
            add(sec, field, "error", string(ME.message));
        end
    end

    function checkAuroc(a, binSec, sec, field, isPlot)
        %checkAuroc  A plot's auroc settings (ISPLOT) or a response test's.
        if ~ismember(a.method, ["psth" "epochs"]); add(sec, field + ".method", "error", "The auROC method is psth or epochs."); end
        if ~ismember(a.windows, ["tiled" "sliding"]); add(sec, field + ".windows", "error", "The auROC windows are tiled or sliding."); end
        whole = @(x) binSec > 0 && x / binSec >= 1 - 1e-6 && abs(x / binSec - round(x / binSec)) < 1e-6;
        if ~whole(a.windowSec)
            add(sec, field + ".windowSec", "error", sprintf("The auROC window (%g s) must be a whole number of %g s bins.", a.windowSec, binSec));
        end
        if a.windows == "sliding" && ~whole(a.stepSec)
            add(sec, field + ".stepSec", "error", sprintf("The sliding step (%g s) must be a whole number of %g s bins.", a.stepSec, binSec));
        end
        if ~ismember(a.cutoff, ["ci" "fixed" "test" "none"])
            add(sec, field + ".cutoff", "error", "The auROC cutoff is ci, fixed, test or none.");
        elseif ~isPlot && a.cutoff == "none"
            add(sec, field + ".cutoff", "error", "The auROC response test needs a cutoff (ci, fixed or test) to call units modulated.");
        end
        if a.cutoff == "fixed" && ~(a.threshold >= 0 && a.threshold < 0.5)
            add(sec, field + ".threshold", "error", "The threshold is |auROC - 0.5|, from 0 up to (not including) 0.5.");
        end
        if a.cutoff == "test"
            if ~ismember(a.test, ["bootstrap" "ranksum" "shuffle"])
                add(sec, field + ".test", "error", "The auROC test is bootstrap, ranksum or shuffle.");
            elseif a.test ~= "ranksum" && ~(a.nResamples >= 1 && a.nResamples == round(a.nResamples))
                add(sec, field + ".nResamples", "error", "nResamples must be a whole number >= 1.");
            end
        end
        if isPlot
            m = a.modulationWindow;
            if ~(numel(m) == 2 && all(isfinite(m)) && m(2) > m(1))
                add(sec, field + ".modulationWindow", "error", "The modulation window must be [m0 m1] with m0 < m1 (s from the event).");
            end
            if a.cutoff == "test"
                if ~ismember(a.correction, ["bh" "holm" "bonferroni" "none"])
                    add(sec, field + ".correction", "error", "The correction is bh, holm, bonferroni or none.");
                end
                if ~(a.alpha > 0 && a.alpha <= 1); add(sec, field + ".alpha", "error", "alpha must be in (0, 1]."); end
            end
            if a.modulatedOnly && a.cutoff == "none"
                add(sec, field + ".modulatedOnly", "error", "Modulated units only needs a cutoff (ci, fixed or test) to call units modulated.");
            end
        end
        if ~(license('test', 'Statistics_Toolbox') && exist('tiedrank', 'file'))
            add(sec, field, "error", "auROC needs the Statistics and Machine Learning Toolbox (tiedrank, tinv, ranksum).");
        end
    end

    function checkSelection(s, sec, field)
        try
            trialSelection(s);
        catch ME
            if ME.identifier == "trialSelection:BadFilter"
                add(sec, field + ".filter", "warning", string(ME.message));
            else
                add(sec, field, "error", string(ME.message));
            end
        end
    end

    function checkPattern(pattern, kind, sec, field)
        if kind == "file"
            t = struct('Name', "n", 'Plot', "p", 'Kind', "k", 'Group', "g", 'Unit', "u", 'Index', 1);
        else
            t = struct('OutputFolder', "o", 'OutputRoot', "r", 'Root', "r", 'Name', "n");
        end
        try
            figureFileName(pattern, t, Kind=kind);
        catch ME
            add(sec, field, "error", string(ME.message));
        end
        if kind == "file" && strtrim(pattern) == ""
            add(sec, field, "error", "The file-name pattern is empty.");
        end
    end
end


function tf = isColor(name)
%isColor  True for a colour name or hex code (groupPalette gives every group that colour).
try
    validatecolor(name);
    tf = true;
catch
    tf = false;
end
end
