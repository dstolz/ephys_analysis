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
%     Plots     at least one enabled; kind is one of Kinds; source fits the
%               kind (units / detected for spike kinds, LFP / MUA / SPIKE /
%               AUX for signal kinds); layout fits the kind; "between"
%               windows only for rate / tuning, and with a stop event; tuning
%               names its parameter; groupBy <= 2; BinSec > 0; pre <= post;
%               baseline mode fits the kind and its window is [b0 b1] with
%               b0 < b1; psth histStyle; probemap value; heatmap order;
%               style values
%     Export    formats are png / eps / svg / pdf; Dpi, FigureSizeCm; the
%               folder and file-name patterns use known tokens
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
            add("Plots", f0 + ".window", "error", sprintf("A %s plot needs a fixed window (""between"" windows are for rate and tuning plots).", p.kind));
        end
    end
    if p.kind == "tuning" && strtrim(p.param) == ""
        add("Plots", f0 + ".param", "error", "A tuning plot needs param: the trial parameter on its x axis.");
    end
    if ismember(p.kind, ["psth" "raster"]) || (p.kind == "heatmap" && ismember(p.source, EphysAnalysisConfig.SpikeSources))
        if ~(p.bins.BinSec > 0); add("Plots", f0 + ".bins.BinSec", "error", "BinSec must be positive."); end
        if ~(p.bins.SmoothSec >= 0); add("Plots", f0 + ".bins.SmoothSec", "error", "SmoothSec must be >= 0."); end
    end
    switch p.kind
        case {"psth" "raster" "heatmap"}
            modes = ["none" "subtract" "zscore" "percent"];
            if ismember(p.source, EphysAnalysisConfig.SignalSources); modes = ["none" "subtract"]; end
        case {"rate" "tuning"}
            modes = ["none" "subtract" "ratio" "zscore"];
        case "evoked"
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
    if p.kind == "psth" && ~ismember(p.histStyle, ["bar" "line"])
        add("Plots", f0 + ".histStyle", "error", "A PSTH is drawn as bar or line.");
    end
    if p.kind == "probemap" && ~ismember(p.value, ["rate" "nSpikes" "nUnits"])
        add("Plots", f0 + ".value", "error", "A probe map shows rate, nSpikes or nUnits.");
    end
    if p.kind == "heatmap" && ~ismember(p.order, ["depth" "channel" "peak"])
        add("Plots", f0 + ".order", "error", "A heatmap orders its rows by depth, channel or peak.");
    end
    if ~(p.units.maxUnits >= 1)
        add("Plots", f0 + ".units.maxUnits", "error", "maxUnits must be >= 1 (Inf = all).");
    end
    st = p.style;
    if ~(st.MaxTiles >= 1); add("Plots", f0 + ".style.MaxTiles", "error", "MaxTiles must be >= 1."); end
    if ~(st.FontSize > 0);  add("Plots", f0 + ".style.FontSize", "error", "FontSize must be positive."); end
    if ~(st.LineWidth > 0); add("Plots", f0 + ".style.LineWidth", "error", "LineWidth must be positive."); end
    for cm = ["Colormap" "HeatColormap"]
        if ~(cm == "Colormap" && st.(cm) == "lines") && ~ismember(exist(char(st.(cm))), [2 5]) %#ok<EXIST>
            add("Plots", f0 + ".style." + cm, "warning", "No colormap function """ + st.(cm) + """; the default is used.");
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
