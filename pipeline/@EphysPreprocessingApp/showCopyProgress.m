function showCopyProgress(obj, frac, msg)
%showCopyProgress  The copy engine's current file, shown under the Copy tab's options.
%   Called by copySessions from the polling timer, so it must be cheap and
%   must not throw while the app is closing.
if isempty(obj.CopyProgressLabel) || ~isvalid(obj.CopyProgressLabel)
    return
end
obj.CopyProgressLabel.Text = char(sprintf("%3.0f%%   %s", 100 * max(0, min(1, frac)), msg));
end
