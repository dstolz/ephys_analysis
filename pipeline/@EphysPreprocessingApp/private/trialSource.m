function src = trialSource(d, quick)
%trialSource  Where a dataset's trials come from, as the Trials tab uses it.
%   SRC = trialSource(D) is "epsych2" when D's Epsych2 session file is
%   there, "epocs" when D is a TDT block whose trial line is an epoc store
%   (EphysDataset.behaviorSource), "" otherwise (also a session associated
%   but missing). trialSource(D, true) does not open a recording: a dataset
%   whose reader is not set up yet, or is not TDT, counts as "" unless it
%   has a session file (for the tab strip, refreshed often).
if nargin < 2; quick = false; end
src = "";
if d.BehaviorFile ~= ""
    if isfile(d.BehaviorFile); src = "epsych2"; end
    return
end
if quick && (isempty(d.Reader) || ~isa(d.Reader, 'TDTReader') || isnan(d.Fs)); return; end
try
    if d.behaviorSource() == "epocs"; src = "epocs"; end
catch
end
end
