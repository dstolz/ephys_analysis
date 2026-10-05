function setControlValue(obj, ctrl, value, name)
%setControlValue  Show a config value in a control (the apply*Section helpers).
%   obj.setControlValue(CTRL, VALUE, NAME) sets CTRL.Value. A value the
%   control rejects, such as NaN or a number outside a numeric field's
%   Limits, is clamped into the Limits when it is finite, else the control
%   keeps the value it has; either way NAME ("Section.Field") with both
%   values joins ApplyRejected, which applyConfig reports.
try
    ctrl.Value = value;
    return
catch
end
if isnumeric(value) && isscalar(value) && isfinite(value) && isprop(ctrl, 'Limits')
    try
        ctrl.Value = min(max(value, ctrl.Limits(1)), ctrl.Limits(2));
    catch
    end
end
obj.ApplyRejected(end+1) = name + " = " + shown(obj, value) + " (shown as " + shown(obj, ctrl.Value) + ")";
end


function t = shown(obj, v)
%shown  VALUE as text for the report.
if isnumeric(v) && isscalar(v)
    t = string(obj.numberText(v));
else
    t = strjoin(string(v), ", ");
end
end
