function onAcquisitionChanged(obj)
%onAcquisitionChanged  An Open Ephys reader option changed: update the config
%   and, when a project is scanned, rescan it, because the options decide
%   which folders are recordings (one dataset per session or per recording)
%   and what each dataset reads (record node, stream). While a run is under
%   way the change is refused and the options put back.
if obj.Applying; return; end
if obj.refuseWhileRunning("Open Ephys options")
    obj.applyAcquisitionSection(obj.Config.Acquisition);
    return
end
obj.onConfigChanged();
if ~isempty(obj.Project) && obj.RootPathField.Value ~= "" && isfolder(obj.RootPathField.Value)
    obj.onScan();
end
end
