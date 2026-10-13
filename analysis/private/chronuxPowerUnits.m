function u = chronuxPowerUnits(u)
%chronuxPowerUnits  The units of power of a signal in units U: µV²/Hz, V²/Hz, ...
u = string(u);
if startsWith(u, "micro") || u == "uV" || u == "µV"
    u = "µV²/Hz";
elseif startsWith(u, "volt") || u == "V"
    u = "V²/Hz";
else
    u = u + "²/Hz";
end
end
