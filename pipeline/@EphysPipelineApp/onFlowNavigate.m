function onFlowNavigate(obj, evt)
%onFlowNavigate  Open the setting a box in the Diagram draws.
%   Every box in the chart names the control(s) behind what it shows (see the
%   node helper in flowChartHTML); the page's setup() sends them here when the
%   box is clicked. The tab holding the first control is shown, the control is
%   scrolled into view and focused, and every control of the box is
%   highlighted until the next tab change (clearFlowHighlight).
%
%   The page also reports each zoom or pan ('zoom'), which is kept per view
%   (FlowZoom) for the next redraw of that view (refreshFlowChart).
%
%   See also openSetting, flowNavControls, flowChartHTML, buildFlowTab.

if strcmp(evt.HTMLEventName, 'zoom')
    keepZoom(obj, evt.HTMLEventData);
    return
end
if ~strcmp(evt.HTMLEventName, 'navigate'); return; end
[target, title] = eventFields(evt.HTMLEventData);
if target == ""; return; end
if title == ""; title = target; end

[ok, tab] = obj.openSetting(target);   % the tab, the controls in view, marked, the first focused
if ~ok
    obj.setStatus("Diagram: " + title + " has no setting to open.", "");
    return
end
where = ternary(isempty(tab), "this config", "the " + string(tab.Title) + " tab");
obj.setStatus("Diagram: " + title + " is set on " + where + ".", "");
end


function keepZoom(obj, v)
%keepZoom  Keep the zoom a Diagram page reports, under the view it names.
if ~(isstruct(v) && isscalar(v) && all(isfield(v, {'key', 'auto', 'scale', 'x', 'y'})))
    return
end
key = asText(v.key);
num = @(a) isnumeric(a) && isscalar(a) && isfinite(a);
if ~ismember(extractBefore(key + "_lr", "_lr"), ["overview" "detail_tree" "detail_steps"]) || ~num(v.scale) || v.scale <= 0 ...
        || ~num(v.x) || ~num(v.y)
    return
end
auto = asText(v.auto);
if ~ismember(auto, ["fit" "actual"]); auto = ""; end
obj.FlowZoom.(key) = struct('key', key, 'auto', auto, 'scale', v.scale, 'x', v.x, 'y', v.y);
end


function [target, title] = eventFields(data)
%eventFields  The nav target and box title out of the page's event data.
target = ""; title = "";
if isstruct(data) && isscalar(data)
    if isfield(data, 'nav');   target = asText(data.nav); end
    if isfield(data, 'title'); title  = asText(data.title); end
else
    target = asText(data);
end
end


function s = asText(v)
%asText  V as one trimmed string, or "" for anything that is not text.
s = "";
if ischar(v) || (isstring(v) && isscalar(v) && ~ismissing(v))
    s = strip(string(v));
end
end


function v = ternary(tf, a, b)
if tf; v = string(a); else; v = string(b); end
end
