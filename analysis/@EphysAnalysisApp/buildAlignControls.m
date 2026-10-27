function C = buildAlignControls(obj, parents, changed)
%buildAlignControls  Event-reference, window and trial-selection controls in three containers.
%   C = buildAlignControls(obj, PARENTS, CHANGED) builds AlignControls'
%   set (AlignControls.build) in PARENTS (three panels: C.RefGrid,
%   C.WindowGrid, C.SelectionGrid) with the app's Event sequence window
%   (editSequence) and filter help (onFilterHelp). Every control calls
%   CHANGED(PART) when edited, PART "ref", "window" or "selection". The
%   Alignment tab builds one set in three titled panels for the config's
%   Defaults, the Figures tab two more in sections of its editor for a
%   figure's and a panel's own values (applyAlignControls /
%   AlignControls.read move values in and out; fillAlignItems lists the
%   active dataset's lines and parameters). "Epoch Diagram" (C.Diagram),
%   under the window, is left to the caller to wire to onShowEpochs.
C = AlignControls.build(parents, changed, EditSequence=@(varargin) obj.editSequence(varargin{:}), ...
    FilterHelp=@() obj.onFilterHelp());
end
