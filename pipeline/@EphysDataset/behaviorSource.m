function [src, store] = behaviorSource(obj)
%behaviorSource  Where this dataset's trials come from.
%   [SRC, STORE] = ds.behaviorSource() returns
%     "epsych2"  an Epsych2 session is associated (BehaviorFile, also while
%                its file is not there); it always wins
%     "epocs"    no session, and the recording is a TDT block whose event
%                line TrialConfig.TrialLine is one of its epoc stores: each
%                epoc of that store is a trial and the other epoc stores give
%                the trial parameters (see readBehavior, TDTReader.epocTrials);
%                STORE is the store's name (the line's native name)
%     ""         neither
%   The trial line is matched by its final name (after LabelField /
%   LineNames), as pairTrials matches it.
%
%   See also EphysDataset.readBehavior, EphysDataset.pairTrials.

store = "";
if obj.BehaviorFile ~= ""
    src = "epsych2";
    return
end
src = "";
if isempty(obj.Reader); obj.discoverFiles(); end
if isempty(obj.Reader) || ~isa(obj.Reader, 'TDTReader'); return; end
if isnan(obj.Fs) || isempty(obj.PerFile); obj.refreshMetadata(); end
[labelField, lineNames] = obj.lineNaming("", []);
L = EphysDataset.relabelEvents(struct('events', struct(), 'digInNames', obj.DigInNames, ...
    'digInNativeNames', obj.DigInNativeNames), labelField, lineNames);
k = find(L.digInNames == string(obj.TrialConfig.TrialLine), 1);
if isempty(k); return; end
src = "epocs";
store = L.digInNativeNames(k);
end
