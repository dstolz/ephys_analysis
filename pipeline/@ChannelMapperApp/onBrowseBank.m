function onBrowseBank(obj)
%onBrowseBank  Use another hardware bank folder.
folder = uigetdir(char(obj.Bank.Folder), 'Choose a hardware bank folder');
figure(obj.Fig);
if isequal(folder, 0)
    return
end
obj.Bank = HardwareBank(string(folder));
obj.refreshBank();
obj.onChainChanged("package");
end
