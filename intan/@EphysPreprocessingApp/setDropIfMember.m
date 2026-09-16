function setDropIfMember(~, dd, value)
    % Set a dropdown's Value only if VALUE is one of its Items (safe for
    % restoring a possibly-stale saved config).
    v = char(string(value));
    if ismember(v, dd.Items)
        dd.Value = v;
    end
end
