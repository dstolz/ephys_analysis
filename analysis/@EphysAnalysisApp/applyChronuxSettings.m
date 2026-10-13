function applyChronuxSettings(obj, S)
%applyChronuxSettings  Set the Chronux tab's controls from settings S (chronuxSettings; a remembered preference).
%   The signal and channels are the dataset's and stay as they are; a
%   value a control cannot take is left as it was.
C = obj.ChronuxControls;
S = chronuxSettings(S);
set1(C.analysis, S.analysis);
set1(C.timeBase, S.timeBase);
set1(C.pre, S.window(1));
set1(C.post, S.window(2));
set1(C.useGroups, S.useGroups);
set1(C.from, S.range(1));
if isinf(S.range(2)); set1(C.to, []); else; set1(C.to, S.range(2)); end
set1(C.segment, S.segmentSec);
set1(C.taperMode, S.taperMode);
set1(C.TW, S.TW);
set1(C.K, S.K);
set1(C.W, S.W);
set1(C.p, S.p);
set1(C.pad, S.pad);
set1(C.fmin, S.fpass(1));
if isinf(S.fpass(2)); set1(C.fmax, []); else; set1(C.fmax, S.fpass(2)); end
set1(C.err, S.err);
set1(C.errP, S.errP);
set1(C.detrend, S.detrend);
set1(C.mwWin, S.movingwin(1));
set1(C.mwStep, S.movingwin(2));
set1(C.baseline, S.baseline);
set1(C.baseFrom, S.baselineWindow(1));
set1(C.baseTo, S.baselineWindow(2));
d = S.display;
set1(C.scale, d.scale);
set1(C.layout, d.layout);
set1(C.showErr, d.showErr);
set1(C.maxTiles, d.maxTiles);
set1(C.ylim, strjoin(string(d.ylim), " "));
set1(C.clim, strjoin(string(d.clim), " "));
obj.syncChronuxControls();
end


function set1(c, v)
try
    if isprop(c, 'ItemsData') && ~isempty(c.ItemsData) && ~any(string(c.ItemsData) == string(v)); return; end
    c.Value = v;
catch
end
end
