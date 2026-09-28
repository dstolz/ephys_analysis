function chain = currentChain(obj)
%currentChain  The chain the controls describe, as ChannelMap.resolve takes it.
%   Empty ([]) when the package or the headstage is missing from the bank.
b = obj.Bank;
chain = [];
if obj.PackageId == "" || ~b.has(obj.PackageId) || obj.HeadstageId == "" || ~b.has(obj.HeadstageId)
    return
end
chain = struct();
chain.probe = [];
if obj.ProbeId ~= "" && b.has(obj.ProbeId)
    chain.probe = b.get(obj.ProbeId);
end
chain.package = b.get(obj.PackageId);
chain.adaptors = {};
hs = b.get(obj.HeadstageId);
n = obj.HeadstageCount;
off = obj.Offsets;
if numel(off) < n
    off(end + 1:n) = 0;
end
chain.headstages = struct('Entry', repmat({hs}, 1, n), 'ChannelOffset', num2cell(off(1:n)));
chain.mates = obj.Mates;
chain.channelNumbers = [];
if obj.RowsMode ~= "in-order"
    chain.channelNumbers = obj.ChannelNumbers;
end
chain.rowsMode = obj.RowsMode;
chain.dataset = obj.DatasetName;
end
