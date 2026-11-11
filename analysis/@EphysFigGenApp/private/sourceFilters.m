function F = sourceFilters(S)
%sourceFilters  The signals' filters of config Source S (Source.SignalFilter): a field per signal, each a SignalFilter.
%   F = sourceFilters(S) is S.SignalFilter with every signal's field
%   (DatasetOutputs.SignalTypes), each normalized (SignalFilter.normalize:
%   off when missing). A config made in a MATLAB session that loaded
%   EphysAnalysisConfig before the field existed has none (a class's
%   property defaults are evaluated once per session, until clear
%   classes): every signal is then off, and the app goes on.
%
%   See also showSignalFilter, onSignalFilter, sourceRates, SignalFilter.normalize.
d = struct();
if isstruct(S) && isfield(S, 'SignalFilter') && isstruct(S.SignalFilter); d = S.SignalFilter; end
F = struct();
for s = DatasetOutputs.SignalTypes
    f = [];
    if isfield(d, s); f = d.(s); end
    F.(s) = SignalFilter.normalize(f);
end
end
