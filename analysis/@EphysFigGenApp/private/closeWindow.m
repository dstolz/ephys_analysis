function closeWindow(obj)
%closeWindow  The second half of Close: stop what is left, save the preferences and the note, delete the window.
%   Close (onClose) asks about unsaved changes and hides the window, then
%   calls this at once, or, while a run goes, when the run has ended
%   (onRunExport). Each step is on its own: one that throws is warned of and
%   the rest go on, and the window is deleted whatever happened (a window
%   hidden and never deleted could not be closed again).
obj.CloseWhenRunEnds = false;
gone = onCleanup(@() deleteWindow(obj)); %#ok<NASGU> the window goes even when a step above it throws
if ~isempty(obj.Runner) && isvalid(obj.Runner) && obj.FigurePreviewState == "computing"
    obj.Runner.cancel();   % a preview computing right now stops at its next checkpoint
end
step(@() obj.savePreferences(), 'EphysFigGenApp:SavePrefsFailed', 'Could not save preferences');
step(@() noteSaved(obj), 'EphysFigGenApp:NoteNotWritten', 'The note was not written');   % before the sources go
step(@() clearSources(obj), 'EphysFigGenApp:CloseStepFailed', 'Could not release the datasets');
step(@() deleteWindows(obj), 'EphysFigGenApp:CloseStepFailed', 'Could not close a window');
end


function step(fcn, id, what)
%step  Run FCN; a failure is a warning with WHAT and its message, so the next step still runs.
try
    fcn();
catch ME
    warning(id, '%s: %s', what, ME.message);
end
end


function clearSources(obj)
if ~isempty(obj.Runner) && isvalid(obj.Runner); obj.Runner.clearSources(); end
end


function noteSaved(obj)
%noteSaved  The note in the notepad is written (a read-only folder: its text goes to the Command Window rather than nowhere).
if ~isempty(obj.NotePadWindow) && isvalid(obj.NotePadWindow)
    p = obj.NotePadWindow;
    if ~p.save()
        warning('EphysFigGenApp:NoteNotWritten', 'The note on %s was not written (%s). Its text:\n%s', ...
            p.Item.title, p.StateLabel.Text, p.Text);
    end
    delete(p);
end
end


function deleteWindows(obj)
%deleteWindows  The app's other windows and timers (each deleted on its own, one that fails does not keep the rest).
for w = {obj.SequenceDialog, obj.NoteSearchWindow, obj.VariableDialog, obj.DownsampleWindow, obj.SignalFilterWindow, obj.PanelFilterWindow, obj.ProbePickWindow}   % closed as canceled: the rates, filters and picks stay as they were
    step(@() deleteHandle(w{1}), 'EphysFigGenApp:CloseStepFailed', 'Could not close a window');
end
O = obj.FigureArrangeOverlay;
if isstruct(O) && ~isempty(O.timer) && isvalid(O.timer); stop(O.timer); end   % Arrange's cue timer (it deletes itself)
for t = {obj.FigureSelectTimer, obj.FigureSettleTimer, obj.WarmTimer}   % Arrange's refill after a release, its redraw after Arrange off, the startup warm-up (they delete themselves)
    step(@() stopTimer(t{1}), 'EphysFigGenApp:CloseStepFailed', 'Could not stop a timer');
end
end


function deleteHandle(h)
if ~isempty(h) && isvalid(h); delete(h); end
end


function stopTimer(t)
if ~isempty(t) && isvalid(t); stop(t); end
end


function deleteWindow(obj)
if isvalid(obj) && ~isempty(obj.Fig) && isvalid(obj.Fig); delete(obj.Fig); end
end
