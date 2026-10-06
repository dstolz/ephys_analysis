function onResetSIParams(obj)
%onResetSIParams  Put the SpikeInterface sorter's parameters back to its defaults.
%   Sorting.SIParams.<sorter> becomes "" (SpikeInterface's defaults when it
%   runs) and the text area shows those defaults. The other sorters'
%   parameters stay.
%
%   See also onResetKS4Params, showSorterControls.
sorter = obj.SIParamsShown;
if sorter == ""; return; end
txt = obj.siDefaultParams(sorter);
if txt == ""; txt = "{" + newline + "}"; end
obj.SIParamsArea.Value = cellstr(splitlines(txt));
obj.onConfigChanged();   % the defaults (or {}) are stored as "" (gatherSortingSection)
obj.log("%s", sorter + " parameters reset to SpikeInterface's defaults.");
obj.setStatus(sorter + " parameters reset to defaults.");
end
