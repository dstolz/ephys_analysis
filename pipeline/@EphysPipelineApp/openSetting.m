function [ok, tab] = openSetting(obj, target)
%openSetting  Show the setting(s) named by TARGET: their tab, scrolled into view, focused and highlighted.
%   [OK, TAB] = obj.openSetting(TARGET) resolves TARGET (control property
%   names, comma separated; see flowNavControls) into controls, shows the
%   tab that holds the first one, scrolls each control into view, marks it
%   (the highlight lasts until the next tab change or the next Diagram
%   click: clearFlowHighlight) and focuses the first. OK is false, and
%   nothing moves, when TARGET names no control of the app. TAB is the tab
%   shown ([] when there is none).
%
%   The Diagram's boxes (onFlowNavigate) and the Run tab's issues table
%   (onIssueActivated) both open settings through here.
%
%   See also flowNavControls, onFlowNavigate, onIssueActivated.
arguments
    obj (1,1) EphysPipelineApp
    target (1,1) string
end
tab = [];
ctrls = obj.flowNavControls(target);
obj.clearFlowHighlight();
ok = ~isempty(ctrls);
if ~ok; return; end
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
%highlight  Mark C as the control that was opened, remembering its look.
%   Tables are left alone: recoloring one recolors every cell in it.
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
