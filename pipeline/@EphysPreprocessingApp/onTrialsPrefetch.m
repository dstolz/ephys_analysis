function onTrialsPrefetch(obj)
%onTrialsPrefetch  Read and cache the digital lines of every ticked dataset.
%   For each ticked dataset (Project tab) with an Epsych2 session, reads
%   the digital lines once through EphysDataset.digitalEvents, which saves
%   them as <outputFolder>/<Name>_events.mat. Load, the behavior step and
%   the pairing then take them from that file instead of reading the
%   recording again; a dataset whose cache is still current is only checked.
%   With Behavior.AutoApprove each dataset is also paired, and a pairing
%   whose counts match without cuts is approved
%   (EphysDataset.autoApproveTrialPairing). Cancel stops before the next
%   recording file; the datasets finished so far stay cached.
dlgTitle = "Prefetch digital lines";
if isempty(obj.Project) || obj.Project.NumDatasets == 0
    uialert(obj.Fig, "Scan a project first (Project tab).", dlgTitle);
    return
end
idx = obj.tickedDatasetIndices();
if isempty(idx)
    uialert(obj.Fig, "Tick the datasets to prefetch in the Select column of the Project tab.", dlgTitle);
    return
end
hasBeh = arrayfun(@(i) obj.Project.Datasets(i).BehaviorFile ~= "" ...
    && isfile(obj.Project.Datasets(i).BehaviorFile), idx);
nSkipped = nnz(~hasBeh);
idx = idx(hasBeh);
if isempty(idx)
    uialert(obj.Fig, "None of the ticked datasets has an Epsych2 session associated (Project tab).", dlgTitle);
    return
end
auto = obj.Config.Behavior.AutoApprove;

n = numel(idx);
nRead = 0; nCached = 0; nAlready = 0;
approved = zeros(1, 0);   % dataset indices approved automatically
review = strings(1, 0); failed = strings(1, 0);
nNotDone = 0;   % datasets left when Cancel was pressed
t0 = tic;
dlg = uiprogressdlg(obj.Fig, "Title", dlgTitle, "Message", "Starting ...", ...
    "Cancelable", "on", "Value", 0);
for k = 1:n
    drawnow
    if dlg.CancelRequested; nNotDone = n - k + 1; break; end
    d = obj.Project.Datasets(idx(k));
    dlg.Value = (k - 1) / n;
    dlg.Message = sprintf("%d of %d: %s", k, n, d.Name);
    try
        E = d.digitalEvents(ProgressFcn=@(i, nFiles, file) progress(dlg, k, n, d.Name, i, nFiles, file));
    catch ME
        if strcmp(ME.identifier, 'EphysPreprocessingApp:PrefetchCancelled')
            nNotDone = n - k + 1;
            break
        end
        failed(end + 1) = d.Name + ": " + string(ME.message); %#ok<AGROW>
        continue
    end
    if E.source == "cache"
        nCached = nCached + 1;
    else
        nRead = nRead + 1;
    end
    if ~auto; continue; end
    try
        [P, tf] = d.autoApproveTrialPairing(d.pairTrials(Events=E, Warn=false));
    catch ME
        failed(end + 1) = d.Name + ": pairing: " + string(ME.message); %#ok<AGROW>
        continue
    end
    if tf
        approved(end + 1) = idx(k); %#ok<AGROW>
    elseif P.status == "approved"
        nAlready = nAlready + 1;
    else
        review(end + 1) = d.Name + " (" + reviewReason(P) + ")"; %#ok<AGROW>
    end
end
close(dlg);

% The shown pairing may have just been approved: show its new record.
if ~isempty(obj.TrialsEvents) && obj.TrialsEventsIdx == obj.SelectedDatasetIdx ...
        && ismember(obj.SelectedDatasetIdx, approved)
    obj.repairTrials("recorded");
end
if ~isempty(approved)
    obj.refreshDatasetsTable();
end

msg = sprintf("Prefetch: digital lines of %d dataset(s) ready (%d read, %d already cached) in %s", ...
    nRead + nCached, nRead, nCached, string(duration(0, 0, round(toc(t0)), "Format", "hh:mm:ss")));
if nSkipped > 0; msg = msg + sprintf("; %d skipped (no Epsych2 session)", nSkipped); end
if ~isempty(failed); msg = msg + sprintf("; %d failed", numel(failed)); end
if nNotDone > 0; msg = msg + sprintf("; cancelled with %d not done", nNotDone); end
msg = msg + ".";
if auto
    msg = msg + sprintf(" Pairings: %d approved automatically, %d already approved, %d need review.", ...
        numel(approved), nAlready, numel(review));
end
hint = "";
if ~isempty(review)
    hint = "Load each pairing that needs review and resolve it.";
elseif nRead + nCached > 0
    hint = "Load a dataset: its digital lines now come from the cache.";
end
obj.setStatus(msg, hint);

details = strings(1, 0);
if ~isempty(review)
    details(end + 1) = "Pairings that need review:" + newline + "  " + strjoin(review, newline + "  ");
end
if ~isempty(failed)
    details(end + 1) = "Failed:" + newline + "  " + strjoin(failed, newline + "  ");
end
if ~isempty(details)
    uialert(obj.Fig, strjoin([msg, details], newline + newline), dlgTitle, "Icon", "warning");
end
end


function progress(dlg, k, n, name, i, nFiles, file)
%progress  Report the file being read; stop when Cancel was pressed.
drawnow
if dlg.CancelRequested
    error('EphysPreprocessingApp:PrefetchCancelled', 'Prefetch cancelled.');
end
dlg.Value = (k - 1 + (i - 1) / max(nFiles, 1)) / n;
dlg.Message = sprintf("%d of %d: %s" + newline + "Reading %s (file %d of %d)", k, n, name, file, i, nFiles);
end


function why = reviewReason(P)
%reviewReason  Why autoApproveTrialPairing left P for review, in a few words.
kept = [P.nTrials - sum(P.cutTrials), P.nIntervals - sum(P.cutIntervals)];
if P.countMismatch
    why = sprintf("%d trial(s) vs %d interval(s)", kept(1), kept(2));
elseif any(P.cutTrials) || any(P.cutIntervals)
    why = "its cuts are not approved";
else
    why = "no trials";
end
end
