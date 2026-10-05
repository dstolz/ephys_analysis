function onDesignProbe(obj)
%onDesignProbe  Open the probeinterface-backed probe designer.
%   Launches ProbeDesignerApp, which builds a probe from the probeinterface
%   library or a geometry generator (via obj.runProbeTool), lets the user wire
%   contacts to Intan amplifier channels, and Saves a Kilosort4 probe .json into
%   the probe folder. The designer calls back into obj.refreshProbeList on save
%   so the new probe appears in the list.
%
%   Passes the active dataset's channel count (when any) purely as a soft
%   count-check hint.
%
%   See also ProbeDesignerApp, EphysPreprocessingApp.runProbeTool,
%   EphysPreprocessingApp.refreshProbeList.

nChanHint = NaN;
d = obj.currentDataset();
if ~isempty(d) && ~isnan(d.NumChannels)
    nChanHint = d.NumChannels;
end

ProbeDesignerApp(obj, nChanHint);
end
