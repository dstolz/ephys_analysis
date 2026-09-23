function setDropIfMember(obj, dd, value, name)
    % Set a dropdown's Value only if VALUE is one of its ItemsData (or Items
    % when there is no ItemsData) -- safe for restoring a stale saved config.
    % With NAME ("Section.Field"), a VALUE that is not an item joins
    % ApplyRejected, which applyConfig reports.
    v = char(string(value));
    if ~isempty(dd.ItemsData)
        ok = any(strcmp(v, dd.ItemsData));
    else
        ok = any(strcmp(v, dd.Items));
    end
    if ok
        dd.Value = v;
    elseif nargin >= 4
        obj.ApplyRejected(end+1) = name + " = """ + string(value) + """ (shown as """ + string(dd.Value) + """)";
    end
end
