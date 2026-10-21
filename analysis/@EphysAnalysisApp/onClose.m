function onClose(obj)
%onClose  Ask about unsaved changes, stop a run, save the preferences, write the note in the notepad, close.
if ~obj.confirmDiscard(); return; end
if (obj.Running || obj.FigurePreviewState == "computing") && ~isempty(obj.Runner)
    obj.Runner.cancel();   % a preview computing right now stops at its next checkpoint
end
try
    obj.savePreferences();
catch ME
    warning('EphysAnalysisApp:SavePrefsFailed', 'Could not save preferences: %s', ME.message);
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
        warning('EphysAnalysisApp:NoteNotWritten', 'The note on %s was not written (%s). Its text:\n%s', ...
            p.Item.title, p.StateLabel.Text, p.Text);
    end
    delete(p);
end
if ~isempty(obj.NoteSearchWindow) && isvalid(obj.NoteSearchWindow)
    delete(obj.NoteSearchWindow);
end
delete(obj.Fig);
end
