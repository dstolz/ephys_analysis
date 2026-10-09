function body = issueReport(obj, kind, opts)
%issueReport  Markdown body of a GitHub issue about this session.
%   BODY = issueReport(OBJ, KIND) assembles the report the Help menu's
%   "Report an issue" and "Request a feature" items send to GitHub (see
%   onReportIssue, issueURL). KIND is "bug" or "feature" and only chooses
%   the headings the description goes under.
%
%   Name-value arguments
%     Description  what the user typed; it goes under the first heading
%     System       MATLAB release, platform, cores, memory, GPU, the Python
%                  interpreter the Sorting tab uses, the installed toolboxes,
%                  the version and git commit of this code (ephysVersion)
%                  and the repository folder (default true)
%     Config       the working config as the controls hold it now
%                  (gatherConfig): name, file, enabled steps, roots, dataset
%                  counts, and the whole config as JSON (default true)
%     Logs         the tail of the Run, Kilosort and Copy logs and the last
%                  run error with its stack (LastError) (default true)
%     MaxLogLines  lines kept from the end of each log (default 60). Every
%                  log that is cut says so and how many lines it had.
%
%   Nothing is collected that the dialog does not show: what this returns is
%   exactly what onReportIssue previews, copies to the clipboard and sends.
%   No section is included unless its option is true, so the user can leave
%   the config (which carries their file paths) out.
arguments
    obj (1,1) EphysPipelineApp
    kind (1,1) string {mustBeMember(kind, ["bug", "feature"])}
    opts.Description (1,1) string = ""
    opts.System (1,1) logical = true
    opts.Config (1,1) logical = true
    opts.Logs (1,1) logical = true
    opts.MaxLogLines (1,1) double = 60
end

L = IssueReport.lead(kind, opts.Description);

if opts.System
    L = [L; IssueReport.details("System", IssueReport.systemLines(pythonLines(obj)))];
end
if opts.Config
    cfg = workingConfig(obj);
    L = [L; IssueReport.details("Pipeline options", configLines(obj, cfg))];
    L = [L; IssueReport.details("Config JSON", configJSON(cfg))];
end
if opts.Logs
    L = [L; IssueReport.details("Logs", logLines(obj, opts.MaxLogLines), false)];
end

L = [L; IssueReport.trailer("EphysPipelineApp")];
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
file = cfg.File;
if file == ""; file = "(never saved)"; end
dirty = "no";
if cfg.File == "" || ~isequaln(cfg.toStruct(), obj.SavedConfigStruct); dirty = "yes"; end
steps = cfg.enabledSteps();
if isempty(steps); steps = "(none)"; end
L = [IssueReport.kv("Config name", cfg.Name); ...
    IssueReport.kv("Config file", file); ...
    IssueReport.kv("Unsaved edits", dirty); ...
    IssueReport.kv("Enabled steps", join(string(steps), ", ")); ...
    IssueReport.kv("Project root", cfg.Project.Root); ...
    IssueReport.kv("Output root", cfg.Project.OutputRoot)];
if isempty(obj.Project)
    L = [L; IssueReport.kv("Datasets", "no project scanned")];
else
    L = [L; IssueReport.kv("Datasets", sprintf('%d scanned, %d ticked', ...
        obj.Project.NumDatasets, numel(obj.tickedDatasetIndices())))];
end
d = obj.currentDataset();
if ~isempty(d); L = [L; IssueReport.kv("Active dataset", d.Name)]; end
try
    L = [L; IssueReport.kv("Selected tab", string(obj.Tabs.SelectedTab.Title))];
catch
end
L = [L; IssueReport.kv("Run in progress", string(obj.RunActive))];
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
%logLines  The tail of each log area, then the last run error and its stack.
L = strings(0, 1);
areas = {"Run log", obj.RunLogArea; "Sorting log", obj.KSLogArea; "Copy log", obj.CopyLogArea};
for k = 1:size(areas, 1)
    txt = areaLines(areas{k, 2});
    if isempty(txt); continue; end
    tail = txt(max(1, numel(txt) - maxLines + 1):end);
    head = "**" + areas{k, 1} + "** (";
    if numel(tail) < numel(txt)
        head = head + "the last " + numel(tail) + " of " + numel(txt) + " lines)";
    else
        head = head + numel(txt) + " lines)";
    end
    L = [L; ""; head; ""; "```text"; tail; "```"];   %#ok<AGROW>
end
if ~isempty(obj.LastError)
    when = "";
    if ~isnat(obj.LastErrorTime)
        when = " (" + string(obj.LastErrorTime, "yyyy-MM-dd HH:mm:ss") + ")";
    end
    try
        rep = string(getReport(obj.LastError, 'extended', 'hyperlinks', 'off'));
    catch
        rep = string(obj.LastError.message);
    end
    L = [L; ""; "**Last run error**" + when; ""; "```text"; splitlines(rep); "```"];
end
if isempty(L); L = "_The logs were empty._"; end
end


function lines = areaLines(area)
%areaLines  A log text area's lines, the trailing blank ones dropped.
lines = strings(0, 1);
if isempty(area) || ~isvalid(area); return; end
v = string(area.Value);
v = v(:);
last = find(strlength(strip(v)) > 0, 1, 'last');
if isempty(last); return; end
lines = v(1:last);
end


function L = pythonLines(obj)
%pythonLines  MATLAB's interpreter and the one the Sorting tab runs Kilosort4 with.
parts = strings(0, 1);
try
    pe = pyenv;
    if strlength(string(pe.Version)) > 0
        parts = [parts; "pyenv " + string(pe.Version) + " (" + string(pe.Status) + ")"];
    end
catch
end
parts = [parts; fieldText(obj, "PythonExeField", "Sorting tab exe")];
parts = [parts; fieldText(obj, "CondaEnvField", "conda env")];
L = strings(0, 1);
if ~isempty(parts); L = IssueReport.kv("Python", join(parts.', "; ")); end
end


function s = fieldText(obj, prop, label)
%fieldText  "label: value" for an edit field, empty when it is blank or gone.
s = strings(0, 1);
try
    f = obj.(char(prop));
    if isempty(f) || ~isvalid(f); return; end
    v = strip(string(f.Value));
    if v == ""; return; end
    s = label + ": " + v;
catch
end
end
