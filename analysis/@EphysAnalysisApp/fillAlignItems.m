function fillAlignItems(obj, C)
%fillAlignItems  List the active dataset's lines and trial parameters in a control set.
%   The line boxes offer "Trial" and every digital line (the extract's and
%   the trials'); the group-by boxes every Epsych2 parameter. The boxes are
%   editable, so a value the active dataset lacks stays as typed.
lines = "Trial";
params = string.empty(1, 0);
src = activeSource(obj);
if ~isempty(src)
    lines = [lines string(fieldnames(src.events)).'];
    if src.hasTrials && height(src.trials) > 0
        lines = [lines string(fieldnames(src.trials.TrialEvents)).'];
    end
    params = src.paramNames;
end
lines = unique(lines, 'stable');
setItems(C.Line, lines);
setItems(C.StopLine, lines);
setItems(C.Group1, ["(none)" params]);
setItems(C.Group2, ["(none)" params]);
end


function setItems(dd, items)
v = string(dd.Value);
if ~ismember(v, items); items = [items v]; end
dd.Items = items;
dd.Value = char(v);
end


function src = activeSource(obj)
src = [];
if isempty(obj.Runner) || obj.ActiveIdx < 1; return; end
try
    src = obj.Runner.source(obj.ActiveIdx);
catch
end
end
