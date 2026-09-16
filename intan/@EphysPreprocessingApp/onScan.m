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
    "Message", "Discovering *.rhd folders...", "Indeterminate", "on");
drawnow;

try
    % Discovery is cheap (AutoMetadata=false per folder inside discover()).
    P = EphysProject(root);

    % Push shared config (probe/python/etc) from current UI before metadata.
    obj.applyConfigToProject(P);

    if P.NumDatasets == 0
        close(dlg);
        obj.Project = P;
        obj.refreshDatasetsTable();
        obj.populateDatasetMenu();
        obj.populateArtifactDatasets();
        obj.populateReviewDatasets();
        obj.ScanStatusLabel.Text = sprintf("No *.rhd folders found under %s", root);
        obj.setStatus(sprintf("Scan complete: no *.rhd recordings found under %s.", root), ...
            "Pick a different parent folder and Scan again.");
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
    obj.populateDatasetMenu();
    obj.populateArtifactDatasets();
    obj.applyArtifactConfigToProject();   % seed every dataset with the tab's config
    obj.ScanStatusLabel.Text = sprintf("Found %d dataset(s) under %s", n, root);
    obj.setStatus(sprintf("Scanned %s: found %d dataset(s).", root, n));
catch ME
    if isvalid(dlg); close(dlg); end
    uialert(obj.Fig, ME.message, "Scan failed");
    obj.setStatus("Scan failed: " + string(ME.message), ...
        "Check the parent folder path and try Scan again.");
end
end


function showScanProgress(dlg, i, n, name)
if ~isvalid(dlg); return; end
dlg.Value = i / n;
dlg.Message = sprintf("Reading headers %d/%d: %s", i, n, name);
end
