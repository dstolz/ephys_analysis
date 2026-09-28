function resetFlag(obj, name)
%resetFlag  Set a guard flag (Applying / Syncing) back to false; used with onCleanup.
if isvalid(obj)
    obj.(name) = false;
end
end
