function refreshBank(obj)
%refreshBank  Show the bank folder and fill the dropdowns from the bank.
%   Setting Items / Value from code does not fire ValueChangedFcn, so this
%   never changes the chain; the caller resolves when it needs to.
obj.BankFolderField.Value = char(obj.Bank.Folder);
obj.BankFolderField.Tooltip = char(obj.Bank.Folder);
obj.fillCascade();
E = obj.Bank.Entries;
bad = E(arrayfun(@(e) ~isempty(e.Problems), E));
if isempty(bad)
    obj.setStatus(sprintf('Bank: %d entries.', numel(E)), false);
else
    ids = strings(1, numel(bad));
    for k = 1:numel(bad)
        ids(k) = bad(k).Id;
    end
    obj.setStatus(sprintf('Bank: %d entries; %d with problems (marked !): %s', numel(E), ...
        numel(bad), strjoin(ids, ", ")), true);
end
end
