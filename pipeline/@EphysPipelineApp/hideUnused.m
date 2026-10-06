function tf = hideUnused(obj)
%hideUnused  Whether the Diagram leaves out what the config does not use (false before the tab is built).
tf = ~isempty(obj.FlowHideCheckBox) && isvalid(obj.FlowHideCheckBox) && logical(obj.FlowHideCheckBox.Value);
end
