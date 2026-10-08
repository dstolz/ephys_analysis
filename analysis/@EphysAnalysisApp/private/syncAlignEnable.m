function syncAlignEnable(C)
%syncAlignEnable  Enable the alignment controls C whose options are in use.
%   The stop event's line, edge, which, n, scope and shift only with the
%   stop event ticked; each n only for "nth"; each shift's unit only with
%   a parameter to shift by.
en = @(c, tf) set(c, 'Enable', matlab.lang.OnOffSwitchState(tf));
en(C.N, string(C.Which.Value) == "nth");
stop = C.StopOn.Value;
en([C.StopLine C.StopEdge C.StopWhich C.StopScope], stop);
en(C.StopN, stop && string(C.StopWhich.Value) == "nth");
en(C.StopShiftParam, stop);
shifts = @(dd) ~ismember(strtrim(string(dd.Value)), ["(none)" ""]);
en(C.ShiftUnit, shifts(C.ShiftParam));
en(C.StopShiftUnit, stop && shifts(C.StopShiftParam));
end
