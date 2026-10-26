function onScan(obj)
%onScan  Build an EphysProject from the parent dir, gather metadata.
%   The active dataset, and the dataset a Visualize plot shows, stay the
%   same recordings (matched by folder) when they are still there, whatever
%   their new places in the project; else the first dataset becomes active
%   and the plot is flagged as out of date. Refused while a run is under
%   way. Datasets whose headers or manifest could not be read are listed in
%   an alert (EphysProject.refresh): a manifest that cannot be read is
%   neither used nor overwritten. When the app last closed with a
%   Kilosort4 queue kept for this root, the scan then offers it back
%   (offerKeptKSQueue). While the app starts (the constructor's scan of
%   the last config's project) the progress goes to the splash instead of
%   a dialog, its alerts wait for the window (AppSplash.alert), and the
%   constructor offers the kept queue once the window shows.

if obj.refuseWhileRunning("Scan"); return; end
root = string(obj.RootPathField.Value);
if root == "" || ~isfolder(root)
    obj.Splash.alert(obj.Fig, "Select a valid parent directory first.", "Scan");
    return
end

obj.savePreferences();
obj.ScanButton.Enable = "off";
cleanup = onCleanup(@() set(obj.ScanButton, "Enable", "on"));

starting = obj.Splash.isActive();   % the window is hidden: no dialog on it
if starting
    dlg = [];
    obj.Splash.progress(0, "Discovering the recording folders under " + root + " ...");
else
    dlg = uiprogressdlg(obj.Fig, "Title", "Scanning", ...
        "Message", "Discovering recording folders...", "Indeterminate", "on");
    drawnow;
end

active = obj.currentDataset();   % found again by folder in the new project
try
    % Discovery is cheap (AutoMetadata=false per folder inside discover()).
    obj.Config = obj.gatherConfig();
    P = EphysProject(root, Recursive=obj.Config.Project.Recursive, ...
        ReaderOptions=obj.Config.Acquisition);

    % Push the config's shared settings (python / output root / artifacts).
    EphysPipeline.applyConfigToDatasets(obj.Config, P);

    if P.NumDatasets == 0
        closeDialog(dlg);
        obj.Project = P;
        obj.refreshDatasetsTable();
        obj.populateDatasetPickers();
        obj.ScanStatusLabel.Text = sprintf("No recordings found under %s", root);
        hint = "Pick a different parent folder and Scan again.";
        if ~P.Recursive
            hint = "Only the root and the folders directly in it were searched: tick Recursive, or pick a different parent folder, and Scan again.";
        end
        obj.setStatus(sprintf("Scan complete: no recordings found under %s.", root), hint);
        if ~starting; obj.offerKeptKSQueue(); end
        return
    end

    % Header-only metadata + manifest restore/refresh, one dataset at a time,
    % with progress (EphysProject.refresh is what scripts and the pipeline
    % call too, so the app and headless runs agree on what a scan does).
    n = P.NumDatasets;
    if starting
        report = P.refresh(ProgressFcn=@(i, n, name) obj.Splash.progress(i / n, ...
            sprintf("Reading headers %d/%d: %s", i, n, name)));
    else
        dlg.Indeterminate = "off";
        report = P.refresh(ProgressFcn=@(i, n, name) showScanProgress(dlg, i, n, name), ...
            CancelFcn=@() dlg.CancelRequested);
        close(dlg);
    end

    nRule = 0;   % datasets that took the probe of a matching probe rule
    if obj.Config.Probe.AutoAssign
        nRule = height(EphysPipeline.assignProbeRules(P.Datasets, obj.Config.Probe.RuleSubjects, obj.Config.Probe.RuleProbes));
    end

    obj.Project = P;
    obj.SelectedDatasetIdx = sameFolder(P, active);   % 0: the first dataset (populateDatasetPickers)
    ix = sameFolder(P, obj.VizDataset);
    if ix > 0   % the plot shows that recording still, loaded again through the new dataset
        obj.VizDataset = P.Datasets(ix);
        obj.VizData = [];   % its sources read through the old dataset object
    end
    obj.refreshDatasetsTable();
    obj.applySelectionToTable(obj.Config.Project);
    obj.populateDatasetPickers();
    obj.syncStepEnableStates();
    obj.ScanStatusLabel.Text = sprintf("Found %d dataset(s) under %s", n, root);
    scanMsg = sprintf("Scanned %s: found %d dataset(s).", root, n);
    if nRule > 0
        scanMsg = scanMsg + sprintf(" Probe rules assigned a probe to %d.", nRule);
    end
    obj.setStatus(scanMsg, namePatternHint(P, obj.Config.Project.NamePattern));
    if ~starting; obj.offerKeptKSQueue(); end
    bad = report(report.Message ~= "" & report.Message ~= "canceled", :);
    if height(bad) > 0
        hint = strings(1, 0);
        if any(~bad.Manifest)   % a manifest that was not read; a read one with a message only dropped tags
            hint(end+1) = "A manifest that cannot be read is left as it is: fix or delete it, then Scan again.";
        end
        if any(bad.Manifest & contains(bad.Message, "tag(s) dropped"))
            hint(end+1) = "Invalid tags were dropped from the manifest.";
        end
        obj.setStatus(sprintf("Scanned %s: found %d dataset(s), %d with a problem.", root, n, height(bad)), ...
            strjoin(hint, " "));
        obj.Splash.alert(obj.Fig, strjoin(["These datasets were scanned with a problem:"; ""; bad.Dataset + ": " + bad.Message], newline), ...
            "Scan", "Icon", "warning");
    end
catch ME
    closeDialog(dlg);
    obj.Splash.alert(obj.Fig, ME.message, "Scan failed");
    obj.setStatus("Scan failed: " + string(ME.message), ...
        "Check the parent folder path and try Scan again.");
end
end


function ix = sameFolder(P, d)
%sameFolder  Index of the dataset of project P in dataset D's folder (0: none).
ix = 0;
if isempty(d) || ~isvalid(d) || P.NumDatasets == 0; return; end
hit = find(EphysDataset.pathKey([P.Datasets.Folder]) == EphysDataset.pathKey(d.Folder), 1);
if ~isempty(hit); ix = hit; end
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


function closeDialog(dlg)
%closeDialog  Close the progress dialog, when there is one (none while the app starts).
if ~isempty(dlg) && isvalid(dlg); close(dlg); end
end


function showScanProgress(dlg, i, n, name)
if ~isvalid(dlg); return; end
dlg.Value = i / n;
dlg.Message = sprintf("Reading headers %d/%d: %s", i, n, name);
end
