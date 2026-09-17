function onCopyCancel(obj)
%onCopyCancel  Ask the running copy engine to stop.
%   The engine finishes nothing more: it stops the file it is copying, leaves
%   the partial copy where it is and reports the rest of the batch cancelled.
%   Nothing is deleted, so Copy selected with IfExists="resume" completes it
%   later. Cancelling is not instant; the next poll picks it up.
if isempty(obj.CopyJob)
    return
end
obj.CopyCancelRequested = true;
obj.CopyRunButton.Enable = "off";
obj.CopyRunButton.Text = "Cancelling...";
obj.copyLog("Cancelling the copy; what has been copied is kept.");
obj.setStatus("Cancelling the copy...", "Copy selected will complete the partial copy later.");
end
