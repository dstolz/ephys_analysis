function test_EphysAnalysisEpochs()
%test_EphysAnalysisEpochs  Verification suite for sources, event references and epochs.
%   Runs a small synthetic project (clean + late-start scenarios, trial
%   pairings approved with the scenario's cuts) through the pipeline and
%   checks loadAnalysisSource against the generator's truth, then
%   resolveEvents / epochTable: trial-scope alignment to the first Stim of
%   each trial, "Trial" alignment to the trial onsets, recording scope,
%   grouping by Depth, response selection and filters, Platform onset ->
%   offset ("between") epochs, selectUnits for sorted units and detections,
%   the error identifiers and the fallback to recording scope without
%   behavior.
%
%   Usage:  test_EphysAnalysisEpochs

here = fileparts(mfilename('fullpath'));
repo = fileparts(here);
addpath(here);
addpath(fullfile(repo, 'pipeline'));
addpath(repo);
addpath(genpath(fullfile(repo, 'vendor')));

root = fullfile(tempdir, sprintf('AnaEpochs_test_%s', datestr(now, 'yyyymmdd_HHMMSSFFF'))); %#ok<TNOW1,DATST>
mkdir(root);
cleanup = onCleanup(@() rmdirQuiet(root)); %#ok<NASGU>

nPass = 0; nFail = 0;
    function check(cond, msg)
        if cond
            nPass = nPass + 1;
            fprintf('  PASS: %s\n', msg);
        else
            nFail = nFail + 1;
            fprintf(2, '  FAIL: %s\n', msg);
        end
    end
    function id = errorId(fcn)
        id = '';
        try
            fcn();
        catch ME
            id = ME.identifier;
        end
    end

fprintf('\n== 0. fixture ==\n');
F = makeAnalysisFixture(root, Scenarios=["clean" "late-start"], NumTrials=12);
T1 = F.truth(1);
check(numel(F.outputs) == 2 && all(F.outputs(1).has("behavior") & F.outputs(1).has("spikes") & F.outputs(1).has("LFP")), ...
    'the pipeline wrote behavior, signals and spikes for the fixture');

fprintf('\n== 1. loadAnalysisSource ==\n');
src = loadAnalysisSource(F.outputs(1), Key=F.keys(1));
check(src.name == T1.name && src.key == F.keys(1) && abs(src.durationSec - T1.duration) < 1e-9 && src.fs == T1.Fs, ...
    'name, key, rate and duration come from the manifest');
ok = height(src.lines) == numel(T1.digInNames);
for ln = T1.digInNames
    r = src.lines.Line == ln;
    ok = ok && any(r) && src.lines.Count(r) == size(T1.events.(ln), 1) ...
        && isequal(round(src.events.(ln) * T1.Fs), round(T1.events.(ln) * T1.Fs));
end
check(ok, 'every digital line is there with the written intervals');
check(src.hasBehavior && src.hasTrials && src.nTrials == 12 && src.trialLine == "InTrial" && src.respField == "RespCode" ...
    && all(ismember(["Depth" "TrialType" "StimDelay"], src.paramNames)) && isstring(src.trials.PairingFlag), ...
    'paired trials, the trial line, RespCode and the Epsych2 parameters');
check(src.signals.LFP && src.signals.MUA && src.signals.AUX && ~src.signals.SPIKE && src.signalFs.LFP == 1000 ...
    && src.signalFs.MUA == 2000 && numel(src.labels) == numel(T1.channelNames), 'signals, their rates and the channel labels');
check(src.hasUnits && src.unitsFrom == "spikes" && src.hasDetected && isstruct(src.probe) && numel(src.probe.xc) == numel(T1.channelNames), ...
    'units from the spikes file, detections and the probe map');

fprintf('\n== 2. trial scope: first Stim of each trial ==\n');
[E, G] = epochTable(src, eventRef(line="Stim", scope="trial"), Window=epochWindow(pre=-0.2, post=0.5));
firstStim = arrayfun(@(i) src.trials.TrialEvents(i).Stim(1, 1), (1:src.nTrials).');
check(height(E) == 12 && isequal(E.trial, (1:12).') && max(abs(E.t0 - firstStim)) == 0, ...
    'one epoch per trial at TrialEvents(i).Stim(1,1)');
check(max(abs(E.t0 - T1.events.Stim(:, 1))) < 1e-9 && all(E.complete) && all(abs(E.duration - 0.7) < 1e-12) ...
    && height(G) == 1 && G.label == "all" && G.n == 12, 'the onsets are the written Stim onsets; one group "all"');
U = E.Properties.UserData;
check(U.scope == "trial" && U.nEvents == 12 && U.nTrialsSelected == 12 && U.ref.line == "Stim", 'UserData records the alignment');

fprintf('\n== 3. "Trial" = the trial onsets; recording scope ==\n');
E = epochTable(src, eventRef(line="Trial"), Window=epochWindow(pre=-0.5, post=1));
check(height(E) == 12 && max(abs(E.t0 - src.trials.TrialOnset)) == 0 && max(abs(E.t0 - T1.trials.Onset)) < 1e-9, ...
    '"Trial" aligns to TrialOnset (= the written trial onsets)');
E = epochTable(src, eventRef(line="Trial", edge="offset"));
check(max(abs(E.t0 - src.trials.TrialOffset)) == 0, '"Trial" offset aligns to TrialOffset');
E = epochTable(src, eventRef(line="Stim", scope="recording", which="all"), Window=epochWindow(pre=-0.1, post=0.3));
check(height(E) == size(T1.events.Stim, 1) && all(E.groupIndex == 1) && isequal(E.trial, (1:12).'), ...
    'recording scope: every Stim interval, each assigned its trial');
E = epochTable(src, eventRef(line="Stim", scope="recording", which="first"));
check(height(E) == 1, 'recording scope "first" is the first Stim of the recording');
E = epochTable(src, eventRef(line="Stim", scope="trial", offsetSec=0.25));
check(max(abs(E.t0 - (firstStim + 0.25))) < 1e-12, 'offsetSec shifts every event');

fprintf('\n== 4. selection and groups ==\n');
[trials, ~] = readEpsychSession(T1.behaviorFile);
[E, G] = epochTable(src, eventRef(line="Stim"), Selection=trialSelection(groupBy="Depth"));
u = unique(trials.Depth);
cnt = arrayfun(@(v) nnz(trials.Depth == v), u);
check(height(G) == numel(u) && isequal(G.Depth, u) && isequal(G.n, cnt) && isequal(G.nTrials, cnt) ...
    && all(startsWith(G.label, "Depth = ")) && isequal(E.Depth, trials.Depth) ...
    && isequal(E.groupIndex, arrayfun(@(v) find(u == v), trials.Depth)), ...
    sprintf('groupBy Depth: %d groups with the session''s counts, ascending', numel(u)));
Gd = selectTrialsGroups(src, trialSelection(groupBy="Depth", groupOrder="descending"));
check(isequal(Gd.Depth, flipud(u)), 'descending order reverses the groups');
check(size(G.color, 2) == 3 && (numel(u) <= 2 || ~isequal(G.color(1, :), G.color(end, :))), 'each group has a colour');
[mask, ~, gi] = selectTrials(src, trialSelection(response="Hit"));
check(isequal(mask, bitand(trials.RespCode, 1) > 0) && isequal(gi, double(mask)), 'response "Hit" keeps the trials with bit 1');
m1 = selectTrials(src, trialSelection(filter="Hit | Miss"));
m2 = selectTrials(src, trialSelection(response=["Hit" "Miss"]));
check(isequal(m1, m2) && isequal(m1, trials.TrialType == 0), 'filter "Hit | Miss" = response Hit or Miss = the non-catch trials');
m3 = selectTrials(src, trialSelection(filter="Depth >= 0.5 & ~FA"));
check(isequal(m3, trials.Depth >= 0.5 & bitand(trials.RespCode, 8) == 0), 'a filter mixing a parameter and a negated response word');
m4 = selectTrials(src, trialSelection(filter="Depth = 0.25", trials=[1 2 3]));
check(isequal(find(m4), find(trials.Depth(1:3) == 0.25)), 'a single "=" compares; trials limits to rows');
[E, G] = epochTable(src, eventRef(line="Stim", scope="recording", which="all"), Selection=trialSelection(groupBy="TrialType"));
check(height(E) == 12 && height(G) == numel(unique(trials.TrialType)) && isequal(E.TrialType, trials.TrialType), ...
    'recording scope with groups: each event takes its trial''s group');

fprintf('\n== 5. between: Platform onset -> offset ==\n');
ref = eventRef(line="Platform", edge="onset", which="first", scope="trial");
stop = eventRef(line="Platform", edge="offset", which="first", scope="trial");
E = epochTable(src, ref, Window=epochWindow(mode="between", pre=0, post=0, stop=stop));
pl = arrayfun(@(i) src.trials.TrialEvents(i).Platform(1, :), (1:12).', 'UniformOutput', false);
pl = vertcat(pl{:});
check(height(E) == 12 && max(abs(E.t0 - pl(:, 1))) == 0 && max(abs(E.t1 - pl(:, 2))) == 0 ...
    && max(abs(E.duration - (pl(:, 2) - pl(:, 1)))) < 1e-12, 'each epoch spans its Platform interval');
E = epochTable(src, eventRef(line="Stim"), Window=epochWindow(pre=-0.2, post=1, stop=eventRef(line="Stim", edge="offset")));
check(all(abs(E.t1 - E.t0 - 0.5) < 2e-3) && all(E.complete), 'a fixed window with a stop fills t1 (Stim offset, 0.5 s later)');
E = epochTable(src, eventRef(line="Trial"), Window=epochWindow(mode="between", pre=-0.1, post=0.1, stop=eventRef(line="Trial", edge="offset")));
check(max(abs(E.tStop - (src.trials.TrialOffset + 0.1))) < 1e-12, 'between Trial onset and offset');

fprintf('\n== 6. late-start: cut trials are not used ==\n');
src2 = loadAnalysisSource(F.outputs(2));
T2 = F.truth(2);
E = epochTable(src2, eventRef(line="Trial"));
ok = isfinite(T2.trials.Onset) & T2.trials.Interval > 1;   % intervals 2.. are whole; interval 1 is partial and cut
check(height(E) == 12 - T2.expectedCuts.trials(1) && all(src2.trials.PairingFlag(1:3) == "cut") ...
    && max(abs(E.t0 - T2.trials.Onset(ok))) < 1e-9, ...
    'the approved cuts leave 9 trials, aligned to the written onsets');
E = epochTable(src2, eventRef(line="Trial"), Selection=trialSelection(pairingFlags=string.empty(1,0)));
check(height(E) == 9, 'pairingFlags [] still skips trials without an interval');

fprintf('\n== 7. units and detections ==\n');
[st, meta] = selectUnits(src, struct('source', "units", 'classes', string.empty(1,0)));
check(numel(st) == numel(T1.units) && isequal(meta.nSpikes, cellfun(@numel, st)) ...
    && isequal(meta.channel, [T1.units.peakChannel].') && all(ismember(meta.class, ["su" "mua"])), ...
    'every sorted unit, with its peak channel and spike count');
tr = T1.units(1).samples;
check(max(abs(st{1} - (tr - 1) / T1.Fs)) < 1e-9, 'unit spike times are (sample-1)/Fs');
[st, meta] = selectUnits(src, struct('source', "units", 'classes', "su"));
check(all(meta.class == "su") && numel(st) == nnz([T1.units.label] == "good"), 'classes "su" keeps the good units');
[st, meta] = selectUnits(src, struct('source', "detected"));
check(numel(st) == numel(T1.channelNames) && isequal(meta.channel, (1:numel(T1.channelNames)).') && all(meta.class == "det") ...
    && all(isfinite(meta.y)) && isequal(meta.label, T1.channelNames(:)), 'detections: one "unit" per channel with its site');
[~, meta] = selectUnits(src, struct('source', "detected", 'shanks', 0, 'maxUnits', 3));
check(height(meta) == 3 && all(meta.shank == 0), 'shanks and maxUnits limit the detections');
[Y, fs, cm] = selectChannels(src, "LFP", Channels=[2 4]);
check(fs == 1000 && size(Y, 2) == 2 && isequal(cm.channel, [2; 4]) && isequal(cm.recordingChannel, [2; 4]) ...
    && all(cm.units == "uV") && abs(size(Y, 1) / fs - T1.duration) < 0.01, 'selectChannels: LFP columns with their sites');

fprintf('\n== 8. errors and the no-behavior fallback ==\n');
check(strcmp(errorId(@() epochTable(src, eventRef(line="Nope"))), 'resolveEvents:NoLine'), 'an unknown line: resolveEvents:NoLine');
check(strcmp(errorId(@() epochTable(src, eventRef(line="Stim", scope="recording"), Selection=trialSelection(groupBy="Nope"))), 'selectTrials:NoParam'), ...
    'an unknown groupBy parameter: selectTrials:NoParam');
check(strcmp(errorId(@() selectTrials(src, trialSelection(filter="system('dir')"))), 'trialSelection:BadFilter'), ...
    'a filter calling system(): trialSelection:BadFilter');
check(strcmp(errorId(@() trialSelection(filter="Depth > 0; x")), 'trialSelection:BadFilter') ...
    && strcmp(errorId(@() selectTrials(src, trialSelection(filter="Nope > 1"))), 'trialSelection:BadFilter'), ...
    'a filter with ";" or an unknown name: trialSelection:BadFilter');
check(strcmp(errorId(@() trialSelection(response="Win")), 'trialSelection:BadValue'), 'an unknown response word: trialSelection:BadValue');
check(strcmp(errorId(@() epochWindow(mode="between")), 'epochWindow:NoStop'), 'between without a stop: epochWindow:NoStop');
check(strcmp(errorId(@() eventRef(edge="middle")), 'eventRef:BadValue'), 'a bad edge: eventRef:BadValue');
check(strcmp(errorId(@() epochTable(src, eventRef(line="Stim"), Window=epochWindow(pre=-100, post=0))), 'epochTable:NoEpochs'), ...
    'windows outside the recording: epochTable:NoEpochs');
check(strcmp(errorId(@() epochTable(src, eventRef(line="Stim"), Selection=trialSelection(filter="Depth > 5"))), 'resolveEvents:NoEvents'), ...
    'a filter that keeps nothing: resolveEvents:NoEvents');
nb = src;
nb.hasBehavior = false; nb.hasTrials = false; nb.trials = table(); nb.nTrials = 0; nb.trialLine = "";
[E, G] = epochTable(nb, eventRef(line="Stim", which="all"));
check(height(E) == size(T1.events.Stim, 1) && all(isnan(E.trial)) && G.label == "all" && E.Properties.UserData.scope == "recording", ...
    'without behavior "auto" falls back to recording scope');
check(strcmp(errorId(@() epochTable(nb, eventRef(line="Stim"), Selection=trialSelection(groupBy="Depth"))), 'selectTrials:NoTrials') ...
    && strcmp(errorId(@() epochTable(nb, eventRef(line="Stim", scope="trial"))), 'resolveEvents:NoTrials') ...
    && strcmp(errorId(@() epochTable(nb, eventRef(line="Trial"))), 'resolveEvents:NoLine'), ...
    'without behavior, grouping / trial scope / "Trial" raise NoTrials / NoTrials / NoLine');

fprintf('\n================  %d passed, %d failed  ================\n', nPass, nFail);
if nFail > 0
    error('test_EphysAnalysisEpochs:Failures', '%d checks failed.', nFail);
end
end


function G = selectTrialsGroups(src, sel)
[~, G] = selectTrials(src, sel);
end


function rmdirQuiet(root)
if isfolder(root)
    try
        rmdir(root, 's');
    catch
    end
end
end
