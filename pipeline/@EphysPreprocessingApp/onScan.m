function onScan(obj)
%onScan  Build an EphysProject from the parent dir, gather metadata.

root = string(obj.RootPathField.Value);
if root == "" || ~isfolder(root)
    uialert(obj.Fig, "Select a valid parent directory first.", "Scan");
    return
end

obj.savePreferences();
obj.ScanButton.Enable = "off";
cleanup = onCleanup(@() set(obj.ScanButton, "Enable", "on"));

dlg = uiprogressdlg(obj.Fig, "Title", "Scanning", ...
    "Message", "Discovering recording folders...", "Indeterminate", "on");
drawnow;

try
    % Discovery is cheap (AutoMetadata=false per folder inside discover()).
    obj.Config = obj.gatherConfig();
    P = EphysProject(root, Recursive=obj.Config.Project.Recursive, ...
        ReaderOptions=obj.Config.Acquisition);

    % Push the config's shared settings (python / output root / SI / artifacts).
    EphysPipeline.applyConfigToDatasets(obj.Config, P);

    if P.NumDatasets == 0
        close(dlg);
        obj.Project = P;
        obj.refreshDatasetsTable();
        obj.populateDatasetPickers();
        obj.ScanStatusLabel.Text = sprintf("No recordings found under %s", root);
        hint = "Pick a different parent folder and Scan again.";
        if ~P.Recursive
            hint = "Only the root and the folders directly in it were searched: tick Recursive, or pick a different parent folder, and Scan again.";
        end
        obj.setStatus(sprintf("Scan complete: no recordings found under %s.", root), hint);
        return
    end

    % Header-only metadata + manifest restore/refresh, one dataset at a time,
    % with progress (EphysProject.refresh is what scripts and the pipeline
    % call too, so the app and headless runs agree on what a scan does).
    dlg.Indeterminate = "off";
    n = P.NumDatasets;
    P.refresh(ProgressFcn=@(i, n, name) showScanProgress(dlg, i, n, name), ...
        CancelFcn=@() dlg.CancelRequested);
    close(dlg);

    obj.Project = P;
    obj.refreshDatasetsTable();
    obj.applySelectionToTable(obj.Config.Project);
    obj.populateDatasetPickers();
    obj.syncStepEnableStates();
    obj.ScanStatusLabel.Text = sprintf("Found %d dataset(s) under %s", n, root);
    obj.setStatus(sprintf("Scanned %s: found %d dataset(s).", root, n), namePatternHint(P, obj.Config.Project.NamePattern));
catch ME
    if isvalid(dlg); close(dlg); end
    uialert(obj.Fig, ME.message, "Scan failed");
    obj.setStatus("Scan failed: " + string(ME.message), ...
        "Check the parent folder path and try Scan again.");
end
end


function hint = namePatternHint(P, pattern)
%namePatternHint  Suggest the Open Ephys name pattern when Open Ephys
%   session names do not match the current one.
hint = "";
oe = arrayfun(@(d) ~isempty(d.Reader) && d.Reader.Kind == "openephys", P.Datasets);
if ~any(oe); return; end
ok = true(1, 0);
for d = P.Datasets(oe)
    try
        [~, ~, ok(end+1)] = parseNameTokens(d.Name, pattern); %#ok<AGROW>
    catch
        return
    end
end
if all(ok); return; end
hint = sprintf("%d Open Ephys session name(s) do not match the name pattern; Open Ephys folders match %s.", ...
    nnz(~ok), OpenEphysReader.DefaultNamePattern);
end


function showScanProgress(dlg, i, n, name)
if ~isvalid(dlg); return; end
dlg.Value = i / n;
dlg.Message = sprintf("Reading headers %d/%d: %s", i, n, name);
end
