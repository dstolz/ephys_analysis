function fillAlignItems(obj, C)
%fillAlignItems  List the active dataset's lines and trial parameters in a control set (AlignControls.fillItems).
AlignControls.fillItems(C, activeSource(obj));
end


function src = activeSource(obj)
src = [];
if isempty(obj.Runner) || obj.ActiveIdx < 1; return; end
try
    src = obj.Runner.source(obj.ActiveIdx);
catch
end
end
