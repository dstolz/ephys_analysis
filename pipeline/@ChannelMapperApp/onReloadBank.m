function onReloadBank(obj)
%onReloadBank  Read the bank folder again and re-resolve (entries may have changed).
obj.Bank.reload();
obj.refreshBank();
obj.refreshMatesTable();
obj.resolve();
end
