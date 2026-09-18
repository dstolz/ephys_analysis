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
%                  interpreter the Sorting tab uses, the installed toolboxes
%                  and this repository's folder and git commit (default true)
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
    obj (1,1) EphysPreprocessingApp
    kind (1,1) string {mustBeMember(kind, ["bug", "feature"])}
    opts.Description (1,1) string = ""
    opts.System (1,1) logical = true
    opts.Config (1,1) logical = true
    opts.Logs (1,1) logical = true
    opts.MaxLogLines (1,1) double = 60
end

if kind == "bug"
    headings = ["What happened"; "Steps to reproduce"; "What I expected"];
else
    headings = ["What would you like to be able to do"; "Why it would help"; "How it might work"];
end

L = ["### " + headings(1); ""; opts.Description; ""];
for k = 2:numel(headings)
    L = [L; "### " + headings(k); ""; ""];   %#ok<AGROW>
end

if opts.System
    L = [L; detailsBlock("System", systemLines(obj))];
end
if opts.Config
    cfg = workingConfig(obj);
    L = [L; detailsBlock("Pipeline options", configLines(obj, cfg))];
    L = [L; detailsBlock("Config JSON", configJSON(cfg))];
end
if opts.Logs
    L = [L; detailsBlock("Logs", logLines(obj, opts.MaxLogLines), false)];
end

L = [L; ""; "---"; ...
    "_Filed from the EphysPreprocessingApp Help menu on " + ...
    string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm')) + "._"];
body = join(L, newline);
end


function L = detailsBlock(summary, lines, fenced)
%detailsBlock  One collapsed <details> section, its lines in a code fence.
if nargin < 3; fenced = true; end
lines = string(lines(:));
if isempty(lines); lines = "(nothing to report)"; end
L = [""; "<details>"; "<summary>" + summary + "</summary>"; ""];
if fenced
    L = [L; "```text"; lines; "```"];
else
    L = [L; lines];
end
L = [L; ""; "</details>"];
end


function L = systemLines(obj)
%systemLines  MATLAB, machine, GPU, Python and this checkout of the code.
L = [kv("MATLAB", version); kv("Platform", computer)];
osTxt = osDescription();
if osTxt ~= ""; L = [L; kv("OS", osTxt)]; end
L = [L; kv("Repository", repoDescription())];
try
    L = [L; kv("Compute threads", string(maxNumCompThreads))];
catch
end
if ispc
    try
        [~, sys] = memory;
        L = [L; kv("Memory", sprintf('%.1f GB total, %.1f GB free', ...
            sys.PhysicalMemory.Total / 2^30, sys.PhysicalMemory.Available / 2^30))];
    catch
    end
end
gpuTxt = gpuDescription();
if gpuTxt ~= ""; L = [L; kv("GPU", gpuTxt)]; end
pyTxt = pythonDescription(obj);
if pyTxt ~= ""; L = [L; kv("Python", pyTxt)]; end
tbTxt = toolboxList();
if tbTxt ~= ""; L = [L; kv("Toolboxes", tbTxt)]; end
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
L = [kv("Config name", cfg.Name); ...
    kv("Config file", file); ...
    kv("Unsaved edits", dirty); ...
    kv("Enabled steps", join(string(steps), ", ")); ...
    kv("Project root", cfg.Project.Root); ...
    kv("Output root", cfg.Project.OutputRoot)];
if isempty(obj.Project)
    L = [L; kv("Datasets", "no project scanned")];
else
    L = [L; kv("Datasets", sprintf('%d scanned, %d ticked', ...
        obj.Project.NumDatasets, numel(obj.tickedDatasetIndices())))];
end
d = obj.currentDataset();
if ~isempty(d); L = [L; kv("Active dataset", d.Name)]; end
try
    L = [L; kv("Selected tab", string(obj.Tabs.SelectedTab.Title))];
catch
end
L = [L; kv("Run in progress", string(obj.RunActive))];
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
areas = {"Run log", obj.RunLogArea; "Kilosort log", obj.KSLogArea; "Copy log", obj.CopyLogArea};
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


function s = kv(label, value)
%kv  One aligned "label : value" line.
value = strip(join(string(value), " "));
s = string(sprintf('%-16s : %s', label, value));
end


function s = osDescription()
s = "";
try
    if usejava('jvm')
        s = strip(string(java.lang.System.getProperty('os.name')) + " " + ...
            string(java.lang.System.getProperty('os.version')));
    end
catch
end
if s == "" && ispc; s = string(getenv('OS')); end
end


function s = repoDescription()
%repoDescription  Where this code is and which commit it is on, when git can tell.
here = fileparts(mfilename('fullpath'));            % @EphysPreprocessingApp
s = string(fileparts(fileparts(here)));             % the repository folder
try
    [st, out] = system(sprintf('git -C "%s" rev-parse --short HEAD', here));
    commit = strtrim(string(out));
    if st ~= 0 || isempty(regexp(commit, '^[0-9a-f]{7,40}$', 'once')); return; end
    s = s + " (commit " + commit;
    [st, branch] = system(sprintf('git -C "%s" rev-parse --abbrev-ref HEAD', here));
    branch = strtrim(string(branch));
    if st == 0 && branch ~= "" && branch ~= "HEAD"; s = s + " on " + branch; end
    [st, dirty] = system(sprintf('git -C "%s" status --porcelain', here));
    if st == 0 && strlength(strtrim(string(dirty))) > 0; s = s + ", with uncommitted changes"; end
    s = s + ")";
catch
end
end


function s = gpuDescription()
s = "";
try
    if isempty(ver('parallel')); return; end
    n = gpuDeviceCount("available");
    s = string(n) + " available";
    if n > 0
        T = gpuDeviceTable;
        s = s + " (" + join(string(T.Name(:)).', ", ") + ")";
    end
catch
end
end


function s = pythonDescription(obj)
%pythonDescription  MATLAB's interpreter and the one the Sorting tab runs Kilosort4 with.
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
if isempty(parts); s = ""; return; end
s = join(parts.', "; ");
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


function s = toolboxList()
s = "";
try
    v = ver;
    s = join(string({v.Name}) + " " + string({v.Version}), ", ");
catch
end
end
