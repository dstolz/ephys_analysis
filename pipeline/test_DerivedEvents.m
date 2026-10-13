function test_DerivedEvents()
%test_DerivedEvents  Verification suite for derived events (deriveEvents).
%   Checks deriveEvents on a trials table (one condition, several with
%   "all" / "any", text and response-word conditions, a line built on an
%   earlier derived one, unpaired trials and intervals outside every trial,
%   the errors and OnError="skip"), the config's Behavior.DerivedEvents
%   (normalized from a struct array, a cell array and JSON, validated,
%   carried by trialConfig and the standalone script's literal), then on a
%   synthetic RHD recording: the behavior file (derivedEvents, the lines in
%   TrialEvents, the InDataset trials column, a definition the session
%   cannot meet left out, none without a pairing), the extract's events
%   (toMat, and writeExtractEvents bringing an existing extract up to date
%   without touching its signals), the exports (exportChronux,
%   eventEpochs) and the analysis source (loadAnalysisSource,
%   resolveEvents, selectTrials), and the DerivedEventsDialog.
%
%   Usage:  test_DerivedEvents

here = fileparts(mfilename('fullpath'));
addpath(here);
addpath(fullfile(fileparts(here), 'analysis'));

root = fullfile(tempdir, sprintf('Derived_test_%s', datestr(now, 'yyyymmdd_HHMMSSFFF'))); %#ok<TNOW1,DATST>
mkdir(root);
cleanup = onCleanup(@() rmdir(root, 's')); %#ok<NASGU>

nPass = 0; nFail = 0;
    function check(cond, msg)
        if cond
            nPass = nPass + 1;
            fprintf('  PASS: %s\n', msg);
        else
            nFail = nFail + 1;
            fprintf(2, '  FAIL: %s\n', msg);
            LegacySuiteTest.checkFailed(msg);   % one failure per check in run_all_tests' report
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
    function d = def(name, line, conds, varargin)
        d = EphysPipelineConfig.defaults("DerivedEvent");
        d.Name = name; d.Line = line; d.Conditions = conds;
        for j = 1:2:numel(varargin); d.(varargin{j}) = varargin{j + 1}; end
    end

fprintf('\n== 1. deriveEvents on a trials table ==\n');
on = [10; 20; 30; 40; 50; NaN];                % trial 6 is unpaired
T = table((1:6).', [0; -2; -4; -6; -8; -10], [1; 2; 1; 4; 1; 1], ["a"; "b"; "a"; "b"; "a"; "a"], on, on + 5, ...
    'VariableNames', {'TrialIndex', 'Depth', 'RespCode', 'Side', 'TrialOnset', 'TrialOffset'});
ev = struct('InTrial', [on(1:5), on(1:5) + 5; 60 65], ...             % 60 s: an interval no trial was paired with
    'Stim', [on(1:5) + 1, on(1:5) + 1.1; 8 8.1]);                     % 8 s: before every trial
[E, D, failed] = deriveEvents(ev, T, def("Shallow", "Trial", "Depth >= -4"), TrialLine="InTrial");
check(isequal(E.Shallow, ev.InTrial(1:3, :)) && isscalar(D) && D.index == 1 && D.nTrials == 3 && D.nIntervals == 3 ...
    && isequal(D.trials, [true; true; true; false; false; false]) && D.sourceLine == "InTrial" && isempty(failed) ...
    && D.description == "Trial intervals of the trials where Depth >= -4", ...
    '"Trial" takes the trial line''s intervals of the trials that meet the condition');
defs = [def("Mid", "Stim", ["Depth < -2" "Depth >= -6"]), ...
        def("Ends", "Stim", ["Depth == 0" "Depth <= -8"], 'Combine', "any"), ...
        def("MidHit", "Mid", "Hit"), ...
        def("SideA", "InTrial", "Side == ""a"" & !CR", 'InDataset', true)];
[E, D] = deriveEvents(ev, T, defs, TrialLine="InTrial");
check(isequal(E.Mid, ev.Stim(3:4, :)) && isequal(E.Ends, ev.Stim([1 5], :)) && D(1).expression == "(Depth < -2) & (Depth >= -6)" ...
    && D(2).expression == "(Depth == 0) | (Depth <= -8)", 'several conditions combine with all (AND) or any (OR)');
check(isequal(E.MidHit, ev.Stim(3, :)) && D(3).sourceLine == "Mid", 'a derived event can take its intervals from an earlier one');
check(isequal(E.SideA, ev.InTrial([1 3 5], :)) && isequal(D(4).trials, [true; false; true; false; true; true]) ...
    && D(4).nTrials == 3 && D(4).inDataset, 'text columns and response words; the trial mask covers unpaired trials, nTrials only paired ones');
check(~ismember(8, E.Mid(:, 1)) && ~any(E.SideA(:, 1) == 60), 'intervals outside every paired trial are dropped');
check(strcmp(errorId(@() deriveEvents(ev, T, def("1bad", "Trial", "Depth > 0"), TrialLine="InTrial")), 'deriveEvents:BadName') ...
    && strcmp(errorId(@() deriveEvents(ev, T, def("Stim", "Trial", "Depth > 0"), TrialLine="InTrial")), 'deriveEvents:BadName') ...
    && strcmp(errorId(@() deriveEvents(ev, T, def("Depth", "Trial", "Depth > 0", 'InDataset', true), TrialLine="InTrial")), 'deriveEvents:BadName') ...
    && strcmp(errorId(@() deriveEvents(ev, T, def("X", "Nope", "Depth > 0"), TrialLine="InTrial")), 'deriveEvents:NoLine') ...
    && strcmp(errorId(@() deriveEvents(ev, T, def("X", "Trial", string.empty(1, 0)), TrialLine="InTrial")), 'deriveEvents:BadCondition') ...
    && strcmp(errorId(@() deriveEvents(ev, T, def("X", "Trial", "Dpeth > 0"), TrialLine="InTrial")), 'deriveEvents:BadCondition') ...
    && strcmp(errorId(@() deriveEvents(ev, T, def("X", "Trial", "system('dir')"), TrialLine="InTrial")), 'deriveEvents:BadCondition') ...
    && strcmp(errorId(@() deriveEvents(ev, T(:, 1:4), def("X", "Trial", "Depth > 0"))), 'deriveEvents:NoTrials'), ...
    'bad names, lines, conditions (eval never reached) and unpaired trials are errors');
[E, D, failed] = deriveEvents(ev, T, [def("Bad", "Trial", "Dpeth > 0"), def("Good", "Trial", "Depth == 0")], ...
    TrialLine="InTrial", OnError="skip");
check(~isfield(E, 'Bad') && isfield(E, 'Good') && isscalar(D) && D.index == 2 && isscalar(failed) && failed.index == 1 ...
    && failed.identifier == "deriveEvents:BadCondition" && contains(failed.message, "Dpeth"), ...
    'OnError="skip" leaves a failing definition out and says why');
[E0, D0] = deriveEvents(ev, table(), []);
check(isequal(E0, ev) && isempty(D0) && isfield(D0, 'intervals'), 'no definitions: the events as given and an empty D');

fprintf('\n== 2. Behavior.DerivedEvents in the config ==\n');
two = [def("Shallow", "Trial", "Depth >= -6"), def("Mid", "Trial", ["Depth < -6" "Depth >= -10"], 'InDataset', true)];
cfg = EphysPipelineConfig();
check(isempty(cfg.Behavior.DerivedEvents) && isfield(cfg.Behavior.DerivedEvents, 'Conditions'), 'none by default');
cfg.Behavior.DerivedEvents = two;
cfgC = EphysPipelineConfig(); cfgC.Behavior.DerivedEvents = {struct('Name', "A", 'Conditions', "Depth > 0")};
check(isequal(cfg.Behavior.DerivedEvents, two) && cfgC.Behavior.DerivedEvents.Line == "Trial" ...
    && isequal(cfgC.Behavior.DerivedEvents.Conditions, "Depth > 0"), 'a struct array or a cell array of partial structs is normalized');
jf = fullfile(root, 'cfg.json');
cfg.save(jf);
cfg2 = EphysPipelineConfig.load(jf);
cfg1 = EphysPipelineConfig(); cfg1.Behavior.DerivedEvents = two(2); cfg1.save(jf);
cfg3 = EphysPipelineConfig.load(jf);
check(isequal(cfg2.Behavior.DerivedEvents, two) && isequal(cfg3.Behavior.DerivedEvents, two(2)) ...
    && isequal(cfg3.Behavior.DerivedEvents.Conditions, ["Depth < -6" "Depth >= -10"]), ...
    'the definitions survive the JSON round trip, the conditions as typed (one definition too)');
tc = EphysPipelineConfig.trialConfig(cfg);
x = eval(EphysPipelineScript.literal(tc.DerivedEvents));
check(isequal(tc.DerivedEvents, two) && isequal(x, two), 'trialConfig carries them, and the standalone script writes them back exactly');
bad = cfg;
bad.Behavior.DerivedEvents = [two, def("Shallow", "Trial", "Depth > 0"), def("x y", "", string.empty(1, 0)), ...
    def("Odd", "Trial", "Depth >"), def("Comb", "Trial", "Depth > 0", 'Combine', "some")];
I = bad.validate(CheckPaths=false);
msgs = I.Message(I.Field == "DerivedEvents" & I.Severity == "error");
check(any(contains(msgs, "used twice")) && any(contains(msgs, "not a valid name")) && any(contains(msgs, "Line must")) ...
    && any(contains(msgs, "at least one condition")) && any(contains(msgs, "not a valid expression")) && any(contains(msgs, "Combine")) ...
    && ~any(cfg.validate(CheckPaths=false).Field == "DerivedEvents"), 'validate checks the names, lines, conditions and Combine');
np = cfg; np.Behavior.Enabled = true; np.Behavior.SearchDirs = root; np.Behavior.PairTrials = false;
I = np.validate(CheckPaths=false);
check(any(I.Field == "DerivedEvents" & I.Severity == "warning"), 'derived events without pairing are a warning');

fprintf('\n== 3. behavior file, extract, exports, analysis ==\n');
Fs = 1000; spb = 128; nSamp = 64 * spb; k = 5;
onR = (1:k).' * 1200; offR = onR + 300;
din0 = zeros(1, nSamp); din1 = zeros(1, nSamp);
for i = 1:k
    din0(onR(i):offR(i)) = 1;
    din1(onR(i) + 100:onR(i) + 150) = 1;
end
din1(7000:7050) = 1;                                   % a pulse after every trial
recDir = fullfile(root, 'proj', 'mouseA_260101T120000_rec'); mkdir(recDir);
rng(5);
writeSyntheticRHD(fullfile(recDir, 'mouseA_260101T120000_rec.rhd'), ...
    uint16(randi([30000 35000], 2, nSamp)), din0 + 2 * din1, Fs, spb, DigInNames=["din0" "din1"]);
t0 = datetime(2026, 1, 1, 12, 0, 0);
ts = t0 + seconds(offR / Fs + 3);
Data = struct('Depth', num2cell([0 -2 -4 -6 -8]), 'RespCode', num2cell([1 2 1 4 1]), 'TrialIndex', num2cell(1:k), ...
    'computerTimestamp', num2cell(ts.'), 'isTest', num2cell(false(1, k)));
Info = struct('Subject', struct('Name', "mouseA"), 'StartTime', t0, 'FormatVersion', 2);
behFile = fullfile(root, 'mouseA_260101T120000.mat');
save(behFile, 'Data', 'Info');

d = EphysDataset(recDir);
d.OutputDir = fullfile(root, 'out', d.Name);
d.BehaviorFile = behFile;
tc = d.TrialConfig;
tc.TrialLine = "din0";
tc.DerivedEvents = [def("Shallow", "Trial", "Depth >= -4"), ...
                    def("DeepStim", "din1", ["Depth < -4" "Depth >= -8"], 'InDataset', true), ...
                    def("ShallowHit", "Shallow", "Hit")];
d.TrialConfig = tc;
P = d.pairTrials(Warn=false);
o = d.behaviorToMat(Pairing=P);
B = load(o.file).behavior;
DE = B.derivedEvents;
check(isequal([DE.name], ["Shallow" "DeepStim" "ShallowHit"]) && isequal([DE.nIntervals], [3 2 2]) ...
    && isequal(o.derivedEvents, [DE.name]) && isempty(o.derivedFailed) && isempty(o.extractFiles) && isempty(B.derivedEventsFailed), ...
    'the behavior file holds the derived events and their intervals');
check(isequal(round(DE(2).intervals(:, 1) * Fs), onR(4:5) + 100) && isequal(round(DE(1).intervals(:, 1) * Fs), onR(1:3)), ...
    'the intervals are those of the source line in the trials that meet the conditions');
bt = B.trials;
check(isequal(bt.DeepStim, [false; false; false; true; true]) && ~ismember("Shallow", bt.Properties.VariableNames) ...
    && size(bt.TrialEvents(4).DeepStim, 1) == 1 && isempty(bt.TrialEvents(1).DeepStim) && size(bt.TrialEvents(1).Shallow, 1) == 1 ...
    && isequal(bt.TrialEventSamples(4).DeepStim, round(bt.TrialEvents(4).DeepStim * Fs)), ...
    'each derived line joins every trial''s TrialEvents; InDataset adds a logical trials column');

xf = fullfile(d.outputFolder(), d.Name + "_extract.mat");
if license('test', 'Signal_Toolbox')
    d.toMat(SignalOptions=struct('dataTypeOut', "LFP", 'LFP_Fs', 250));
    X = load(xf, 'events', 'info', 'Y');
    check(isfield(X.events, 'DeepStim') && ~isfield(X.events, 'Shallow') && isfield(X.events, 'din1') ...
        && isequal(X.events.DeepStim, DE(2).intervals) && isequal([X.info.derivedEvents.name], "DeepStim") ...
        && X.info.derivedEvents.expression == "(Depth < -4) & (Depth >= -8)", ...
        'toMat puts the InDataset events into the extract''s events and lists them in info.derivedEvents');
    tc.DerivedEvents(1).InDataset = true;
    tc.DerivedEvents(2).InDataset = false;
    d.TrialConfig = tc;
    o2 = d.behaviorToMat(Pairing=P, Overwrite=true);
    X2 = load(xf, 'events', 'info', 'Y');
    check(isequal(o2.extractFiles, string(xf)) && isfield(X2.events, 'Shallow') && ~isfield(X2.events, 'DeepStim') ...
        && isequal([X2.info.derivedEvents.name], "Shallow") && isequal(X2.Y.LFP, X.Y.LFP) && isfield(X2.events, 'din0'), ...
        'the behavior step brings an existing extract''s events up to date, its signals untouched');
    o3 = d.behaviorToMat(Pairing=P, Overwrite=true);
    check(isempty(o3.extractFiles), 'an extract already up to date is not written again');
    cf = d.exportChronux();
    C = load(cf.file, 'events');
    check(all(isfield(C.events, {'Shallow', 'DeepStim', 'ShallowHit', 'din0', 'din1'})) && isequal(C.events.DeepStim, DE(2).intervals), ...
        'an export carries every derived event, in the extract or not');
    EP = d.eventEpochs(EventLine="ShallowHit", Window=[-0.05 0.1]);
    check(EP.event.nEpochs == 2, 'the epochs export cuts epochs around a derived event');
else
    fprintf('  (extract and export checks skipped: Signal Processing Toolbox not available)\n');
    tc.DerivedEvents(1).InDataset = true;
    tc.DerivedEvents(2).InDataset = false;
    d.TrialConfig = tc;
    d.behaviorToMat(Pairing=P, Overwrite=true);
end

src = loadAnalysisSource(d.outputs());
row = src.lines(src.lines.Line == "ShallowHit", :);
check(all(isfield(src.events, {'Shallow', 'DeepStim', 'ShallowHit'})) && numel(src.derivedEvents) == 3 && height(row) == 1 ...
    && row.Count == 2 && contains(row.Derived, "Shallow intervals of the trials where Hit") ...
    && all(src.lines.Derived(ismember(src.lines.Line, ["din0" "din1"])) == ""), ...
    'the analysis source has the derived lines, marked in its lines table');
tTrial = resolveEvents(src, eventRef(line="DeepStim", scope="trial", which="all"));
tRec = resolveEvents(src, eventRef(line="DeepStim", scope="recording", which="all"));
check(isequal(round(tTrial * Fs), onR(4:5) + 100) && isequal(tTrial, tRec), 'a derived event aligns in trial and recording scope');
mask = selectTrials(src, trialSelection(filter="Shallow & Hit"));
check(isequal(mask, [true; false; true; false; false]), 'an InDataset event is a trial column the filters use');

tc.DerivedEvents(end+1) = def("Bad", "Trial", "Nope > 1");
d.TrialConfig = tc;
ws = warning('off', 'EphysDataset:behaviorStruct:DerivedEvent');
lastwarn('');
d.behaviorStruct(Pairing=P);
[~, wid] = lastwarn;                        % (behaviorToMat's save clears lastwarn)
o4 = d.behaviorToMat(Pairing=P, Overwrite=true);
warning(ws);
B4 = load(o4.file).behavior;
check(isequal(o4.derivedEvents, ["Shallow" "DeepStim" "ShallowHit"]) && isscalar(o4.derivedFailed) && contains(o4.derivedFailed, "Nope") ...
    && strcmp(wid, 'EphysDataset:behaviorStruct:DerivedEvent') && B4.derivedEventsFailed.name == "Bad", ...
    'a definition the session cannot meet is left out with a warning; the others and the file are still written');
ws = warning('off', 'EphysDataset:behaviorStruct:NoPairing');
lastwarn('');
b0 = d.behaviorStruct();
[~, wid] = lastwarn;
warning(ws);
check(isempty(b0.derivedEvents) && strcmp(wid, 'EphysDataset:behaviorStruct:NoPairing'), 'without a pairing there are none, with a warning');

fprintf('\n== 4. DerivedEventsDialog ==\n');
got = {};
    function setGot(defs)
        got{end+1} = defs;
    end
dlg = DerivedEventsDialog([], Visible=false, OnChange=@setGot);
dlg.add();
check(isscalar(dlg.Defs) && dlg.Defs.Name == "Event1" && dlg.Selected == 1 && contains(dlg.Results(1).message, "no condition") ...
    && numel(got) == 1, 'Add makes a definition and tells the owner; without a condition it says so');
dlg.edit("Name", "Shallow");
dlg.edit("Conditions", "Depth >= -4" + newline + "  " + newline + "Hit");
check(isequal(dlg.Defs.Conditions, ["Depth >= -4" "Hit"]) && dlg.Results(1).message == "" && isnan(dlg.Results(1).nTrials) ...
    && isequal(got{end}, dlg.Defs), 'the conditions are one per line (blank lines dropped); without a dataset only the syntax is checked');
dlg.setPreview(P.events, bt, "din0", "rec");
check(dlg.Results(1).nTrials == 2 && dlg.Results(1).nIntervals == 2 && contains(dlg.ResultText, "2 of 5 paired trials"), ...
    'with a preview each definition is counted on the dataset');
dlg.edit("Combine", "any");
check(dlg.Results(1).nTrials == 4 && dlg.Defs.Combine == "any", 'Combine "any" counts the trials that meet either');
dlg.duplicate();
check(numel(dlg.Defs) == 2 && dlg.Defs(2).Name == "Shallow1" && dlg.Selected == 2 && isequal(dlg.Defs(2).Conditions, dlg.Defs(1).Conditions), ...
    'Duplicate copies the selected definition under a free name');
dlg.edit("Conditions", "Dpeth > 1");
check(contains(dlg.Results(2).message, "Dpeth") && dlg.Results(1).message == "", 'a condition on a missing column is shown as that definition''s error');
dlg.move(-1);
check(dlg.Defs(1).Name == "Shallow1" && dlg.Selected == 1, 'Up moves the selected definition');
dlg.remove();
check(isscalar(dlg.Defs) && dlg.Defs.Name == "Shallow" && isscalar(got{end}), 'Remove deletes it');
n = numel(got);
dlg.setDefinitions(two);
check(isequal(dlg.Defs, two) && numel(got) == n, 'setDefinitions shows other definitions without calling OnChange');
fig = dlg.Fig;
delete(dlg);
check(~isvalid(fig), 'deleting the dialog closes its window');

fprintf('\n================  %d passed, %d failed  ================\n', nPass, nFail);
if nFail > 0
    error('test_DerivedEvents:Failures', '%d checks failed.', nFail);
end
end
