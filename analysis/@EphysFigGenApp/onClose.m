function onClose(obj)
%onClose  Ask about unsaved changes, then hide the window, stop a run, save the preferences, write the note in the notepad, close.
%   The Save / Discard / Cancel question comes first and at once
%   (confirmDiscard). Once the answer lets the app close, the window is
%   hidden before the rest, so it goes at once; deleting a window that
%   holds drawn previews takes a second or more. A close request made
%   while one is under way (a second click on the window's X) is ignored.
if obj.Closing; return; end
obj.Closing = true;
if ~obj.confirmDiscard()
    obj.Closing = false;
    return
end
if ~isempty(obj.Fig) && isvalid(obj.Fig)
    obj.Fig.Visible = "off";
    drawnow nocallbacks   % shown hidden now; a queued edit is not acted on (it would start a preview)
end
if (obj.Running || obj.FigurePreviewState == "computing") && ~isempty(obj.Runner)
    obj.Runner.cancel();   % a preview computing right now stops at its next checkpoint
end
try
    obj.savePreferences();
catch ME
    warning('EphysFigGenApp:SavePrefsFailed', 'Could not save preferences: %s', ME.message);
end
if ~isempty(obj.Runner)
    obj.Runner.clearSources();
end
if ~isempty(obj.SequenceDialog) && isvalid(obj.SequenceDialog)
    delete(obj.SequenceDialog);
end
if ~isempty(obj.NotePadWindow) && isvalid(obj.NotePadWindow)
    p = obj.NotePadWindow;
    if ~p.save()   % a read-only folder: the text goes to the Command Window rather than nowhere
        warning('EphysFigGenApp:NoteNotWritten', 'The note on %s was not written (%s). Its text:\n%s', ...
            p.Item.title, p.StateLabel.Text, p.Text);
    end
    delete(p);
end
if ~isempty(obj.NoteSearchWindow) && isvalid(obj.NoteSearchWindow)
    delete(obj.NoteSearchWindow);
end
if ~isempty(obj.VariableDialog) && isvalid(obj.VariableDialog)
    delete(obj.VariableDialog);
end
if ~isempty(obj.DownsampleWindow) && isvalid(obj.DownsampleWindow)
    delete(obj.DownsampleWindow);   % closed as canceled: the rates stay as they were
end
for w = {obj.SignalFilterWindow, obj.PanelFilterWindow}   % the Filter dialogs: closed as canceled
    if ~isempty(w{1}) && isvalid(w{1}); delete(w{1}); end
end
O = obj.FigureArrangeOverlay;
if isstruct(O) && ~isempty(O.timer) && isvalid(O.timer); stop(O.timer); end   % Arrange's cue timer (it deletes itself)
for t = {obj.FigureSelectTimer, obj.FigureSettleTimer, obj.WarmTimer}   % Arrange's refill after a release, its redraw after Arrange off, the startup warm-up (they delete themselves)
    if ~isempty(t{1}) && isvalid(t{1}); stop(t{1}); end
end
delete(obj.Fig);
end
