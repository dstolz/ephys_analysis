function showTransferProgress(obj)
%showTransferProgress  The Run tab's last row: where the output copies have got to.
%   Every transfer followed (Transfers) together: the share of their bytes
%   copied (a SHA-256 check counts as two more reads), the batches done, a
%   rate from the bytes of the last 15 s and a time left, how many wait
%   for a background sort, and the batch in flight with what the copy
%   engine said last. The tooltip adds each destination. Called by the
%   timer (pollTransfers), so it must be cheap.
T = obj.Transfers;   % the monitor timer's pollTransfers can empty obj.Transfers while this runs
if isempty(obj.RunTransferLabel) || ~isvalid(obj.RunTransferLabel) || isempty(T); return; end
infos = arrayfun(@(X) X.progress(), T);
total = sum([infos.BytesTotal]);
doneBytes = sum([infos.BytesDone]);
batches = sum(vertcat(infos.Batches), 1);
waiting = sum([infos.Waiting]);
failed = sum([infos.Failed]);
if total > 0
    frac = sum([infos.Fraction] .* [infos.BytesTotal]) / total;
else
    frac = double(all([infos.Fraction] >= 1));
end
obj.setRunBar(obj.RunTransferBar, frac);

phases = [infos.Phase];
if any(phases == "copying")
    what = "Copying outputs";
elseif any(phases == "verifying")
    what = "Checking the copies (SHA-256)";
elseif any(phases == "waiting")
    what = "Output copies wait for a sort";
elseif all(phases == "done")
    what = "Output copies";
else
    what = "Output copies";
end
s = sprintf("%s: %.0f%%, %s of %s, %d of %d batch(es)", what, 100 * frac, ...
    OutputTransfer.bytesText(doneBytes), OutputTransfer.bytesText(total), batches(1), batches(2));
if waiting > 0; s = s + sprintf(", %d waiting for a sort", waiting); end
if failed > 0; s = s + sprintf(", %d FAILED", failed); end
s = s + rateAndLeft(obj, frac, doneBytes);
k = find([infos.Current] ~= "", 1);
if ~isempty(k)
    s = s + "   " + infos(k).Current;
    if infos(k).Message ~= ""; s = s + " (" + infos(k).Message + ")"; end
end
if isempty(obj.Transfers); return; end   % they finished meanwhile: keep pollTransfers' last message
tip = s + newline + "To: " + strjoin(unique([T.Destination], 'stable'), ", ");
obj.RunTransferLabel.Text = char(s);
obj.RunTransferLabel.Tooltip = char(tip);
obj.RunTransferLabel.FontColor = [0.2 0.2 0.2];
if failed > 0; obj.RunTransferLabel.FontColor = [0.75 0.1 0.1]; end
end


function s = rateAndLeft(obj, frac, bytes)
%rateAndLeft  ", 45.0 MB/s, about 3 min left": the rate from the bytes of the
%   last 15 s, the time left from the fraction (TransferClock, a ProgressClock).
if isempty(obj.TransferClock); obj.TransferClock = ProgressClock(); end
left = obj.TransferClock.update(frac);
elapsed = obj.TransferClock.Elapsed;
obj.TransferRateHistory = [obj.TransferRateHistory; elapsed, bytes];
obj.TransferRateHistory(obj.TransferRateHistory(:, 1) < elapsed - 15, :) = [];
h = obj.TransferRateHistory;
s = "";
if size(h, 1) >= 2 && h(end, 1) - h(1, 1) >= 2 && h(end, 2) > h(1, 2)
    rate = (h(end, 2) - h(1, 2)) / (h(end, 1) - h(1, 1));
    s = ", " + OutputTransfer.bytesText(rate) + "/s";
end
if left ~= ""; s = s + ", " + left; end
end
