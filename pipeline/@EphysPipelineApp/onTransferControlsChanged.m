function onTransferControlsChanged(obj)
%onTransferControlsChanged  A Copy outputs control changed: the settings
%   follow the box, then the config is re-gathered.
syncTransferControls(obj);
obj.onConfigChanged();
end
