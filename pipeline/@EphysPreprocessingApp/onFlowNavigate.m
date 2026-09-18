function onFlowNavigate(obj, evt)
%onFlowNavigate  Open the setting a box in the Diagram draws.
%   Every box in the chart names the control(s) behind what it shows (see the
%   node helper in flowChartHTML); the page's setup() sends them here when the
%   box is clicked. The tab holding the first control is shown, the control is
%   scrolled into view and focused, and every control of the box is
%   highlighted until the next tab change (clearFlowHighlight).
%
%   See also flowNavControls, flowChartHTML, buildFlowTab.

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
