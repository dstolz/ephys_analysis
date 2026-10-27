function editSequence(obj, holder, lineCtl, edgeCtl, done)
%editSequence  Edit an event sequence in a window of its own.
%   obj.editSequence(HOLDER, LINECTL, EDGECTL, DONE) opens the "Event
%   sequence" window (AlignControls.editSequence) on the sequence the
%   label HOLDER keeps, as obj.SequenceDialog. One window at a time:
%   opening another closes it, and so does showing other values in
%   HOLDER's panel (closeSequenceDialog).
%
%   See also AlignControls, eventRef, eventRefLabel.

if ~isempty(obj.SequenceDialog) && isvalid(obj.SequenceDialog)
    delete(obj.SequenceDialog);
end
obj.SequenceDialog = AlignControls.editSequence(holder, lineCtl, edgeCtl, done);
end
