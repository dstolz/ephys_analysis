function syncAlignEnable(C)
%syncAlignEnable  Enable the alignment controls C whose options are in use.
%   The stop event's line, edge, which, n and scope only with the stop
%   event ticked; each n only for "nth".
en = @(c, tf) set(c, 'Enable', matlab.lang.OnOffSwitchState(tf));
en(C.N, string(C.Which.Value) == "nth");
stop = C.StopOn.Value;
en([C.StopLine C.StopEdge C.StopWhich C.StopScope], stop);
en(C.StopN, stop && string(C.StopWhich.Value) == "nth");
end
