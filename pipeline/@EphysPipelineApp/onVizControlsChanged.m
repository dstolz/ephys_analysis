function onVizControlsChanged(obj, what)
%onVizControlsChanged  A Visualize control changed: apply it and draw.
%   WHAT names the control group (applyVizSettings), or "view" (Start /
%   Window typed), "spacing" (Spacing typed). Nothing is read beyond the
%   window shown, and no file is changed.
%
%   See also applyVizSettings, buildVisualizeTab.

v = obj.Viewer;
if isempty(v) || ~isvalid(v) || isempty(obj.VizData); return; end
switch what
    case "view"
        v.setView(obj.VizStartField.Value, obj.VizDurField.Value);
    case "spacing"
        v.setSpacing(obj.VizSpacingField.Value);
    otherwise
        obj.applyVizSettings(what);
end
v.render();
end
