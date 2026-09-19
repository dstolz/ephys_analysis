function E = namedTrialsEvents(obj, S)
%namedTrialsEvents  The loaded (native-keyed) events named by the Signals
%   section S (default obj.Config.Signals): LabelField and LineNames, see
%   EphysDataset.relabelEvents. [] when no events are loaded.
if nargin < 2; S = obj.Config.Signals; end
E = [];
if isempty(obj.TrialsEvents); return; end
E = EphysDataset.relabelEvents(obj.TrialsEvents, string(S.LabelField), reshape(string(S.LineNames), 1, []));
end
