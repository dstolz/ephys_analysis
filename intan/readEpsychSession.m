function [trials, info, meta] = readEpsychSession(file)
%readEpsychSession  Load an Epsych2 behavioral session (.mat with Data + Info).
%   [TRIALS, INFO, META] = readEpsychSession(file)
%
%   Epsych2 (https://github.com/dstolz/epsych2) saves one plain .mat per
%   subject and session with two variables:
%     Data   struct array, one element per completed trial: one field per
%            readable parameter (stimulus values, RespCode/ResponseCode, ...)
%            plus TrialIndex (chronological order), TrialID (row of the
%            compiled trial table - NOT the presentation order),
%            computerTimestamp (datetime at trial end) and isTest
%     Info   the session snapshot: Subject, StartTime, Protocol, TrialTable,
%            WriteParams, DataFilename, FormatVersion, ...
%   No Epsych2 code is needed to read it.
%
%   TRIALS is struct2table(Data): one row per trial, one column per
%   parameter, values as saved (response codes are left as raw bit masks).
%   INFO is the Info struct as saved. META is epsychSessionMeta(file) plus
%   responseCodeField ("RespCode" | "ResponseCode" | "") and parameterNames.
%
%   Pairing trials with the recording's digital-input events is a separate
%   step (see the pipeline docs); this function only loads.
%
%   See also epsychSessionMeta, findEpsychSessions, matchEpsychSession,
%   EphysDataset.readBehavior.

arguments
    file (1,1) string
end

meta = epsychSessionMeta(file);
L = load(file, 'Data', 'Info');
Data = L.Data;
info = L.Info;

if isempty(Data)
    trials = table();
else
    if ~isstruct(Data)
        error('readEpsychSession:NotEpsych', 'Data in %s is not a struct array.', file);
    end
    trials = struct2table(Data(:), 'AsArray', true);
end

rc = "";
for f = ["RespCode" "ResponseCode"]
    if ismember(f, string(trials.Properties.VariableNames))
        rc = f;
        break
    end
end
meta.responseCodeField = rc;
meta.parameterNames = string(trials.Properties.VariableNames);
meta.nTrials = height(trials);
end
