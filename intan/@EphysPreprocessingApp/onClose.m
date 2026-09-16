function onClose(obj)
%onClose  Ask about unsaved changes, stop background work, persist prefs, close.
if ~obj.confirmDiscard(); return; end
if obj.RunActive && ~isempty(obj.Pipe)
    obj.Pipe.cancel();
end
obj.stopKSMonitor();
try
    obj.savePreferences();
catch ME
    warning('EphysPreprocessingApp:SavePrefsFailed', 'Could not save preferences: %s', ME.message);
end
delete(obj.Fig);
end
