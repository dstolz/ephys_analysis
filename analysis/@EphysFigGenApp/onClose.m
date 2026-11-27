function onClose(obj)
%onClose  Ask about unsaved changes, then hide the window, stop a run, save the preferences, write the note in the notepad, close.
%   The Save / Discard / Cancel question comes first and at once
%   (confirmDiscard). Once the answer lets the app close, the window is
%   hidden before the rest, so it goes at once; deleting a window that
%   holds drawn previews takes a second or more. A close request made
%   while one is under way (a second click on the window's X) is ignored.
%   Whatever stops the close before the window is hidden (Cancel, an error
%   of the Save: onSaveConfig) leaves the app as it was, Closing off, so the
%   window can be closed again. After the hide the close is committed:
%   closeWindow does each step on its own (one that throws is warned of) and
%   deletes the window whatever happened, so no hidden window is left that
%   cannot be closed.
%   While a run goes, the run is canceled and the window, hidden, waits for
%   it (CloseWhenRunEnds): the run's progress, its report and its run record
%   (the files and the lab database record of what was finished) are written
%   as for any canceled run, and onRunExport closes the window when it
%   ends. The runner is not released under it.
%
%   See also onRunExport, closeWindow, confirmDiscard.
if obj.Closing; return; end
obj.Closing = true;
undo = onCleanup(@() notClosing(obj)); %#ok<NASGU> Closing off again on every way out that leaves the window open
if ~obj.confirmDiscard(); return; end
if windowOpen(obj)
    try
        obj.Fig.Visible = "off";
        drawnow nocallbacks   % shown hidden now; a queued edit is not acted on (it would start a preview)
    catch
    end
end
if obj.Running && ~isempty(obj.Runner)
    obj.CloseWhenRunEnds = true;   % onRunExport closes the window when the run has ended
    obj.Runner.cancel();
    return
end
closeWindow(obj);
end


function notClosing(obj)
%notClosing  The close did not go through (or is waiting for a run): Closing is off again, unless the window waits for the run's end.
if isvalid(obj) && ~obj.CloseWhenRunEnds; obj.Closing = false; end
end
