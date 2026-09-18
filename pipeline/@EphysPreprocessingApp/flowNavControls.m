function ctrls = flowNavControls(obj, target)
%flowNavControls  The controls one Diagram box stands for.
%   CTRLS = app.flowNavControls(TARGET) resolves a box's target (see the node
%   helper in flowChartHTML) into a cell array of UI components, in the order
%   named. TARGET is a comma-separated list of
%     <PropertyName>    a control property of the app, e.g. ArtThresholdField
%     ks4.<parameter>   a Kilosort4 field, e.g. ks4.nblocks (obj.ParamControls)
%   Names that are not controls of this app are skipped, so CTRLS may be
%   shorter than the list or empty.
%
%   See also onFlowNavigate, flowChartHTML.

ctrls = {};
for name = strip(split(string(target), ","))'
    if name == ""; continue; end
    if startsWith(name, "ks4.")
        p = extractAfter(name, "ks4.");
        if isfield(obj.ParamControls, p); c = obj.ParamControls.(p); else; c = []; end
    elseif isprop(obj, name)
        c = obj.(char(name));
    else
        c = [];
    end
    if isscalar(c) && isgraphics(c)
        ctrls{end+1} = c; %#ok<AGROW>
    end
end
end
