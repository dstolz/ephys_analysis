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
%   See also flowNavControls, flowChartHTML, buildFlowTab.

if strcmp(evt.HTMLEventName, 'zoom')
    keepZoom(obj, evt.HTMLEventData);
    return
end
if ~strcmp(evt.HTMLEventName, 'navigate'); return; end
[target, title] = eventFields(evt.HTMLEventData);
if target == ""; return; end
if title == ""; title = target; end

ctrls = obj.flowNavControls(target);
obj.clearFlowHighlight();
if isempty(ctrls)
    obj.setStatus("Diagram: " + title + " has no setting to open.", "");
    return
end

tab = ancestor(ctrls{1}, 'matlab.ui.container.Tab');
if ~isempty(tab); obj.selectTab(tab); end
for k = 1:numel(ctrls)
    scrollIntoView(ctrls{k});   % in order, so a box's whole group of controls ends up in view
    highlight(obj, ctrls{k});
end
try
    focus(ctrls{1});
catch
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
if ~ismember(key, ["overview" "detail_tree" "detail_steps"]) || ~num(v.scale) || v.scale <= 0 ...
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


function scrollIntoView(c)
%scrollIntoView  Scroll every scrollable container C sits in to C.
p = c.Parent;
while ~isempty(p) && ~isa(p, 'matlab.ui.Figure')
    if isprop(p, 'Scrollable') && strcmp(p.Scrollable, 'on')
        try
            scroll(p, c);
        catch
        end
    end
    p = p.Parent;
end
end


function highlight(obj, c)
%highlight  Mark C as the control the Diagram box pointed at, remembering its look.
%   Tables are left alone: recolouring one recolours every cell in it.
if isa(c, 'matlab.ui.control.Table'); return; end
props = intersect(["FontColor", "FontWeight"], string(properties(c)));
if isempty(props); return; end
saved = struct();
for p = props(:)'
    saved.(p) = c.(p);
end
obj.FlowHighlight(end+1) = struct('Control', c, 'Saved', saved);
if isfield(saved, 'FontColor');  c.FontColor = [0.15 0.45 0.80]; end
if isfield(saved, 'FontWeight'); c.FontWeight = 'bold'; end
end


function v = ternary(tf, a, b)
if tf; v = string(a); else; v = string(b); end
end
