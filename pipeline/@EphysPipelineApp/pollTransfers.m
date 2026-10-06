function pollTransfers(obj)
%pollTransfers  Timer callback: advance every output transfer and show where they are.
%   Each OutputTransfer reads what its engine reported, checks a finished
%   job, starts the next one and, once its Run is over, removes what a move
%   copied. When all of them are done, the last row of the Run tab says
%   how each dataset's copy ended and the timer stops. With the app's
%   figure gone the timer stops (an engine in flight finishes its job on
%   its own).
if isempty(obj.Fig) || ~isvalid(obj.Fig)
    obj.stopTransferMonitor();
    return
end
for X = obj.Transfers
    try
        X.poll();
    catch ME
        obj.log("[transfer] %s", ME.message);
    end
end
obj.showTransferProgress();
if isempty(obj.Transfers) || ~all(arrayfun(@(X) X.Done, obj.Transfers))
    return
end

% Every transfer is done: how each dataset's copy ended, then stop watching.
counts = struct('done', 0, 'error', 0, 'cancelled', 0, 'skipped', 0);
verb = "copied";
folders = strings(1, 0);
for X = obj.Transfers
    if X.Method == "move"; verb = "moved"; end
    folders(end+1) = X.Destination; %#ok<AGROW>
    if isempty(X.Batches); continue; end
    for key = unique([X.Batches.Key], 'stable')
        st = X.statusOf(key);
        if isfield(counts, st); counts.(st) = counts.(st) + 1; end
    end
end
msg = sprintf("Output copies done: %d dataset(s) %s to %s", counts.done, verb, strjoin(unique(folders, 'stable'), ", "));
if counts.error > 0; msg = msg + sprintf(", %d with an ERROR (see their transfer rows and the log)", counts.error); end
if counts.cancelled > 0; msg = msg + sprintf(", %d cancelled", counts.cancelled); end
if counts.skipped > 0; msg = msg + sprintf(", %d skipped", counts.skipped); end
obj.RunTransferLabel.Text = char(msg + ".");
obj.RunTransferLabel.Tooltip = char(msg + ".");
obj.RunTransferLabel.FontColor = [0.4 0.4 0.4];
if counts.error > 0; obj.RunTransferLabel.FontColor = [0.75 0.1 0.1]; end
obj.setRunBar(obj.RunTransferBar, 1);
obj.RunTransferStopButton.Enable = "off";
obj.Transfers = OutputTransfer.empty(1, 0);
obj.stopTransferMonitor();
obj.setStatus(msg + ".");
obj.syncTabStrip();
end
