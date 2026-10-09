function onClose(obj)
%onClose  Ask about unsaved changes, stop a run, save the preferences, close.
if ~obj.confirmDiscard(); return; end
if (obj.Running || obj.PreviewState == "computing") && ~isempty(obj.Runner)
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
delete(obj.Fig);
end
