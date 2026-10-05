function loadVizEvents(obj, out, read)
%loadVizEvents  The plotted dataset's digital-input events, for the Visualize plot.
%   obj.loadVizEvents(OUT, READ) finds the events of VizDataset (OUT: its
%   EphysDataset.outputs), taking the first of
%     1. the Signals step's extract: its events, with the lines named and
%        their polarity applied as when the step ran
%     2. the dataset's events cache, <Name>_events.mat (written by the
%        Trials tab, a Signals run or Read events), when it exists
%     3. with READ only, the recording itself (EphysDataset.digitalEvents,
%        which can mean reading all of it, and then writes the cache)
%   and gives 2 and 3 the polarity of the dataset's
%   TrialConfig.InvertedLines (digitalLinePolarity). It sets VizData.events
%   (EphysTraceViewer.eventLines: on the traces' clock) and
%   VizData.eventsNote, fills the Lines list (a line picked before stays
%   picked, else every line with an event is) and enables Read events
%   while there are none. The caller hands them to the viewer
%   (applyVizSettings "events") and draws.
%
%   See also onVizReadEvents, applyVizSettings, EphysTraceViewer.eventLines,
%   EphysDataset.digitalEvents.

d = obj.VizDataset;
E = EphysTraceViewer.emptyEvents();
note = "";
if out.has("extract")
    w = warning('off', 'MATLAB:load:variableNotFound');
    restore = onCleanup(@() warning(w));
    try
        S = out.load("extract", "events", "info");
        if isfield(S, 'events') && isstruct(S.events) && isscalar(S.events) && ~isempty(fieldnames(S.events))
            fs = NaN;
            if isfield(S, 'info') && isstruct(S.info) && isfield(S.info, 'origFs')
                fs = double(S.info.origFs);
            end
            E = EphysTraceViewer.eventLines(S.events, fs);
            note = "Events from the Signals step's extract.";
        end
    catch ME
        note = "The extract's events were not read: " + string(ME.message) + " ";
    end
    clear restore
end
cacheFile = fullfile(d.outputFolder(), d.Name + "_events.mat");
if isempty(E) && (read || isfile(cacheFile))
    try
        R = d.digitalEvents();
        inverted = string.empty(1, 0);
        if isfield(d.TrialConfig, 'InvertedLines')
            inverted = reshape(string(d.TrialConfig.InvertedLines), 1, []);
        end
        ev = digitalLinePolarity(R.events, inverted, R.nSamples, R.Fs);
        E = EphysTraceViewer.eventLines(ev, R.Fs);
        if R.source == "cache"
            note = "Events from " + d.Name + "_events.mat.";
        else
            note = "Events read from the recording.";
        end
    catch ME
        note = note + "The recording's events were not read: " + string(ME.message);
    end
end
if isempty(E) && note == ""
    note = "No events yet: none in a Signals extract or an events file. " + ...
        "Read events reads the recording's digital inputs.";
elseif ~isempty(E)
    n = arrayfun(@(e) numel(e.on), E);
    note = note + sprintf(" %d line(s), %d with events.", numel(E), nnz(n));
end
obj.VizData.events = E;
obj.VizData.eventsNote = note;

% The Lines list: every line, the ones picked before (else those with events) selected.
names = cell(1, 0);
if ~isempty(E); names = cellstr([E.name]); end
before = string(obj.VizEventLinesListBox.Value);
had = string(obj.VizEventLinesListBox.Items);
obj.VizEventLinesListBox.Items = names;
if ~isempty(E) && any(ismember(had, [E.name]))
    obj.VizEventLinesListBox.Value = cellstr(intersect([E.name], before, 'stable'));
elseif ~isempty(E)
    obj.VizEventLinesListBox.Value = names(arrayfun(@(e) ~isempty(e.on), E));
end
obj.VizEventsLabel.Text = note;
obj.VizEventsReadButton.Enable = matlab.lang.OnOffSwitchState(isempty(E));
end
