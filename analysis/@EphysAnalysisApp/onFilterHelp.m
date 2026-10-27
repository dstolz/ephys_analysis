function onFilterHelp(obj)
%onFilterHelp  What a trial filter can use: the active dataset's columns, the response words, the functions.
src = [];
if ~isempty(obj.Runner) && obj.ActiveIdx >= 1
    try
        src = obj.Runner.source(obj.ActiveIdx);
    catch
    end
end
uialert(obj.Fig, AlignControls.filterHelpText(src), "Trial filter", "Icon", "info");
end
