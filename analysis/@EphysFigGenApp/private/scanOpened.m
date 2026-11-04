function scanOpened(obj)
%scanOpened  Scan the source of a config just opened, its own selection kept (openConfigFile, openSource).
%   gatherSourceSection takes a project's selection from the Run ticks of
%   the last scan, and those belong to the config shown before: they are
%   set aside for the scan, so the opened config's Selection and Datasets
%   tick the rows. A scan that does not get as far as listing the
%   datasets leaves the old ticks with the old datasets.
old = obj.Ticked;
obj.Ticked = logical.empty(1, 0);
obj.onScan();
if isempty(obj.Runner) || numel(obj.Ticked) ~= numel(obj.Runner.Keys)
    obj.Ticked = old;
end
end
