function S = createSyntheticProject(obj, root, opts)
%createSyntheticProject  Write a synthetic test project and open it in the app.
%   S = app.createSyntheticProject(root, Name=Value) runs makeSyntheticProject
%   into ROOT with a progress dialog, opens the config it wrote (the working
%   config is replaced without a prompt; onCreateSyntheticProject asks
%   first), scans the project and shows the Project tab. S is the
%   makeSyntheticProject result, or [] when writing failed (an alert says
%   why). Options: Preset ("standard" | "small"), Overwrite, Scan (default
%   true) and Generator, a struct of further makeSyntheticProject options
%   (Fs, NumChannels, NumTrials, FileSeconds, Scenarios, Format, ...).
%
%   See also makeSyntheticProject, EphysPreprocessingApp.onCreateSyntheticProject.
arguments
    obj (1,1) EphysPreprocessingApp
    root (1,1) string
    opts.Preset (1,1) string {mustBeMember(opts.Preset, ["standard" "small"])} = "standard"
    opts.Overwrite (1,1) logical = false
    opts.Scan (1,1) logical = true
    opts.Generator (1,1) struct = struct()
end
S = [];
dlg = uiprogressdlg(obj.Fig, "Title", "Synthetic test project", "Message", "Preparing...", "Value", 0);
closer = onCleanup(@() closeDialog(dlg));
extra = namedargs2cell(opts.Generator);
try
    S = makeSyntheticProject(root, 'Preset', opts.Preset, 'Overwrite', opts.Overwrite, ...
        'ProgressFcn', @(f, m) showProgress(dlg, f, m), extra{:});
catch ME
    delete(closer);
    uialert(obj.Fig, "Could not write the synthetic project:" + newline + string(ME.message), ...
        "Create synthetic test project");
    obj.setStatus("Synthetic test project failed: " + string(ME.message), "");
    return
end
delete(closer);

if ~obj.openConfigFile(S.configFile)
    return
end
if opts.Scan
    obj.onScan();
end
obj.selectTab(obj.TabProject);
obj.setStatus(sprintf("Synthetic test project written to %s: %d dataset(s), %.0f MB. Scenarios and expected cuts are in its README.txt.", ...
    root, numel(S.datasets), S.bytes / 2^20), ...
    "Trials tab: Load each dataset and review its pairing; Run tab: Plan, then Run.");
end


function showProgress(dlg, frac, msg)
if ~isvalid(dlg); return; end
dlg.Value = min(max(frac, 0), 1);
dlg.Message = char(msg);
drawnow limitrate;
end


function closeDialog(dlg)
try
    if isvalid(dlg); close(dlg); end
catch
end
end
