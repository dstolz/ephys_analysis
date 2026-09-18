function onSourceModeChanged(obj)
%onSourceModeChanged  Project root or output folders: enable the matching fields.
obj.syncSourceEnable();
obj.onConfigChanged("source");
end
