classdef SyntheticDesign
    %SyntheticDesign  What a synthetic recording holds: units, event-linked LFP, background.
    %   A SyntheticDesign describes the neural signals makeSyntheticRecording
    %   writes, independently of when the events happen (the schedule: the
    %   built-in task, or an Epsych2 session, see syntheticSessionSchedule):
    %
    %     Units       one row per spiking unit. A unit fires at BaselineHz and,
    %                 when Event names a digital line, changes its rate around
    %                 every Edge ("onset" | "offset") of that line: from
    %                 LatencyMs after the edge, for DurationMs, the rate is
    %                 BaselineHz x (1 + (Gain - 1) x envelope), the envelope
    %                 given by Shape. Gain > 1 excites, Gain < 1 suppresses.
    %     LFP         one row per LFP component locked to a line's edges: an
    %                 "oscillation" (FrequencyHz, AmplitudeUV, a Tukey
    %                 envelope with RiseMs ramps; PhaseLocked = the same phase
    %                 on every event, so it survives averaging, else a random
    %                 phase: induced power only) or an "evoked" potential (an
    %                 alpha function peaking RiseMs after the latency, signed
    %                 AmplitudeUV), spread over the channels by Profile.
    %     Background  ongoing LFP rhythms, 1/f-like and white noise, line noise
    %
    %   Unit columns
    %     Name         unique label
    %     Channel      peak channel (1-based); NaN = spread the units evenly
    %     AmplitudeUV  trough amplitude on the peak channel; NaN = random 60-200
    %     WidthMs      trough width (Gaussian sigma); NaN = random 0.15-0.3
    %     BaselineHz   rate away from events; NaN = random 1.5-8
    %     Event        digital line the unit responds to; "" = none
    %     Edge         "onset" | "offset"
    %     Shape        "sustained" (flat for DurationMs) | "transient" (a
    %                  raised-cosine bump over DurationMs) | "phasic-tonic"
    %                  (a bump over the first 30 % over a plateau at 40 %)
    %     Gain         rate multiplier at the envelope's peak; NaN = random 2-5
    %     LatencyMs    edge to response start (may be negative)
    %     DurationMs   response length; NaN = as long as the line's interval
    %     JitterMs     SD of the latency from event to event
    %     Parameter    Epsych2 trial parameter that scales the response; ""
    %                  = none. The response is scaled by the trial's value
    %                  normalised to 0..1 over the session (Tuning
    %                  "increasing") or by 1 minus that ("decreasing");
    %                  events outside any trial respond fully
    %     Tuning       "increasing" | "decreasing"
    %
    %   LFP columns
    %     Name, Event, Edge, LatencyMs, JitterMs, Parameter, Tuning  as for units
    %     Kind         "oscillation" | "evoked"
    %     FrequencyHz  oscillation frequency (ignored for "evoked")
    %     AmplitudeUV  peak amplitude on the profile's peak channel; signed
    %                  for "evoked" (negative = a negative-going potential)
    %     DurationMs   oscillation: its length, NaN = the line's interval;
    %                  evoked: the window it is drawn in, NaN = 8 x RiseMs
    %     RiseMs       oscillation: envelope ramp; evoked: time to peak
    %     PhaseLocked  oscillation: the same phase on every event
    %     Profile      over the probe's depth (site y): "uniform" |
    %                  "superficial" | "middle" | "deep" | "reversal" (the
    %                  sign flips at mid depth, as across a dipole), scaled
    %                  so the largest channel has gain 1
    %
    %   Background fields
    %     RhythmScale  x the 1.7 / 7.3 / 12.5 Hz rhythms (120 / 60 / 25 uV); 0 = off
    %     PinkUV       RMS of the slow (4 Hz low-passed) noise
    %     NoiseUV      RMS of the white noise
    %     LineNoiseUV  line-noise amplitude (its 3rd harmonic at 30 %)
    %     LineFreqHz   50 | 60
    %
    %   Usage
    %     D = SyntheticDesign.builtIn(16);        % what makeSyntheticRecording writes by default
    %     D.Units(end+1, :) = SyntheticDesign.newUnit("tone", "Stim");
    %     D.LFP(end+1, :) = SyntheticDesign.newLFP("oscillation", "Stim");
    %     issues = D.validate(["Stim" "InTrial"], "Depth", 16);
    %     D.save("design.json"); D2 = SyntheticDesign.load("design.json");
    %
    %   See also makeSyntheticRecording, syntheticModel,
    %   syntheticSessionSchedule, syntheticTaskSchedule.

    properties
        Background (1,1) struct = SyntheticDesign.defaultBackground()
        Units table = SyntheticDesign.unitTable(0)
        LFP table = SyntheticDesign.lfpTable(0)
    end

    properties (Constant)
        Edges    = ["onset" "offset"]
        Shapes   = ["sustained" "transient" "phasic-tonic"]
        Kinds    = ["oscillation" "evoked"]
        Profiles = ["uniform" "superficial" "middle" "deep" "reversal"]
        Tunings  = ["increasing" "decreasing"]
        UnitColumns = ["Name" "Channel" "AmplitudeUV" "WidthMs" "BaselineHz" "Event" "Edge" ...
            "Shape" "Gain" "LatencyMs" "DurationMs" "JitterMs" "Parameter" "Tuning"]
        LFPColumns = ["Name" "Kind" "Event" "Edge" "FrequencyHz" "AmplitudeUV" "LatencyMs" ...
            "DurationMs" "RiseMs" "PhaseLocked" "Profile" "JitterMs" "Parameter" "Tuning"]
        FileSchema = "ephys-synthetic-design/1"
    end

    methods
        function obj = set.Units(obj, T)
            obj.Units = SyntheticDesign.normalizeTable(T, "unit");
        end

        function obj = set.LFP(obj, T)
            obj.LFP = SyntheticDesign.normalizeTable(T, "lfp");
        end

        function lines = usedLines(obj)
            %usedLines  The digital lines the units and LFP components are linked to.
            lines = unique([obj.Units.Event; obj.LFP.Event]).';
            lines = lines(lines ~= "");
        end

        function params = usedParameters(obj)
            %usedParameters  The Epsych2 parameters that scale a response.
            params = unique([obj.Units.Parameter; obj.LFP.Parameter]).';
            params = params(params ~= "");
        end

        function issues = validate(obj, lineNames, paramNames, nChannels, Fs)
            %validate  Problems with the design for a schedule and a recording.
            %   ISSUES = D.validate(LINENAMES, PARAMNAMES, NCHANNELS, FS) lists
            %   (string, one per problem, empty when none) rows that cannot be
            %   generated: unknown lines or parameters, channels beyond
            %   NCHANNELS, frequencies at or above FS/2, bad numbers. Pass []
            %   for a check to skip it.
            arguments
                obj (1,1) SyntheticDesign
                lineNames = []
                paramNames = []
                nChannels = []
                Fs = []
            end
            issues = strings(0, 1);
            B = obj.Background;
            for f = ["RhythmScale" "PinkUV" "NoiseUV" "LineNoiseUV"]
                if ~(isscalar(B.(f)) && isfinite(B.(f)) && B.(f) >= 0)
                    issues(end+1, 1) = sprintf("Background %s must be a number >= 0.", f); %#ok<AGROW>
                end
            end
            if ~(isscalar(B.LineFreqHz) && B.LineFreqHz > 0)
                issues(end+1, 1) = "Background LineFreqHz must be > 0.";
            end

            U = obj.Units;
            issues = [issues; nameIssues(U.Name, "Unit")];
            for k = 1:height(U)
                u = U(k, :);
                w = "Unit " + displayName(u.Name, k) + ": ";
                if ~isnan(u.Channel) && ~(u.Channel >= 1 && u.Channel == round(u.Channel))
                    issues(end+1, 1) = w + "Channel must be a whole number >= 1 (or NaN to spread the units)."; %#ok<AGROW>
                elseif ~isempty(nChannels) && ~isnan(u.Channel) && u.Channel > nChannels
                    issues(end+1, 1) = w + sprintf("Channel %d is beyond the %d channel(s).", u.Channel, nChannels); %#ok<AGROW>
                end
                issues = [issues; positive(u.AmplitudeUV, w + "AmplitudeUV", true, false)]; %#ok<AGROW>
                if ~isnan(u.WidthMs) && ~(u.WidthMs >= 0.05 && u.WidthMs <= 2)
                    issues(end+1, 1) = w + "WidthMs must be between 0.05 and 2 (or NaN)."; %#ok<AGROW>
                end
                issues = [issues; positive(u.BaselineHz, w + "BaselineHz", true, true)]; %#ok<AGROW>
                issues = [issues; positive(u.Gain, w + "Gain", true, true)]; %#ok<AGROW>
                issues = [issues; eventIssues(u, w, lineNames, paramNames)]; %#ok<AGROW>
                if ~ismember(u.Shape, SyntheticDesign.Shapes)
                    issues(end+1, 1) = w + "Shape must be one of " + strjoin(SyntheticDesign.Shapes, ", ") + "."; %#ok<AGROW>
                end
                if ~isnan(u.BaselineHz) && ~isnan(u.Gain) && u.BaselineHz * max(u.Gain, 1) > 500
                    issues(end+1, 1) = w + "the peak rate (BaselineHz x Gain) exceeds 500 Hz, which the 2 ms refractory period cannot give."; %#ok<AGROW>
                end
            end

            L = obj.LFP;
            issues = [issues; nameIssues(L.Name, "LFP component")];
            for k = 1:height(L)
                c = L(k, :);
                w = "LFP " + displayName(c.Name, k) + ": ";
                if ~ismember(c.Kind, SyntheticDesign.Kinds)
                    issues(end+1, 1) = w + "Kind must be oscillation or evoked."; %#ok<AGROW>
                end
                if c.Event == ""
                    issues(end+1, 1) = w + "choose the line (Event) it is locked to."; %#ok<AGROW>
                end
                issues = [issues; eventIssues(c, w, lineNames, paramNames)]; %#ok<AGROW>
                if ~isfinite(c.AmplitudeUV)
                    issues(end+1, 1) = w + "AmplitudeUV must be a number."; %#ok<AGROW>
                end
                if c.Kind == "oscillation"
                    if ~(isfinite(c.FrequencyHz) && c.FrequencyHz > 0)
                        issues(end+1, 1) = w + "FrequencyHz must be > 0."; %#ok<AGROW>
                    elseif ~isempty(Fs) && c.FrequencyHz >= Fs / 2
                        issues(end+1, 1) = w + sprintf("FrequencyHz must be below half the sample rate (%g Hz).", Fs / 2); %#ok<AGROW>
                    end
                    if ~(isfinite(c.RiseMs) && c.RiseMs >= 0)
                        issues(end+1, 1) = w + "RiseMs must be >= 0."; %#ok<AGROW>
                    end
                elseif c.Kind == "evoked" && ~(isfinite(c.RiseMs) && c.RiseMs > 0)
                    issues(end+1, 1) = w + "RiseMs (time to peak) must be > 0."; %#ok<AGROW>
                end
                if ~ismember(c.Profile, SyntheticDesign.Profiles)
                    issues(end+1, 1) = w + "Profile must be one of " + strjoin(SyntheticDesign.Profiles, ", ") + "."; %#ok<AGROW>
                end
            end
        end

        function s = toStruct(obj)
            %toStruct  Plain struct for JSON / preferences (tables as struct arrays).
            s = struct();
            s.schema = SyntheticDesign.FileSchema;
            s.Background = obj.Background;
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
            %   units spread over the channels with random amplitudes, widths
            %   and rates: every second unit is driven while Event (default
            %   "Stim") is on (a random 2-5 fold gain), the third is suppressed
            %   to 30 %, the rest are unmodulated; and an evoked potential
            %   (-150 uV, 45 ms to peak) at mid depth on the line's onset.
            arguments
                nChannels (1,1) double {mustBeInteger, mustBePositive} = 16
                opts.Event (1,1) string = "Stim"
            end
            nU = max(2, round(nChannels / 2));
            U = SyntheticDesign.unitTable(nU);
            U.Name = "u" + (1:nU).';
            U.Channel(:) = NaN; U.AmplitudeUV(:) = NaN; U.WidthMs(:) = NaN; U.BaselineHz(:) = NaN;
            U.Gain(:) = 1;
            U.Shape(:) = "sustained";
            U.DurationMs(:) = NaN;
            driven = false(nU, 1); driven(2:2:nU) = true;
            U.Event(driven) = opts.Event; U.Gain(driven) = NaN;
            if nU >= 3
                U.Event(3) = opts.Event; U.Gain(3) = 0.3;
            end
            L = SyntheticDesign.newLFP("evoked", opts.Event);
            L.Name = "evoked"; L.AmplitudeUV = -150; L.LatencyMs = 0; L.RiseMs = 45; L.DurationMs = 350;
            L.Profile = "middle";
            D = SyntheticDesign();
            D.Units = U;
            D.LFP = L;
        end

        function T = newUnit(name, event)
            %newUnit  One unit row with a typical sensory response to EVENT.
            arguments
                name (1,1) string = "u1"
                event (1,1) string = ""
            end
            T = SyntheticDesign.unitTable(1);
            T.Name = name; T.Channel = 1; T.AmplitudeUV = 120; T.WidthMs = 0.2; T.BaselineHz = 5;
            T.Event = event; T.Shape = "phasic-tonic"; T.Gain = 4; T.LatencyMs = 15; T.DurationMs = 200;
            T.JitterMs = 3;
        end

        function T = newLFP(kind, event, name)
            %newLFP  One LFP row: a 40 Hz phase-locked oscillation or an evoked potential on EVENT.
            arguments
                kind (1,1) string {mustBeMember(kind, ["oscillation" "evoked"])} = "oscillation"
                event (1,1) string = ""
                name (1,1) string = ""
            end
            T = SyntheticDesign.lfpTable(1);
            T.Kind = kind; T.Event = event; T.Name = name;
            if kind == "oscillation"
                if name == ""; T.Name = "gamma"; end
                T.FrequencyHz = 40; T.AmplitudeUV = 60; T.LatencyMs = 20; T.DurationMs = 300;
                T.RiseMs = 50; T.PhaseLocked = true; T.Profile = "superficial";
            else
                if name == ""; T.Name = "evoked"; end
                T.FrequencyHz = NaN; T.AmplitudeUV = -100; T.LatencyMs = 10; T.DurationMs = NaN;
                T.RiseMs = 30; T.PhaseLocked = true; T.Profile = "reversal";
            end
        end

        function T = unitTable(n)
            %unitTable  N unit rows with neutral values (no event, no modulation).
            arguments
                n (1,1) double {mustBeInteger, mustBeNonnegative} = 0
            end
            T = table(strings(n, 1), NaN(n, 1), NaN(n, 1), NaN(n, 1), NaN(n, 1), strings(n, 1), ...
                repmat("onset", n, 1), repmat("sustained", n, 1), ones(n, 1), zeros(n, 1), NaN(n, 1), ...
                zeros(n, 1), strings(n, 1), repmat("increasing", n, 1), ...
                'VariableNames', cellstr(SyntheticDesign.UnitColumns));
        end

        function T = lfpTable(n)
            %lfpTable  N LFP rows (phase-locked oscillations, no event yet).
            arguments
                n (1,1) double {mustBeInteger, mustBeNonnegative} = 0
            end
            T = table(strings(n, 1), repmat("oscillation", n, 1), strings(n, 1), repmat("onset", n, 1), ...
                40 * ones(n, 1), 50 * ones(n, 1), zeros(n, 1), NaN(n, 1), 20 * ones(n, 1), true(n, 1), ...
                repmat("uniform", n, 1), zeros(n, 1), strings(n, 1), repmat("increasing", n, 1), ...
                'VariableNames', cellstr(SyntheticDesign.LFPColumns));
        end

        function B = defaultBackground()
            B = struct('RhythmScale', 1, 'PinkUV', 30, 'NoiseUV', 9, 'LineNoiseUV', 5, 'LineFreqHz', 60);
        end

        function D = fromStruct(s)
            %fromStruct  Inverse of toStruct (also accepts what jsondecode returns).
            D = SyntheticDesign();
            if ~isstruct(s); return; end
            if isfield(s, 'Background') && isstruct(s.Background)
                B = D.Background;
                for f = string(fieldnames(B)).'
                    if isfield(s.Background, f)
                        B.(f) = toNumber(s.Background.(f), B.(f));
                    end
                end
                D.Background = B;
            end
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
                elseif islogical(ref.(v))
                    x = logical(x);
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


