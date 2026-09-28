function onAcquisitionChanged(obj)
%onAcquisitionChanged  A source setting (reader option) changed: update the
%   config and, when a project is scanned, rescan it, because the options
%   decide which folders are recordings (Open Ephys: one dataset per session
%   or per recording) and what each dataset reads (record node, stream,
%   gain). A TDT gain that is not a number is refused (status bar) and
%   nothing is rescanned. While a run is under way the change is refused
%   and the options put back.
if obj.Applying; return; end
if obj.refuseWhileRunning("Source settings")
    obj.applyAcquisitionSection(obj.Config.Acquisition);
    return
end
try
    obj.gatherAcquisitionSection();
catch ME
    obj.setStatus("Source settings: " + string(ME.message), "");
    return
end
obj.onConfigChanged();
if ~isempty(obj.Project) && obj.RootPathField.Value ~= "" && isfolder(obj.RootPathField.Value)
    obj.onScan();
end
end
