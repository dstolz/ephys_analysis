function onClose(obj)
%onClose  Ask about unsaved changes, stop a run, save the preferences, close.
if ~obj.confirmDiscard(); return; end
if obj.Running && ~isempty(obj.Runner)
    obj.Runner.cancel();
end
try
    obj.savePreferences();
catch ME
    warning('EphysAnalysisApp:SavePrefsFailed', 'Could not save preferences: %s', ME.message);
end
if ~isempty(obj.Runner)
    obj.Runner.clearSources();
end
delete(obj.Fig);
end
