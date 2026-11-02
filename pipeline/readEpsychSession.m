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
    trials = numericCells(trials);
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


function T = numericCells(T)
%numericCells  A numeric column struct2table left as a cell made numeric, NaN where empty.
%   A field that some trials lack ([] in a stitched session, or a trial
%   ended early) makes struct2table return a cell column, and double() of it
%   fails downstream; when every cell holds at most one number the column is
%   numeric with NaN for the empties.
for v = string(T.Properties.VariableNames)
    x = T.(v);
    if ~iscell(x); continue; end
    if all(cellfun(@(c) (isnumeric(c) || islogical(c)) && numel(c) <= 1, x))
        x(cellfun(@isempty, x)) = {NaN};
        T.(v) = cellfun(@double, x);
    end
end
end
