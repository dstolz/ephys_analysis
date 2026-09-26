function onClose(obj)
%onClose  Remember the preferences and close the window (and the object).
try
    obj.savePreferences();
catch ME
    warning('ChannelMapperApp:SavePrefsFailed', 'Could not save preferences: %s', ME.message);
end
delete(obj);
end
