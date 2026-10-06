function offerKeptKSQueue(obj)
%offerKeptKSQueue  After a scan, offer back the Kilosort4 queue kept for its root.
%   When the app last closed with runs queued for the scanned project's
%   root and the queue was kept ("Keep the queue for next time",
%   keepKSRuns), a confirmation lists the runs that can go back in the
%   queue and the ones that cannot, with why (restoreKSQueue "check").
%   "Queue them again" puts the first back in the queue, where the monitor
%   starts them as slots free; "Drop them" does not. When none can go
%   back, an alert says why instead. Either way the kept queue of this root
%   is then forgotten. onScan calls it; an error here is logged, so the
%   scan stands.
%
%   See also restoreKSQueue, keepKSRuns, onScan.

try
    T = obj.restoreKSQueue("check");
    if isempty(T); return; end
    store = keptSortingQueue(obj.PrefGroup);
    i = find(EphysDataset.pathKey([store.root]) == EphysDataset.pathKey(obj.Project.Root), 1);
    saved = "";
    if ~isempty(i); saved = " (" + string(store(i).saved) + ")"; end
    ok = T.Problem == "";
    msg = sprintf("When the app last closed%s, it kept %d queued sorting run(s) for this project.", saved, height(T));
    if any(ok)
        msg = msg + newline + newline + "Can go back in the queue (their run files are written; they start as slots free):" + ...
            newline + strjoin(("  " + T.Dataset(ok)).', newline);
    end
    if any(~ok)
        msg = msg + newline + newline + "Cannot go back in the queue:" + newline + ...
            strjoin(("  " + T.Dataset(~ok) + ": " + T.Problem(~ok)).', newline);
    end
    if any(ok)
        answer = uiconfirm(obj.Fig, msg + newline + newline + "Queue them again? Either way the kept queue is then forgotten.", ...
            "Sorting queue kept", "Options", ["Queue them again", "Drop them"], ...
            "DefaultOption", 1, "CancelOption", 2);
        action = "drop";
        if answer == "Queue them again"; action = "requeue"; end
    else
        uialert(obj.Fig, msg + newline + newline + "The kept queue is forgotten; sort these datasets again.", ...
            "Sorting queue kept", "Icon", "warning");
        action = "drop";
    end
    T = obj.restoreKSQueue(action);
    if action == "requeue"
        obj.setStatus(sprintf("Queued %d kept sorting run(s) again; %d could not be.", nnz(T.Queued), nnz(~T.Queued)), ...
            "The monitor starts them as slots free (Run tab).");
    end
catch ME
    obj.log("[error] the sorting queue kept for this project could not be offered back: %s", ME.message);
end
end
