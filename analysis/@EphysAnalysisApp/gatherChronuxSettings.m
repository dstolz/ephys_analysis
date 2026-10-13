function S = gatherChronuxSettings(obj)
%gatherChronuxSettings  The Chronux tab's settings (chronuxSettings), from its controls.
%   Errors chronuxSettings:* when a value cannot be used (the caller says why).
C = obj.ChronuxControls;
ch = C.channels.Value;
if iscell(ch); ch = cell2mat(ch); end
sig = string(C.signal.Value);
if sig == ""; sig = "LFP"; end
s = struct();
s.analysis = string(C.analysis.Value);
s.signal = sig;
s.channels = reshape(double(ch), 1, []);
un = C.units.Value;
if iscell(un); un = cell2mat(un); end
s.spikeSource = string(C.spikeSource.Value);
s.units = reshape(double(un), 1, []);
s.pairMode = string(C.pairMode.Value);
s.overTime = C.overTime.Value;
s.seed = numberOr(C.seed.Value, 1);
s.partner = numberOr(C.partner.Value, 2);
s.unitSeed = numberOr(C.unitSeed.Value, 1);
s.unitPartner = numberOr(C.unitPartner.Value, 2);
s.fieldChannel = numberOr(C.fieldChannel.Value, 1);
s.spikeFs = C.spikeFs.Value;
s.fscorr = C.fscorr.Value;
s.timeBase = string(C.timeBase.Value);
s.window = [C.pre.Value C.post.Value];
s.useGroups = C.useGroups.Value;
s.range = [C.from.Value orInf(C.to.Value)];
s.segmentSec = C.segment.Value;
s.taperMode = string(C.taperMode.Value);
s.TW = C.TW.Value;
s.K = C.K.Value;
s.W = C.W.Value;
s.p = C.p.Value;
s.pad = C.pad.Value;
s.fpass = [C.fmin.Value orInf(C.fmax.Value)];
s.err = string(C.err.Value);
s.errP = C.errP.Value;
s.detrend = string(C.detrend.Value);
s.movingwin = [C.mwWin.Value C.mwStep.Value];
s.baseline = string(C.baseline.Value);
s.baselineWindow = [C.baseFrom.Value C.baseTo.Value];
s.display = struct('scale', string(C.scale.Value), 'layout', string(C.layout.Value), 'showErr', C.showErr.Value, ...
    'showPhase', C.showPhase.Value, 'maxTiles', C.maxTiles.Value, 'ylim', twoNumbers(C.ylim.Value), ...
    'clim', twoNumbers(C.clim.Value), 'page', max(1, obj.ChronuxPage));
S = chronuxSettings(s);
end


function v = numberOr(v, default)
%numberOr  A dropdown's number, DEFAULT when it holds none (an empty file).
if ~isnumeric(v) || ~isscalar(v); v = default; end
end


function v = orInf(v)
if isempty(v); v = Inf; end
end


function v = twoNumbers(txt)
%twoNumbers  [low high] from text such as "-3 3"; [] for anything else (automatic).
v = sscanf(char(txt), '%f').';
if numel(v) ~= 2 || v(2) <= v(1); v = zeros(1, 0); end
end
