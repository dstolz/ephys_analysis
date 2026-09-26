function setRows(obj, mode, channelNumbers, datasetName)
%setRows  How hardware channels become recording rows (no dialogs).
%   setRows("in-order")  every headstage channel of the chain, ascending
%   setRows("dataset", CHANNELNUMBERS, NAME)  a dataset's ChannelNumbers
%   setRows("custom", CHANNELNUMBERS)  0-based hardware channels in
%   recording order
arguments
    obj
    mode (1,1) string {mustBeMember(mode, ["in-order" "dataset" "custom"])}
    channelNumbers double = double.empty(1, 0)
    datasetName (1,1) string = ""
end
if mode ~= "in-order" && isempty(channelNumbers)
    error('ChannelMapperApp:NoChannels', 'Rows from a dataset or a list need its channel numbers.');
end
obj.RowsMode = mode;
obj.ChannelNumbers = double(channelNumbers(:)');
if mode == "in-order"
    obj.ChannelNumbers = double.empty(1, 0);
end
obj.DatasetName = "";
if mode == "dataset"
    obj.DatasetName = datasetName;
end
obj.fillCascade();
obj.resolve();
end
