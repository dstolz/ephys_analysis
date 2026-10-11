function syncSynthControls(obj)
%syncSynthControls  Fill the Synthetic tab's table lists from the task's lines and parameters.
%   The units / LFP tables' Event lists hold the built-in task's lines
%   (plus any the design names), their Parameter lists its numeric Epsych2
%   parameters (synthSourceLists).
[lines, params] = obj.synthSourceLists();
D = obj.gatherSynthDesign();
lines = unique([lines, D.usedLines()], 'stable');
params = unique([params, D.usedParameters()], 'stable');
evList = cellstr(lines);
if isempty(evList); evList = {''}; end
parList = [{'(none)'}, cellstr(params)];
edges = cellstr(SyntheticDesign.Edges);
formats = struct( ...
    'Event', {[{'(none)'}, cellstr(lines)]}, 'Edge', {edges}, 'Parameter', {parList}, 'Name', 'char');
obj.SynthUnitsTable.ColumnFormat = columnFormats(obj.synthColumns("unit"), formats);
formats.Event = evList;   % an evoked potential needs a line
obj.SynthLFPTable.ColumnFormat = columnFormats(obj.synthColumns("lfp"), formats);
end


function F = columnFormats(vars, formats)
%columnFormats  A uitable ColumnFormat for VARS: the lists in FORMATS, 'numeric' for the rest.
F = repmat({'numeric'}, 1, numel(vars));
for j = 1:numel(vars)
    if isfield(formats, char(vars(j))); F{j} = formats.(vars(j)); end
end
end
