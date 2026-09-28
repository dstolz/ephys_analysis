function file = saveMapping(obj, name, opts)
%saveMapping  Save the chain and its result to the bank as mappings/<name>.json (no dialogs).
%   Errors HardwareBank:Exists unless Overwrite=true, HardwareBank:Invalid
%   when the bank does not have a device the chain names.
arguments
    obj
    name (1,1) string
    opts.Overwrite (1,1) logical = false
    opts.Notes (1,1) string = ""
end
R = obj.Result;
if isempty(R)
    error('ChannelMapperApp:NoChain', 'Choose a package and a headstage first.');
end
m = ChannelMap.mappingStruct(R, Name=name, Notes=opts.Notes);
file = obj.Bank.saveEntry(m, Overwrite=opts.Overwrite);
obj.MappingName = HardwareBank.safeName(name);
obj.refreshBank();
obj.updateTitle();
obj.setStatus("Saved the mapping " + obj.MappingName + " (" + file + ").", false);
end
