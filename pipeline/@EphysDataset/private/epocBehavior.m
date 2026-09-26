function [trials, info, meta] = epocBehavior(obj, store)
%epocBehavior  Trials of a TDT block from its epocs, shaped like readEpsychSession's.
%   [TRIALS, INFO, META] = epocBehavior(DS, STORE) makes one trial per epoc
%   of the epoc store STORE that lies on the stream (TDTReader.epocTrials),
%   in order, so trial i is interval i of that store's event line.
%     TRIALS  table: TrialIndex (1..n), then one column per epoc store,
%             named by its final line name (LabelField / LineNames): the
%             trial store's own values, then each other store's value at the
%             trial's onset (NaN when none is active; "Tick" is left out)
%     INFO    Source ("TDT epocs"), TrialStore, Block, StartTime, and
%             WriteParams (the parameter columns, as Epsych2's Info lists
%             them)
%     META    the readEpsychSession meta fields: file "" (no session file),
%             stem (the block name), subject "" , startTime (the block start),
%             nTrials, formatVersion "", dataFilename "", hasTrialTable false,
%             responseCodeField "" (no response codes), parameterNames

T = obj.Reader.epocTrials(store);
[labelField, lineNames] = obj.lineNaming("", []);
L = EphysDataset.relabelEvents(struct('events', struct(), 'digInNames', obj.DigInNames, ...
    'digInNativeNames', obj.DigInNativeNames), labelField, lineNames);
nameOf = @(native) EphysReader.eventKey(L.digInNames(find(L.digInNativeNames == native, 1)));

n = numel(T.onset);
trials = table((1:n).', 'VariableNames', {'TrialIndex'});
cols = nameOf(T.store);
trials.(cols) = T.value;
for p = T.params
    c = nameOf(p.name);
    trials.(c) = p.value;
    cols(end+1) = c; %#ok<AGROW>
end

info = struct('Source', "TDT epocs", 'TrialStore', T.store, 'Block', obj.Name, ...
    'StartTime', obj.AcqDate, 'WriteParams', {cellstr(cols)});
meta = struct('file', "", 'stem', obj.Name, 'subject', "", 'startTime', obj.AcqDate, ...
    'nTrials', n, 'formatVersion', "", 'dataFilename', "", 'hasTrialTable', false, ...
    'responseCodeField', "", 'parameterNames', string(trials.Properties.VariableNames));
end
