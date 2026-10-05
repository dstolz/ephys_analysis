function onRemoveProbeRule(obj)
%onRemoveProbeRule  Remove the rule rows selected in the probe rules table.
%   Datasets that already got a probe from a rule keep it.
rows = obj.ProbeRulesTable.UserData;
n = size(obj.ProbeRulesTable.Data, 1);
rows = rows(rows >= 1 & rows <= n);
if isempty(rows)
    uialert(obj.Fig, "Click a rule in the table first.", "Probe rules");
    return
end
obj.ProbeRulesTable.Data(rows, :) = [];
obj.ProbeRulesTable.UserData = [];
obj.onConfigChanged();
end
