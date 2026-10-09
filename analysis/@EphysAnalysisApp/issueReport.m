function body = issueReport(obj, kind, opts)
%issueReport  Markdown body of a GitHub issue about this session.
%   BODY = issueReport(OBJ, KIND) assembles the report the Help menu's
%   "Report an issue" and "Request a feature" items send to GitHub (see
%   onReportIssue, issueURL). KIND is "bug" or "feature" and only chooses
%   the headings the description goes under.
%
%   Name-value arguments
%     Description  what the user typed; it goes under the first heading
%     System       MATLAB release, platform, cores, memory, GPU, the
%                  installed toolboxes, the version and git commit of this
%                  code (ephysVersion) and the repository folder (default true)
%     Config       the working config as the controls hold it now
%                  (gatherConfig): name, file, source, plots, datasets, and
%                  the whole config as JSON (default true)
%     Logs         the tail of the Log tab (default true)
%     MaxLogLines  lines kept from the end of the log (default 60); a log
%                  that is cut says so and how many lines it had.
%
%   Nothing is collected that the dialog does not show: what this returns is
%   exactly what onReportIssue previews, copies to the clipboard and sends.
%   No section is included unless its option is true, so the user can leave
%   the config (which carries their file paths) out.
arguments
    obj (1,1) EphysAnalysisApp
    kind (1,1) string {mustBeMember(kind, ["bug", "feature"])}
    opts.Description (1,1) string = ""
    opts.System (1,1) logical = true
    opts.Config (1,1) logical = true
    opts.Logs (1,1) logical = true
    opts.MaxLogLines (1,1) double = 60
end

L = IssueReport.lead(kind, opts.Description);

if opts.System
    L = [L; IssueReport.details("System", IssueReport.systemLines())];
end
if opts.Config
    cfg = workingConfig(obj);
    L = [L; IssueReport.details("Analysis config", configLines(obj, cfg))];
    L = [L; IssueReport.details("Config JSON", configJSON(cfg))];
end
if opts.Logs
    L = [L; IssueReport.details("Log tab", logLines(obj, opts.MaxLogLines), false)];
end

L = [L; IssueReport.trailer("EphysAnalysisApp")];
body = join(L, newline);
end


function cfg = workingConfig(obj)
%workingConfig  The config as the controls hold it now, unsaved edits and all.
try
    cfg = obj.gatherConfig();
catch
    cfg = obj.Config;   % a control the gatherers reject: report the last good one
end
end


function L = configLines(obj, cfg)
%configLines  What the config does, as the controls hold it right now.
kv = @IssueReport.kv;
file = cfg.File;
if file == ""; file = "(never saved)"; end
dirty = "no";
if cfg.File == "" || ~isequaln(cfg.toStruct(), obj.SavedConfigStruct); dirty = "yes"; end
S = cfg.Source;
L = [kv("Config name", cfg.Name); kv("Config file", file); kv("Unsaved edits", dirty); ...
    kv("Source mode", S.Mode)];
if S.Mode == "project"
    L = [L; kv("Project root", S.Root); kv("Output root", S.OutputRoot); ...
        kv("Selection", S.Selection)];
else
    L = [L; kv("Output folders", string(numel(S.Folders)))];
end
plots = cfg.Plots;
if isempty(plots)
    L = [L; kv("Plots", "none")];
else
    on = [plots.enabled];
    L = [L; kv("Plots", sprintf('%d, %d enabled', numel(plots), nnz(on))); ...
        kv("Plot kinds", join(unique(string({plots.kind})), ", "))];
end
r = obj.Runner;
if isempty(r) || isempty(r.Keys)
    L = [L; kv("Datasets", "none scanned")];
else
    L = [L; kv("Datasets", sprintf('%d scanned, %d ticked', numel(r.Keys), nnz(obj.Ticked)))];
    if obj.ActiveIdx >= 1 && obj.ActiveIdx <= numel(r.Names)
        L = [L; kv("Active dataset", r.Names(obj.ActiveIdx))];
    end
end
try
    L = [L; kv("Selected tab", string(obj.Tabs.SelectedTab.Title))];
catch
end
L = [L; kv("Run in progress", string(obj.Running))];
end


function L = configJSON(cfg)
%configJSON  The config itself, written the way Save config writes it.
%   Through writeJsonFile, so the block is the config file the user would
%   have saved (Inf / NaN kept as strings rather than turned into null) and
%   the maintainer can reproduce the run from it.
file = string(tempname) + ".json";
try
    writeJsonFile(file, cfg.toStruct(), NonFinite="string");
    L = splitlines(string(fileread(file)));
    delete(file);
    return
catch
    if isfile(file); delete(file); end
end
try
    L = splitlines(string(jsonencode(cfg.toStruct(), PrettyPrint=true)));
catch ME
    L = "(the config could not be written as JSON: " + string(ME.message) + ")";
end
end


function L = logLines(obj, maxLines)
%logLines  The tail of the Log tab, saying how many lines it had.
area = obj.LogArea;
if isempty(area) || ~isvalid(area); L = "_The log was empty._"; return; end
v = string(area.Value);
v = v(:);
last = find(strlength(strip(v)) > 0, 1, 'last');
if isempty(last); L = "_The log was empty._"; return; end
txt = v(1:last);
tail = txt(max(1, numel(txt) - maxLines + 1):end);
head = "**Log tab** (";
if numel(tail) < numel(txt)
    head = head + "the last " + numel(tail) + " of " + numel(txt) + " lines)";
else
    head = head + numel(txt) + " lines)";
end
L = [""; head; ""; "```text"; tail; "```"];
end
