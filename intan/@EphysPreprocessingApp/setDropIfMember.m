function setDropIfMember(~, dd, value)
    % Set a dropdown's Value only if VALUE is one of its ItemsData (or Items
    % when there is no ItemsData) -- safe for restoring a stale saved config.
    v = char(string(value));
    if ~isempty(dd.ItemsData)
        ok = any(strcmp(v, dd.ItemsData));
    else
        ok = any(strcmp(v, dd.Items));
    end
    if ok
        dd.Value = v;
    end
end