function issues = positive(x, what, allowNaN, allowZero)
issues = strings(0, 1);
if isnan(x)
    if ~allowNaN; issues = what + " must be a number."; end
    return
end
if ~isfinite(x) || x < 0 || (~allowZero && x == 0)
    if allowZero
        issues = what + " must be >= 0.";
    else
        issues = what + " must be > 0.";
    end
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
if ~isnan(r.DurationMs) && ~(isfinite(r.DurationMs) && r.DurationMs > 0)
    issues(end+1, 1) = w + "DurationMs must be > 0 (or NaN).";
end
if ~(isfinite(r.JitterMs) && r.JitterMs >= 0)
    issues(end+1, 1) = w + "JitterMs must be >= 0.";
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
if ~ismember(r.Tuning, SyntheticDesign.Tunings)
    issues(end+1, 1) = w + "Tuning must be increasing or decreasing.";
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
    elseif islogical(ref.(v))
        col = false(n, 1);
    else
        col = NaN(n, 1);
    end
    for i = 1:n
        if ~isfield(s(i), v); continue; end
        x = s(i).(v);
        if isstring(col)
            if ~isempty(x); col(i) = string(x); end
        elseif islogical(col)
            if ~isempty(x); col(i) = logical(toNumber(x, 0)); end
        else
            col(i) = toNumber(x, NaN);
        end
    end
    cols{j} = col;
end
T = table(cols{:}, 'VariableNames', cellstr(names));
end
