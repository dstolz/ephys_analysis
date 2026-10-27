function applyAlignControls(obj, C, ref, win, sel)
%applyAlignControls  Show an event reference, window and selection in a control set.
%   An Event sequence window open on C's sequences closes; then
%   AlignControls.show puts the values in C.
closeSequenceDialog(obj, [C.SeqText C.StopSeqText]);
AlignControls.show(C, ref, win, sel);
end
