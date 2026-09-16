function onClose(obj)
    % Persist preferences (incl. figure geometry) and close.
    obj.ConvCancelRequested = true;   % stop a running conversion
    obj.stopKSMonitor();
    try
        obj.savePreferences();
    catch ME
        warning('EphysPreprocessingApp:SavePrefsFailed', ...
            'Could not save preferences: %s', ME.message);
    end
    delete(obj.Fig);
end
