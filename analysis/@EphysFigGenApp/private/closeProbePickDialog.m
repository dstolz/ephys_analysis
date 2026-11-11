function closeProbePickDialog(obj, force)
%closeProbePickDialog  Close a Probe... window when the editor no longer shows the rows it picks for.
%   closeProbePickDialog(OBJ) closes the window (pickChannels,
%   OBJ.ProbePickWindow) unless the figure editor shows its figure and,
%   for a layer's, its panel and layer (probePickShown): another figure,
%   panel or layer picked, the panel removed, a config opened, so an OK
%   cannot land on them (as closePanelFilterDialog does for a panel's
%   Filter window). closeProbePickDialog(OBJ, true) closes it whatever is
%   shown. Closed so, it is canceled: nothing changes.
%
%   See also EphysFigGenApp.pickChannels, probePickShown, closePanelFilterDialog.
if nargin < 2; force = false; end
d = obj.ProbePickWindow;
if isempty(d) || ~isvalid(d); return; end
if force || ~probePickShown(obj, obj.ProbePickTarget)
    d.cancel();
    if isvalid(d); delete(d); end
    obj.ProbePickWindow = [];
end
end
