function restoreLastChain(obj)
%restoreLastChain  Reopen the chain the window showed when it last closed.
%   Falls back to the bank's first saved mapping, then to its first
%   package, when there is no remembered chain or its hardware is gone.
g = obj.PrefGroup;
if ispref(g, 'LastChain')
    try
        L = getpref(g, 'LastChain');
        need = [string(L.package), string(L.headstage)];
        if string(L.probe) ~= ""
            need(end + 1) = string(L.probe);
        end
        if all(arrayfun(@(i) obj.Bank.has(i), need))
            obj.ProbeId = string(L.probe);
            obj.PackageId = string(L.package);
            obj.HeadstageId = string(L.headstage);
            obj.HeadstageCount = double(L.count);
            obj.Offsets = double(L.offsets(:)');
            from = string(L.from); to = string(L.to); ori = string(L.orientation);
            mates = struct('From', {}, 'To', {}, 'Orientation', {});
            for k = 1:numel(from)
                mates(k) = struct('From', from(k), 'To', to(k), 'Orientation', ori(k));
            end
            obj.Mates = mates;
            obj.MappingName = string(L.mapping);
            if numel(obj.Offsets) ~= obj.HeadstageCount
                obj.defaultMatesNow();
            end
            obj.fillCascade();
            obj.refreshMatesTable();
            obj.resolve();
            return
        end
    catch
        % fall through to the defaults
    end
end
M = obj.Bank.list("mapping");
for k = 1:numel(M)
    try
        obj.loadMapping(M(k).Id);
        return
    catch
    end
end
P = obj.Bank.list("package");
if ~isempty(P)
    obj.selectPackage(P(1).Id);
else
    obj.fillCascade();
    obj.refreshMatesTable();
    obj.resolve();
end
end
