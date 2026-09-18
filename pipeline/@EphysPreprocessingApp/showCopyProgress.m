function showCopyProgress(obj, frac, msg, info)
%showCopyProgress  Draw where the background copy has got to.
%   Called by copySessions from the polling timer, so it must be cheap and must
%   not throw while the app is closing. FRAC is the batch as a whole (copying
%   and, with Verify="hash", checksumming); INFO says which session it is on,
%   how many sessions there are and how many bytes have moved, which is what
%   makes a rate and a time left possible. The bar is two panels in a grid
%   whose column weights are the fraction, so nothing is redrawn.
if isempty(obj.CopyProgressTrack) || ~isvalid(obj.CopyProgressTrack); return; end
frac = max(0, min(1, frac));
obj.CopyProgressTrack.ColumnWidth = {sprintf('%.4fx', max(frac, 1e-4)), sprintf('%.4fx', max(1 - frac, 1e-4))};
obj.CopyPercentLabel.Text = sprintf('%.0f%%', 100 * frac);

session = sessionName(obj, info.Session);
switch info.Phase
    case "copying";   what = "Copying";
    case "verifying"; what = "Verifying (SHA-256)";
    case "stitching"; what = "Stitching ePsych files for";
    otherwise;        what = "Finished";
end
if info.Sessions(2) > 1 && info.Phase ~= "done"
    nth = min(info.Sessions(1) + 1, info.Sessions(2));
    obj.CopyProgressHeadline.Text = char(sprintf("%s session %d of %d   %s", what, nth, info.Sessions(2), session));
else
    obj.CopyProgressHeadline.Text = char(strtrim(what + " " + session));
end
obj.CopyProgressETA.Text = char(rateAndLeft(obj, frac, info));
obj.CopyProgressLabel.Text = char(detailText(info, msg, session));

% The row in flight carries its own percentage in the table's Result column,
% and the rows the engine has not reached yet are waiting rather than copying.
obj.CopyLiveRow = 0;
obj.CopyLivePos = info.Session;
obj.CopyLivePhase = info.Phase;
if info.Session > 0 && info.Session <= numel(obj.CopyRows) && all(isfinite(info.SessionBytes)) && info.SessionBytes(2) > 0
    obj.CopyLiveRow = obj.CopyRows(info.Session);
    obj.CopyLiveFrac = max(0, min(1, info.SessionBytes(1) / info.SessionBytes(2)));
end
end


function s = detailText(info, msg, session)
%detailText  The batch's bytes, then whatever the engine last said, without
%   repeating the session name already in the headline.
msg = string(msg);
if strlength(session) > 0
    msg = strtrim(erase(msg, session + ":"));
end
if info.Bytes(2) > 0
    s = sprintf("%s of %s   %s", bytesText(info.Bytes(1)), bytesText(info.Bytes(2)), msg);
else
    s = msg;
end
end


function s = rateAndLeft(obj, frac, info)
%rateAndLeft  How fast the bytes are moving and how long the batch has left.
%   The rate comes from the bytes themselves over the last few seconds, so a
%   pause shows as a slower rate; the time left comes from the fraction, which
%   already counts the checksum pass as the two extra reads it is. Neither is
%   shown until there is enough of the copy to measure.
if isempty(obj.CopyStarted); obj.CopyStarted = tic; end
elapsed = toc(obj.CopyStarted);   % seconds, as a double: the history is a plain [s bytes] matrix
obj.CopyRateHistory = [obj.CopyRateHistory; elapsed, info.Bytes(1)];
obj.CopyRateHistory(obj.CopyRateHistory(:, 1) < elapsed - 15, :) = [];
s = "";
h = obj.CopyRateHistory;
if size(h, 1) >= 2 && h(end, 1) - h(1, 1) >= 2 && h(end, 2) > h(1, 2)
    s = bytesText((h(end, 2) - h(1, 2)) / (h(end, 1) - h(1, 1))) + "/s";
end
if frac >= 0.01 && frac < 1 && elapsed >= 5
    left = elapsed * (1 - frac) / frac;
    s = strtrim(s + "   " + leftText(left));
end
end


function s = leftText(secs)
if secs < 60
    s = "less than a minute left";
elseif secs < 3600
    s = sprintf("about %d min left", max(1, round(secs / 60)));
else
    s = sprintf("about %d h %d min left", floor(secs / 3600), round(mod(secs, 3600) / 60));
end
end


function s = sessionName(obj, index)
%sessionName  The destination folder name of the row the engine is working on.
s = "";
if index < 1 || index > numel(obj.CopyRows); return; end
row = obj.CopyRows(index);
if row < 1 || row > height(obj.CopySessions); return; end
[~, s] = fileparts(obj.CopySessions.DestDir(row));
end


function s = bytesText(b)
units = ["B", "KB", "MB", "GB", "TB"];
k = 1;
while b >= 1024 && k < numel(units)
    b = b / 1024; k = k + 1;
end
if k == 1
    s = sprintf("%d B", round(b));
else
    s = sprintf("%.1f %s", b, units(k));
end
end
