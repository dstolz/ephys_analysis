classdef SyntheticDesign
    %SyntheticDesign  What a synthetic recording holds: units, evoked potentials, noise and a sine.
    %   A SyntheticDesign describes the neural signals makeSyntheticRecording
    %   writes, independently of when the events happen (the built-in task,
    %   syntheticTaskSchedule). The signals are deliberately simple, so that
    %   what the pipeline and the analyses should recover is exact:
    %
    %     Units    one row per spiking unit: a fixed waveform (a negative
    %              Gaussian trough of AmplitudeUV, sigma 0.2 ms) on its
    %              Channel only, fired as a Poisson process (2 ms dead time)
    %              at BaselineHz. When Event names a digital line, the rate is
    %              BaselineHz x Gain from LatencyMs to LatencyMs + DurationMs
    %              after every Edge ("onset" | "offset") of that line: a
    %              step up (Gain > 1) or down (Gain < 1, 0 = silent).
    %     LFP      one row per evoked potential locked to a line's edges: a
    %              raised-cosine deflection of AmplitudeUV (signed) that
    %              starts LatencyMs after the edge, peaks halfway through and
    %              ends DurationMs later, on Channel or (NaN) every channel.
    %     NoiseUV  RMS of the white Gaussian noise on every channel.
    %     SineUV   amplitude of a 2 Hz sine on every channel (SineHz; 0 =
    %              off). It stands in for the ongoing LFP, so that detectors
    %              whose thresholds follow the background (the artifact
    %              detector's running RMS) behave as on real recordings
    %              instead of flagging every spike and evoked potential.
    %              The spike band removes it; event-locked averages over
    %              trials at random phases cancel it.
    %
    %   Unit columns
    %     Name         unique label
    %     Channel      the channel it is on (1-based)
    %     AmplitudeUV  trough amplitude (> 0)
    %     BaselineHz   rate away from its responses
    %     Event        digital line it responds to; "" = none
    %     Edge         "onset" | "offset"
    %     Gain         rate multiplier inside the response window
    %     LatencyMs    edge to response start (may be negative)
    %     DurationMs   response length (> 0)
    %     Parameter    Epsych2 trial parameter that scales the response; ""
    %                  = none. The rate is then BaselineHz x (1 + (Gain - 1)
    %                  x v), v the trial's value normalized to 0..1 over the
    %                  session; events outside any trial respond fully
    %
    %   LFP columns
    %     Name, Event, Edge, LatencyMs, DurationMs, Parameter  as for units
    %                  (Event is required; Parameter scales the amplitude)
    %     Channel      the channel it is on; NaN = every channel
    %     AmplitudeUV  peak amplitude, signed (negative = negative-going)
    %
    %   Usage
    %     D = SyntheticDesign.builtIn(16);        % what makeSyntheticRecording writes by default
    %     D.Units(end+1, :) = SyntheticDesign.newUnit("tone", "Stim");
    %     D.LFP(end+1, :) = SyntheticDesign.newLFP("Stim");
    %     issues = D.validate(["Stim" "InTrial"], "Depth", 16);
    %     D.save("design.json"); D2 = SyntheticDesign.load("design.json");
    %
    %   See also makeSyntheticRecording, syntheticModel, syntheticTaskSchedule.

    properties
        NoiseUV (1,1) double = 10
        SineUV (1,1) double = 100
        Units table = SyntheticDesign.unitTable(0)
        LFP table = SyntheticDesign.lfpTable(0)
    end

    properties (Constant)
        Edges = ["onset" "offset"]
        SineHz = 2
        UnitColumns = ["Name" "Channel" "AmplitudeUV" "BaselineHz" "Event" "Edge" "Gain" ...
            "LatencyMs" "DurationMs" "Parameter"]
        LFPColumns = ["Name" "Channel" "AmplitudeUV" "Event" "Edge" "LatencyMs" "DurationMs" "Parameter"]
        FileSchema = "ephys-synthetic-design/2"
    end

    methods
        function obj = set.Units(obj, T)
            obj.Units = SyntheticDesign.normalizeTable(T, "unit");
        end

        function obj = set.LFP(obj, T)
            obj.LFP = SyntheticDesign.normalizeTable(T, "lfp");
        end

        function lines = usedLines(obj)
            %usedLines  The digital lines the units and evoked potentials are linked to.
            lines = unique([obj.Units.Event; obj.LFP.Event]).';
            lines = lines(lines ~= "");
        end

        function params = usedParameters(obj)
            %usedParameters  The Epsych2 parameters that scale a response.
            params = unique([obj.Units.Parameter; obj.LFP.Parameter]).';
            params = params(params ~= "");
        end

        function issues = validate(obj, lineNames, paramNames, nChannels)
            %validate  Problems with the design for a schedule and a recording.
            %   ISSUES = D.validate(LINENAMES, PARAMNAMES, NCHANNELS) lists
            %   (string, one per problem, empty when none) rows that cannot be
            %   generated: unknown lines or parameters, channels beyond
            %   NCHANNELS, bad numbers. Pass [] for a check to skip it.
            arguments
                obj (1,1) SyntheticDesign
                lineNames = []
                paramNames = []
                nChannels = []
            end
            issues = strings(0, 1);
            if ~(isfinite(obj.NoiseUV) && obj.NoiseUV >= 0)
                issues(end+1, 1) = "NoiseUV must be a number >= 0.";
            end
            if ~(isfinite(obj.SineUV) && obj.SineUV >= 0)
                issues(end+1, 1) = "SineUV must be a number >= 0.";
            end

            U = obj.Units;
            issues = [issues; nameIssues(U.Name, "Unit")];
            for k = 1:height(U)
                u = U(k, :);
                w = "Unit " + displayName(u.Name, k) + ": ";
                issues = [issues; channelIssues(u.Channel, w, nChannels, false)]; %#ok<AGROW>
                if ~(isfinite(u.AmplitudeUV) && u.AmplitudeUV > 0)
                    issues(end+1, 1) = w + "AmplitudeUV must be > 0."; %#ok<AGROW>
                end
                if ~(isfinite(u.BaselineHz) && u.BaselineHz >= 0)
                    issues(end+1, 1) = w + "BaselineHz must be >= 0."; %#ok<AGROW>
                end
                if ~(isfinite(u.Gain) && u.Gain >= 0)
                    issues(end+1, 1) = w + "Gain must be >= 0."; %#ok<AGROW>
                elseif isfinite(u.BaselineHz) && u.BaselineHz * max(u.Gain, 1) > 450
                    issues(end+1, 1) = w + "the peak rate (BaselineHz x Gain) exceeds 450 Hz, more than the 2 ms dead time allows."; %#ok<AGROW>
                end
                issues = [issues; eventIssues(u, w, lineNames, paramNames)]; %#ok<AGROW>
            end

            L = obj.LFP;
            issues = [issues; nameIssues(L.Name, "LFP component")];
            for k = 1:height(L)
                c = L(k, :);
                w = "LFP " + displayName(c.Name, k) + ": ";
                issues = [issues; channelIssues(c.Channel, w, nChannels, true)]; %#ok<AGROW>
                if ~isfinite(c.AmplitudeUV)
                    issues(end+1, 1) = w + "AmplitudeUV must be a number."; %#ok<AGROW>
                end
                if c.Event == ""
                    issues(end+1, 1) = w + "choose the line (Event) it is locked to."; %#ok<AGROW>
                end
                issues = [issues; eventIssues(c, w, lineNames, paramNames)]; %#ok<AGROW>
            end
        end

        function s = toStruct(obj)
            %toStruct  Plain struct for JSON / preferences (tables as struct arrays).
            s = struct();
            s.schema = SyntheticDesign.FileSchema;
            s.NoiseUV = obj.NoiseUV;
            s.SineUV = obj.SineUV;
            s.Units = table2struct(obj.Units).';
            s.LFP = table2struct(obj.LFP).';
        end

        function file = save(obj, file)
            %save  Write the design as JSON (NaN kept as "NaN").
            arguments
                obj (1,1) SyntheticDesign
                file (1,1) string
            end
            writeJsonFile(file, obj.toStruct(), NonFinite="string");
        end
    end

    methods (Static)
        function D = builtIn(nChannels, opts)
            %builtIn  The design makeSyntheticRecording writes by default.
            %   D = SyntheticDesign.builtIn(NCHANNELS) has max(2, round(NCHANNELS/2))
            %   units at 5 Hz, spread over the channels, their amplitudes
            %   evenly from 200 down to 60 uV. Every second unit is driven
            %   (x 5) from 20 to 220 ms after Event's onset (default "Stim"),
            %   the third is silenced (Gain 0) from 0 to 500 ms after it, the
            %   rest are unmodulated; and an evoked potential of -150 uV on
            %   every channel from 20 to 70 ms after the onset (peak at 45 ms).
            arguments
                nChannels (1,1) double {mustBeInteger, mustBePositive} = 16
                opts.Event (1,1) string = "Stim"
            end
            nU = max(2, round(nChannels / 2));
            U = SyntheticDesign.unitTable(nU);
            U.Name = "u" + (1:nU).';
            U.Channel = max(1, min(nChannels, round(((1:nU).' - 0.5) * nChannels / nU)));
            U.AmplitudeUV = round(linspace(200, 60, nU).');
            U.BaselineHz(:) = 5;
            driven = false(nU, 1); driven(2:2:nU) = true;
            U.Event(driven) = opts.Event; U.Gain(driven) = 5;
            U.LatencyMs(driven) = 20; U.DurationMs(driven) = 200;
            if nU >= 3
                U.Event(3) = opts.Event; U.Gain(3) = 0; U.LatencyMs(3) = 0; U.DurationMs(3) = 500;
            end
            L = SyntheticDesign.newLFP(opts.Event, "evoked");
            L.AmplitudeUV = -150; L.LatencyMs = 20; L.DurationMs = 50;
            D = SyntheticDesign();
            D.Units = U;
            D.LFP = L;
        end

        function T = newUnit(name, event)
            %newUnit  One unit row on channel 1, driven x 4 from 15 to 215 ms after EVENT's onset.
            arguments
                name (1,1) string = "u1"
                event (1,1) string = ""
            end
            T = SyntheticDesign.unitTable(1);
            T.Name = name; T.AmplitudeUV = 120; T.Event = event; T.Gain = 4; T.LatencyMs = 15; T.DurationMs = 200;
        end

        function T = newLFP(event, name)
            %newLFP  One evoked potential on every channel: -100 uV from 10 to 70 ms after EVENT's onset.
            arguments
                event (1,1) string = ""
                name (1,1) string = "evoked"
            end
            T = SyntheticDesign.lfpTable(1);
            T.Name = name; T.Event = event; T.AmplitudeUV = -100; T.LatencyMs = 10; T.DurationMs = 60;
        end

        function T = unitTable(n)
            %unitTable  N unit rows: channel 1, 100 uV, 5 Hz, no event, no modulation.
            arguments
                n (1,1) double {mustBeInteger, mustBeNonnegative} = 0
            end
            T = table(strings(n, 1), ones(n, 1), 100 * ones(n, 1), 5 * ones(n, 1), strings(n, 1), ...
                repmat("onset", n, 1), ones(n, 1), zeros(n, 1), 100 * ones(n, 1), strings(n, 1), ...
                'VariableNames', cellstr(SyntheticDesign.UnitColumns));
        end

        function T = lfpTable(n)
            %lfpTable  N evoked-potential rows: every channel, -100 uV over 100 ms, no event yet.
            arguments
                n (1,1) double {mustBeInteger, mustBeNonnegative} = 0
            end
            T = table(strings(n, 1), NaN(n, 1), -100 * ones(n, 1), strings(n, 1), repmat("onset", n, 1), ...
                zeros(n, 1), 100 * ones(n, 1), strings(n, 1), ...
                'VariableNames', cellstr(SyntheticDesign.LFPColumns));
        end

        function D = fromStruct(s)
            %fromStruct  Inverse of toStruct (also accepts what jsondecode returns).
            D = SyntheticDesign();
            if ~isstruct(s); return; end
            if isfield(s, 'NoiseUV'); D.NoiseUV = toNumber(s.NoiseUV, D.NoiseUV); end
            if isfield(s, 'SineUV'); D.SineUV = toNumber(s.SineUV, D.SineUV); end
            if isfield(s, 'Units'); D.Units = structRows(s.Units, SyntheticDesign.unitTable(0)); end
            if isfield(s, 'LFP'); D.LFP = structRows(s.LFP, SyntheticDesign.lfpTable(0)); end
        end

        function D = load(file)
            %load  Read a design written by save.
            arguments
                file (1,1) string
            end
            s = readJsonFile(file);
            if ~isstruct(s) || ~isfield(s, 'schema') || string(s.schema) ~= SyntheticDesign.FileSchema
                error('SyntheticDesign:BadFile', '%s is not a synthetic design (%s).', file, SyntheticDesign.FileSchema);
            end
            D = SyntheticDesign.fromStruct(s);
        end
    end

    methods (Static, Access = private)
        function T = normalizeTable(T, kind)
            %normalizeTable  Columns in order, with the types of unitTable / lfpTable.
            if kind == "unit"
                ref = SyntheticDesign.unitTable(0);
            else
                ref = SyntheticDesign.lfpTable(0);
            end
            if ~istable(T)
                error('SyntheticDesign:NotTable', 'The %s rows must be a table.', kind);
            end
            n = height(T);
            out = ref;
            if n > 0
                if kind == "unit"; out = SyntheticDesign.unitTable(n); else; out = SyntheticDesign.lfpTable(n); end
            end
            names = string(ref.Properties.VariableNames);
            have = string(T.Properties.VariableNames);
            extra = setdiff(have, names);
            if ~isempty(extra)
                error('SyntheticDesign:Columns', 'Unknown %s column(s): %s', kind, strjoin(extra, ", "));
            end
            for v = intersect(names, have, 'stable')
                x = T.(v);
                if isstring(ref.(v))
                    x = string(x); x(ismissing(x)) = "";
                else
                    x = double(x);
                end
                out.(v) = reshape(x, [], 1);
            end
            T = out;
        end
    end
end


%% ---------------------------------------------------------------------------
function issues = nameIssues(names, what)
issues = strings(0, 1);
if any(names == "")
    issues(end+1, 1) = what + " names must not be empty.";
end
[u, ~, j] = unique(names(names ~= ""));
dup = u(accumarray(j, 1) > 1);
if ~isempty(dup)
    issues(end+1, 1) = what + " names must be unique (" + strjoin(dup, ", ") + ").";
end
end


function s = displayName(name, k)
if name == ""; s = "#" + k; else; s = """" + name + """"; end
end


function issues = channelIssues(ch, w, nChannels, allowNaN)
issues = strings(0, 1);
if isnan(ch) && allowNaN; return; end
if ~(ch >= 1 && ch == round(ch))
    if allowNaN
        issues = w + "Channel must be a whole number >= 1 (or NaN for every channel).";
    else
        issues = w + "Channel must be a whole number >= 1.";
    end
elseif ~isempty(nChannels) && ch > nChannels
    issues = w + sprintf("Channel %d is beyond the %d channel(s).", ch, nChannels);
end
end


function issues = eventIssues(r, w, lineNames, paramNames)
issues = strings(0, 1);
if r.Event ~= "" && ~isempty(lineNames) && ~ismember(r.Event, string(lineNames))
    issues(end+1, 1) = w + "no digital line """ + r.Event + """ in the schedule (" + strjoin(string(lineNames), ", ") + ").";
end
if ~ismember(r.Edge, SyntheticDesign.Edges)
    issues(end+1, 1) = w + "Edge must be onset or offset.";
end
if ~isfinite(r.LatencyMs)
    issues(end+1, 1) = w + "LatencyMs must be a number.";
end
if ~(isfinite(r.DurationMs) && r.DurationMs > 0)
    issues(end+1, 1) = w + "DurationMs must be > 0.";
end
if r.Parameter ~= ""
    if r.Event == ""
        issues(end+1, 1) = w + "a Parameter needs an Event to scale.";
    elseif ~isempty(paramNames) && ~ismember(r.Parameter, string(paramNames))
        issues(end+1, 1) = w + "no numeric Epsych2 parameter """ + r.Parameter + """ in the session.";
    elseif isempty(paramNames) && ~isequal(paramNames, [])
        issues(end+1, 1) = w + "the schedule has no Epsych2 parameters to scale by.";
    end
end
end


function v = toNumber(x, default)
if isnumeric(x) || islogical(x)
    v = double(x);
elseif (ischar(x) || isstring(x)) && ~isnan(str2double(x))
    v = str2double(x);
elseif (ischar(x) || isstring(x)) && any(strcmpi(string(x), ["NaN" "Inf" "-Inf"]))
    v = str2double(x);
else
    v = default;
end
if isempty(v); v = NaN; end
end


function T = structRows(s, ref)
%structRows  Struct array (from toStruct or jsondecode) -> a table shaped like REF.
if isempty(s)
    T = ref;
    return
end
if iscell(s); s = [s{:}]; end
n = numel(s);
names = string(ref.Properties.VariableNames);
cols = cell(1, numel(names));
for j = 1:numel(names)
    v = names(j);
    if isstring(ref.(v))
        col = strings(n, 1);
    else
        col = NaN(n, 1);
    end
    for i = 1:n
        if ~isfield(s(i), v); continue; end
        x = s(i).(v);
        if isstring(col)
            if ~isempty(x); col(i) = string(x); end
        else
            col(i) = toNumber(x, NaN);
        end
    end
    cols{j} = col;
end
T = table(cols{:}, 'VariableNames', cellstr(names));
end
