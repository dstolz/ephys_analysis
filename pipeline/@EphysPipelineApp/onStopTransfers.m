function onStopTransfers(obj)
%onStopTransfers  Stop copying the outputs (Stop copying..., after a confirmation).
%   Every transfer still going is canceled (OutputTransfer.cancel): the
%   files being copied stop where they are and what was copied stays at
%   the destination; the rest are not copied, and a move removes nothing
%   more here. A Run under way goes on without copying.
live = obj.Transfers(~arrayfun(@(X) X.Done, obj.Transfers));
if isempty(live); return; end
answer = uiconfirm(obj.Fig, ...
    "Stop copying the outputs?" + newline + newline + ...
    "The files being copied stop where they are; what is already copied stays at the destination. " + ...
    "The outputs not copied yet are not copied, and a move removes nothing more here: they stay where they are." + ...
    newline + newline + "Running the pipeline again with Copy outputs on copies them.", ...
    "Stop copying", "Options", ["Stop copying", "Keep copying"], "DefaultOption", 2, "CancelOption", 2);
if answer ~= "Stop copying"; return; end
for X = live
    X.cancel();
end
obj.log("[transfer] stopped by the user");
obj.pollTransfers();
end
