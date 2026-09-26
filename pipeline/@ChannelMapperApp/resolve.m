function R = resolve(obj)
%resolve  Resolve the chain the controls describe and show the result.
%   R (also obj.Result) is ChannelMap.resolve's struct, empty when the
%   chain is incomplete.
chain = obj.currentChain();
if isempty(chain)
    obj.Result = struct([]);
else
    try
        obj.Result = ChannelMap.resolve(chain);
    catch ME
        obj.Result = struct([]);
        obj.setStatus("Could not resolve the chain: " + ME.message, true);
    end
end
R = obj.Result;
obj.refreshAll();
end
