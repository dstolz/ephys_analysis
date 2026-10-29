classdef test_DatasetBrowser < matlab.unittest.TestCase
    %test_DatasetBrowser  DatasetBrowser, mostly with its window hidden (Visible=false).
    %   Over the analysis fixture (two synthetic datasets run through the
    %   pipeline, tagged here): a scan loads no source; the filter and the
    %   ticks through the methods and through the controls' callbacks (a
    %   tick on a sorted row goes to its dataset); the settings form (a
    %   round trip, hidden fields kept, the Data drop-down's blocks, an
    %   invalid edit undone); a drop-down opening loads one source; compute
    %   equals epochMatrix, a dataset ticked later is the only one computed,
    %   a binSec change computes all; the exported script (exportScript:
    %   the ticked keys, only the settings that differ, no browser) gives
    %   the compute's result; loadSessions gives each ticked dataset whole
    %   (the units Compute uses, every trial with the selection marked, the
    %   events on the spikes' clock as epochTable puts them; a signal's
    %   channels kept) and caches nothing; a Normalize change normalizes the
    %   result again in place (still current, nothing assembled, the same as
    %   a compute), and its controls are on only where they apply; the
    %   result file restores without a
    %   compute, and Scan=false; Keep single trials (its own cached parts,
    %   R.epochs left out of the result file and assembled again from the
    %   parts on a restore, a warning without them); the trial rasters
    %   (raster: every row's spikes on their epochs, in group or time order,
    %   counts that average to R.data; a signal's epochs that average to
    %   R.data; the window follows the result and closes with the browser;
    %   no result or no epochs raise); forEach's cache and cancel; the progress
    %   strip (bar widths, the "i/Total" prefix, Cancel and checkCancel, a
    %   full bar at the finish, the command window throttled when hidden);
    %   a compute canceled from the strip keeps its finished part, the
    %   controls off while busy; wait and done (a visible window, a timer);
    %   DatasetBrowser.open returns the window open on the root (never a
    %   hidden or closed one; a new browser for another root); closing
    %   keeps the result and saves the preferences. A dataset whose
    %   outputs changed (its manifest's time, restored afterwards) reads
    %   "old" after a scan and is the only one computed again;
    %   forgetTicked with nothing ticked keeps the cache. checkCancel ends a
    %   script's canceled run; a second Cancel ends a script's run left
    %   open, but not the browser's own compute. Workers: the option, the
    %   field and the preference; on process workers (Slow) compute equals
    %   epochMatrix here and is cached, and forEach runs there too.
    %   Post-processing scripts: the first list (analysis\scripts), a script
    %   added and picked, Compute runs it in the base workspace (B there)
    %   only with the box ticked, Run now, a failing script's name and line,
    %   removing keeps the file, the bundled script runs on a result, the
    %   preferences.
    %
    %   Usage:  runtests("test_DatasetBrowser")

    properties (SetAccess = private)
        Fixture = []
        Root (1,1) string = ""
        Keys (:,1) string = strings(0, 1)
        Names (:,1) string = strings(0, 1)
        Spike = []       % the spike settings of test_EpochMatrix (Stim, [-0.2 0.5] s, Depth descending)
    end

    methods (TestClassSetup)
        function makeFixture(tc)
            here = fileparts(mfilename('fullpath'));
            repo = fileparts(here);
            addpath(fullfile(repo, 'pipeline'));
            addpath(repo);
            addpath(genpath(fullfile(repo, 'vendor')));
            tc.applyFixture(AppPrefsFixture);
            tmp = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            F = makeAnalysisFixture(string(tmp.Folder), Scenarios=["clean" "late-start"], NumTrials=12);
            tc.Fixture = F;
            tc.Root = F.proj;
            P = EphysProject(F.proj);
            P.refresh();
            tags = {{'ofc', 'pilot'}, {'ofc'}};
            for k = 1:numel(F.names)
                d = P.dataset(F.names(k));
                d.Tags = tags{min(k, 2)};
                d.writeManifest();
            end
            tc.Keys = reshape(F.keys, [], 1);
            tc.Names = reshape(F.names, [], 1);
            tc.Spike = epochMatrixSettings([], ref=eventRef(line="Stim"), window=epochWindow(pre=-0.2, post=0.5), ...
                selection=trialSelection(groupBy="Depth", groupOrder="descending"));
        end
    end

    methods
        function B = open(tc, varargin)
            %open  A hidden browser on the fixture with its own result file (unless one is given), closed afterwards.
            args = varargin;
            if ~any(cellfun(@(a) (ischar(a) || isstring(a)) && string(a) == "ResultFile", args(1:2:end)))
                tmp = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
                args = [args, {'ResultFile', fullfile(tmp.Folder, "results.mat")}];
            end
            if ~any(cellfun(@(a) (ischar(a) || isstring(a)) && string(a) == "Visible", args(1:2:end)))
                args = [args, {'Visible', false}];
            end
            B = DatasetBrowser(tc.Root, args{:});
            tc.addTeardown(@() delete(B));
        end
    end

    methods (Test)
        function helpMenuAndAbout(tc)
            B = tc.open(Scan=false);
            help = findobj(B.Fig.Children, "flat", "Type", "uimenu", "Text", "Help");
            tc.verifyNotEmpty(help, 'A Help menu.');
            tc.verifyEqual(flip(string({help.Children.Text})), ...
                ["Help for DatasetBrowser" "Documentation home" "About DatasetBrowser"]);
            tc.verifyEqual(DatasetBrowser.WikiURL, "https://github.com/dstolz/ephys_analysis/wiki");
            L = B.aboutText();
            txt = join(L, newline);
            tc.verifyTrue(contains(txt, "Describe: ") && contains(txt, "Last commit of analysis/DatasetBrowser.m: ") ...
                && contains(txt, "Result file: dataset-browser-results v" + DatasetBrowser.Version) ...
                && contains(txt, "Cache (DatasetRuns): v" + DatasetRuns.Version) && contains(txt, "Root: " + B.Root), txt);
        end

        function scanLoadsNoSource(tc)
            B = tc.open();
            tc.verifyNotEmpty(B.Runner);
            tc.verifyEqual(B.Runner.Sources.Count, uint64(0), 'A scan loads no source.');
            D = B.Datasets;
            tc.verifyEqual(sort(D.key), sort(tc.Keys));
            tc.verifyTrue(all(D.subject ~= "") && all(~isnat(D.date)));
            tc.verifyTrue(all(D.detected) && all(D.behavior));
            tc.verifyTrue(all(contains(D.signals, "LFP")) && all(contains(D.signals, "AUX")));
            k1 = D.key == tc.Keys(1);
            tc.verifyEqual(D.tags(k1), "ofc;pilot");
            tc.verifyEqual(sort(B.Selected), sort(tc.Keys), 'With no saved state, a scan ticks what shows.');
            T = B.Table;
            tc.verifyEqual(string(T.Properties.VariableNames), ["Use" "Name" "Subject" "Date" "Session" "Tags" ...
                "Units" "Detected" "Behavior" "Signals" "Cached" "Key" "Idx"]);
            tc.verifyEqual(B.Ctl.Table.Data, T);
            tc.verifyEqual(B.Ctl.Table.ColumnEditable, [true false(1, 12)]);
            tc.verifyTrue(all(T.Cached == ""));
            tc.verifyEmpty(B.Result);
            tc.verifyFalse(B.Busy);
        end

        function filterAndTicks(tc)
            B = tc.open();
            k1 = tc.Keys(1); k2 = tc.Keys(2);
            seen = containers.Map();
            B.OnChange = @(~, what) count(seen, what);
            B.setFilter(Tags="pilot");
            tc.verifyEqual(B.Shown, k1);
            tc.verifyEqual(sort(B.Selected), sort(tc.Keys), 'A filter leaves the ticks.');
            tc.verifyTrue(startsWith(B.Ctl.Count.Text, "showing 1 of 2 (1 ticked hidden)"), B.Ctl.Count.Text);
            tc.verifyTrue(endsWith(B.Ctl.Count.Text, "2 ticked"), B.Ctl.Count.Text);
            B.setFilter(Tags=["ofc" "pilot"], TagMode="all");
            tc.verifyEqual(B.Shown, k1);
            B.setFilter(Tags="", ExcludeTags="pilot");
            tc.verifyEqual(B.Shown, k2);
            B.clearFilter();
            tc.verifyEqual(sort(B.Shown), sort(tc.Keys));
            B.setFilter(Search=tc.Names(2));
            tc.verifyEqual(B.Shown, k2);
            B.setFilter(Search="");
            sub = B.Datasets.subject(B.Datasets.key == k1);
            B.setFilter(Subjects=sub);
            tc.verifyTrue(ismember(k1, B.Shown));
            B.setFilter(Subjects="", ExcludeSubjects=sub);
            tc.verifyFalse(ismember(k1, B.Shown));
            B.clearFilter();
            tc.verifyTrue(seen.isKey('filter'));

            % the filter controls
            c = B.Ctl;
            tc.verifyTrue(all(ismember({'(any)', 'ofc', 'pilot'}, c.Tags.Items)), 'The tag lists offer the tags in use.');
            c.Tags.Value = 'pilot';
            c.Tags.ValueChangedFcn(c.Tags, []);
            tc.verifyEqual(B.Filter.Tags, "pilot");
            tc.verifyEqual(B.Shown, k1);
            c.Tags.Value = 'xyz';   % typed: no such tag
            c.Tags.ValueChangedFcn(c.Tags, []);
            tc.verifyEqual(string(c.Tags.Value), "xyz", 'A typed value stays.');
            tc.verifyEmpty(B.Shown);
            c.Tags.Value = '(any)';
            c.Tags.ValueChangedFcn(c.Tags, []);
            tc.verifyEqual(B.Filter.Tags, "");
            c.NotTags.Value = 'pilot';
            c.NotTags.ValueChangedFcn(c.NotTags, []);
            tc.verifyEqual(B.Shown, k2);
            c.TickShown.ButtonPushedFcn(c.TickShown, []);
            tc.verifyEqual(B.Selected, k2, 'Tick shown only.');
            tc.verifyTrue(seen.isKey('ticks'));
            c.UntickAll.ButtonPushedFcn(c.UntickAll, []);
            tc.verifyEmpty(B.Selected);
            c.NotTags.Value = '(any)';
            c.NotTags.ValueChangedFcn(c.NotTags, []);
            c.Search.Value = char(tc.Names(1));
            c.Search.ValueChangedFcn(c.Search, []);
            tc.verifyEqual(B.Shown, k1);
            c.Search.ValueChangingFcn(c.Search, struct('Value', ''));
            tc.verifyEqual(sort(B.Shown), sort(tc.Keys));

            % the methods
            B.tick(k2);
            tc.verifyEqual(B.Selected, k2);
            B.tick(tc.Names(1), true);   % a name works too
            tc.verifyEqual(sort(B.Selected), sort(tc.Keys));
            B.tick(k2, false);
            tc.verifyEqual(B.Selected, k1);
            tc.verifyError(@() B.tick("nope"), 'DatasetBrowser:UnknownDataset');
            B.Selected = tc.Keys;
            B.untickAll();

            % a tick on a sorted row goes to that row's dataset
            B.sortBy("Name", "descend");
            T = B.Ctl.Table.Data;
            tc.verifyEqual(T.Name, sort(B.Datasets.name, 'descend'));
            c.Table.CellEditCallback(c.Table, struct('Indices', [1 1], 'NewData', true));
            tc.verifyEqual(B.Selected, B.Datasets.key(B.Datasets.name == T.Name(1)));
            tc.verifyTrue(B.Ctl.Table.Data.Use(1));
            B.clearSort();
            tc.verifyEqual(B.Ctl.Table.Data.Idx, (1:height(B.Datasets)).');
            % a header click is kept as the sort
            c.Table.DisplayDataChangedFcn(c.Table, struct('Interaction', 'sort', 'InteractionColumn', 3, ...
                'InteractionVariable', 'Subject'));
            tc.verifyEqual(B.Sort.column, "Subject");
            tc.verifyEqual(B.Filter, struct('Subjects', "", 'ExcludeSubjects', "", 'Tags', "", 'TagMode', "any", ...
                'ExcludeTags', "", 'Search', ""));
            tc.verifyError(@() B.setFilter(TagMode="some"), 'DatasetBrowser:BadFilter');
        end

        function formRoundTrip(tc)
            B = tc.open();
            ref = eventRef(line="Stim", scope="trial", sequence=[struct('line', "Platform", 'edge', "offset"), ...
                struct('line', "Trough", 'edge', "onset")]);
            S = epochMatrixSettings([], ref=ref, window=epochWindow(pre=-1, post=1), ...
                selection=trialSelection(response="Hit", groupBy="Depth", groupOrder="descending", filter="Depth > 0"), ...
                data="detected", units=struct('classes', "su", 'shanks', 1:4, 'merge', struct('enabled', true)), ...
                measure="rate", binSec=0.01, baseline=[-1 -0.5], signal=struct('detrend', true), ...
                normalize=struct('method', "zscore", 'baseline', [-0.4 0], 'scope', "group"), keepEpochs=true);
            B.Settings = S;
            c = B.Ctl;
            A = c.Align;
            tc.verifyEqual(string(c.Data.Value), "detected");
            tc.verifyEqual(string(A.Line.Value), "Stim");
            tc.verifyEqual(string(A.Scope.Value), "trial");
            tc.verifyEqual(A.SeqText.UserData.sequence, S.ref.sequence, 'The sequence is kept in its summary label.');
            tc.verifyEqual(string(A.SeqText.Text), "then Platform offset then Trough onset");
            tc.verifyEqual(A.Pre.Value, -1);
            tc.verifyEqual(string(A.Mode.ItemsData), "fixed", 'epochMatrix takes a fixed window only.');
            tc.verifyEqual(A.Mode.Visible, matlab.lang.OnOffSwitchState(false));
            tc.verifyEqual(A.StopOn.Visible, matlab.lang.OnOffSwitchState(false));
            tc.verifyEqual(string(A.Filter.Value), "Depth > 0");
            tc.verifyEqual(string(A.Response.Value), "Hit");
            tc.verifyEqual(string(A.Flags.Value), "ok");
            tc.verifyEqual(string(A.Group1.Value), "Depth");
            tc.verifyEqual(string(A.Group2.Value), "(none)");
            tc.verifyEqual(string(A.Order.Value), "descending");
            tc.verifyTrue(c.Merge.Value);
            tc.verifyEqual(string(c.Shanks.Value), "1:4", 'The Channels tab shows the units'' shanks for detected.');
            tc.verifyEqual(string(c.Baseline.Value), "-1 -0.5");
            tc.verifyTrue(c.Detrend.Value);
            tc.verifyEqual(string({c.Normalize.Value c.NormBaseline.Value c.NormScope.Value}), ["zscore" "-0.4 0" "group"]);
            tc.verifyTrue(c.KeepEpochs.Value);
            % every control applied as it shows gives the settings back
            for name = ["Data" "Line" "Edge" "Which" "N" "Scope" "Offset" "MinDur" "MaxDur" "TimeFrom" "TimeTo" ...
                    "ShiftParam" "ShiftUnit" "Pre" "Post" "Filter" "Response" "Flags" "Group1" "Group2" "Order" "MaxGroups" ...
                    "ExcludeArtifacts" "MinArtifact" "Normalize" "NormBaseline" "NormScope" "Merge" "Shanks" "Measure" "Bin" "Baseline" "Channels" "SigBaseline" "Statistic" ...
                    "Detrend" "Rectify" "Magnitude" "KeepEpochs"]
                B.formEdit(name);
                tc.verifyEqual(B.Settings, S, name + " applied as shown changes nothing");
            end
            % an edit keeps the fields the form does not show
            B.formEdit("Pre", -0.5);
            S2 = B.Settings;
            tc.verifyEqual(S2.window.pre, -0.5);
            tc.verifyEqual(S2.ref.scope, "trial");
            tc.verifyEqual(numel(S2.ref.sequence), 2);
            tc.verifyEqual(S2.selection.filter, "Depth > 0");
            tc.verifyEqual(S2.units.classes, "su");
            tc.verifyTrue(S2.signal.detrend);
            B.formEdit("Shanks", "1 3");
            tc.verifyEqual(B.Settings.units.shanks, [1 3]);
            B.formEdit("Shanks", "");
            tc.verifyEmpty(B.Settings.units.shanks);
            B.formEdit("Response", ["Hit" "Miss"]);
            tc.verifyEqual(B.Settings.selection.response, ["Hit" "Miss"]);
            % the trial selection: every field of trialSelection
            B.formEdit("Filter", "Depth > 0.5 & ~FA");
            B.formEdit("Flags", ["ok" "partial"]);
            B.formEdit("Group2", "Level");
            B.formEdit("MaxGroups", 20);
            B.formEdit("ExcludeArtifacts", false);
            sel = B.Settings.selection;
            tc.verifyEqual({sel.filter, sel.pairingFlags, sel.groupBy, sel.maxGroups, sel.excludeArtifacts}, ...
                {"Depth > 0.5 & ~FA", ["ok" "partial"], ["Depth" "Level"], 20, false});
            tc.verifyEqual(A.MinArtifact.Enable, matlab.lang.OnOffSwitchState(false));
            B.formEdit("Filter", "Depth >");   % does not parse: undone
            tc.verifyEqual(B.Settings.selection.filter, "Depth > 0.5 & ~FA");
            tc.verifyEqual(string(A.Filter.Value), "Depth > 0.5 & ~FA");
            tc.verifyTrue(startsWith(string(c.Status.Text), "Not applied"), c.Status.Text);
            B.formEdit("Which", "nth");
            tc.verifyEqual(A.N.Enable, matlab.lang.OnOffSwitchState(true));
            B.formEdit("N", 2);
            tc.verifyEqual([B.Settings.ref.which B.Settings.ref.n], ["nth" "2"]);
            B.formEdit("Which", "first");
            % the sequence: the analysis app's Event sequence window
            A.SeqEdit.ButtonPushedFcn(A.SeqEdit, []);
            tc.addTeardown(@() delete(B.SequenceDialog));
            D = B.SequenceDialog.UserData;
            tc.verifyEqual(height(D.Table.Data), 2);
            tc.verifyEqual(string(D.Line.Value), "Stim");
            D.Table.CellSelectionCallback(D.Table, struct('Indices', [1 1]));
            D.RemoveStep.ButtonPushedFcn(D.RemoveStep, []);
            D.AddStep.ButtonPushedFcn(D.AddStep, []);   % a Trough onset after the Trough onset
            T = D.Table.Data;
            T.Then(2) = "not followed by";
            T.Within(2) = 0.5;
            D.Table.Data = T;
            D.Align.Value = 1;   % align to step 1; step 2 is a condition
            D.Apply.ButtonPushedFcn(D.Apply, []);
            tc.verifyFalse(isvalid(D.Apply), 'Apply closes the window.');
            seq = B.Settings.ref.sequence;
            tc.verifyEqual({seq.line}, {"Trough", "Trough"});
            tc.verifyEqual({seq.relation}, {"followedBy", "notFollowedBy"});
            tc.verifyEqual(seq(2).maxGapSec, 0.5);
            tc.verifyEqual(B.Settings.ref.alignStep, 1);
            kept = B.Settings;
            A.SeqEdit.ButtonPushedFcn(A.SeqEdit, []);
            B.Settings = kept;   % settings from elsewhere close the window
            tc.verifyTrue(isempty(B.SequenceDialog));
            % the Data drop-down: only its block is on
            c.Data.Value = 'LFP';
            c.Data.ValueChangedFcn(c.Data, []);
            tc.verifyEqual(B.Settings.data, "LFP");
            tc.verifyEqual([c.Channels.Enable c.Shanks.Enable c.Detrend.Enable c.Measure.Enable c.Merge.Enable c.Magnitude.Enable], ...
                matlab.lang.OnOffSwitchState([1 1 1 0 0 0]));
            B.formEdit("Data", "AUX");
            tc.verifyEqual([c.Magnitude.Enable c.Shanks.Enable c.Channels.Enable], matlab.lang.OnOffSwitchState([1 0 1]));
            B.formEdit("Data", "units");
            tc.verifyEqual([c.Measure.Enable c.Merge.Enable c.Detrend.Enable c.Baseline.Enable c.Shanks.Enable], ...
                matlab.lang.OnOffSwitchState([1 0 0 0 1]));
            B.formEdit("Measure", "auroc");
            tc.verifyEqual([c.Baseline.Enable c.Normalize.Enable c.NormBaseline.Enable c.NormScope.Enable], ...
                matlab.lang.OnOffSwitchState([1 0 0 0]), 'auROC is not normalized.');
            B.formEdit("Measure", "rate");
            B.formEdit("Normalize", "minmax");
            tc.verifyEqual([c.Normalize.Enable c.NormBaseline.Enable c.NormScope.Enable], matlab.lang.OnOffSwitchState([1 0 1]));
            B.formEdit("Normalize", "none");
            tc.verifyEqual([c.NormBaseline.Enable c.NormScope.Enable], matlab.lang.OnOffSwitchState([0 0]));
            B.formEdit("Normalize", "zscore");
            B.formEdit("Measure", "auroc");
            B.formEdit("Data", "detected");
            tc.verifyEqual(c.Merge.Enable, matlab.lang.OnOffSwitchState(true));
            % an invalid edit is undone and said
            before = B.Settings;
            B.formEdit("Shanks", "1:x");
            tc.verifyEqual(B.Settings, before);
            tc.verifyEqual(string(c.Shanks.Value), "");
            tc.verifyTrue(startsWith(string(c.Status.Text), "Not applied"), c.Status.Text);
            B.formEdit("Bin", 5);   % no whole bin fits [-1 1] s
            tc.verifyEqual(B.Settings, before);
            tc.verifyEqual(c.Bin.Value, 0.01);
            tc.verifyTrue(contains(string(c.Status.Text), "bin"), c.Status.Text);
            tc.verifyError(@() setSettings(B, struct('nope', 1)), 'epochMatrixSettings:UnknownField');
            tc.verifyEqual(B.Settings, before);
            % settings files
            tmp = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            f = fullfile(tmp.Folder, "s.json");
            B.saveSettings(f);
            B.Settings = [];
            tc.verifyEqual(B.Settings.data, "units");
            B.loadSettings(f);
            tc.verifyEqual(B.Settings, before);
            tc.verifyError(@() B.loadSettings(), 'DatasetBrowser:NoFile', 'Hidden: no file dialog.');
        end

        function fileMenuAndRecent(tc)
            B = tc.open(Scan=false);
            tmp = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            f1 = string(fullfile(tmp.Folder, "a.json"));
            f2 = string(fullfile(tmp.Folder, "b.json"));
            tc.verifyEqual(B.SettingsFile, "");
            tc.verifyError(@() B.saveSettings(), 'DatasetBrowser:NoFile', 'No settings file and hidden: no Save as dialog.');
            B.saveSettings(f1);
            tc.verifyEqual(B.SettingsFile, f1);
            B.Settings = epochMatrixSettings(B.Settings, binSec=0.02);
            B.saveSettings();   % to SettingsFile
            tc.verifyEqual(epochMatrixSettings(f1).binSec, 0.02, 'Save writes the settings file.');
            B.saveSettings(f2);
            B.loadSettings(f1);
            tc.verifyEqual(B.RecentSettings, [f1; f2], 'Newest first, no duplicates.');
            tc.verifyTrue(contains(string(B.Ctl.SettingsFile.Text), "a.json"), B.Ctl.SettingsFile.Text);
            items = string({B.Ctl.RecentMenu.Children.Text});   % Children are newest-created first
            tc.verifyTrue(all(ismember([f1 f2 "Remove from list" "Clear list"], items)), strjoin(items, ", "));
            % a recent item loads its file; Remove from list drops it
            B.Settings = [];
            item = findobj(B.Ctl.RecentMenu.Children, "flat", "Text", char(f2));
            item.MenuSelectedFcn(item, []);
            tc.verifyEqual(B.Settings.binSec, 0.02);
            tc.verifyEqual(B.RecentSettings(1), f2);
            rm = findobj(B.Ctl.RecentMenu.Children, "flat", "Text", "Remove from list");
            item = findobj(rm.Children, "flat", "Text", char(f1));
            item.MenuSelectedFcn(item, []);
            tc.verifyEqual(B.RecentSettings, f2);
            tc.verifyTrue(isfile(f1), 'Removing keeps the file.');
            % a missing file stays listed, grayed, until removed
            delete(f2);
            B.removeRecent("nothing.json");
            item = findobj(B.Ctl.RecentMenu.Children, "flat", "-regexp", "Text", "not found");
            tc.verifyEqual(string(item.Enable), "off");
            B.close();
            tc.verifyEqual(string(AppPrefs.getpref("DatasetBrowser", "RecentSettings")), f2, 'The list is a preference.');
            B2 = tc.open(Scan=false);
            tc.verifyEqual(B2.RecentSettings, f2);
            B2.clearRecent();
            tc.verifyEmpty(B2.RecentSettings);
            tc.verifyEqual(string(B2.Ctl.RecentMenu.Children.Text), "(none)");
            B2.close();
        end

        function eventTrialDefinitions(tc)
            B = tc.open(Settings=tc.Spike, Scan=false);
            c = B.Ctl;
            on = @(tf) matlab.lang.OnOffSwitchState(tf);
            pick = @(name, edited) c.DefList.ValueChangedFcn(c.DefList, struct('Value', char(name), 'Edited', edited));
            tc.verifyEmpty(B.Definitions);
            tc.verifyEqual(c.DefRemove.Enable, on(false));
            % + with the box blank: the event and trials part of ResultName, numbered when taken
            B.addDefinition();
            tc.verifyEqual([B.Definitions.name], "StimOnset_AllTrials");
            tc.verifyEqual(string(c.DefList.Value), "StimOnset_AllTrials");
            tc.verifyEqual(c.DefRemove.Enable, on(true));
            hit = epochMatrixSettings(tc.Spike, ref=eventRef(line="Stim", edge="offset"), window=epochWindow(pre=-0.5, post=1), ...
                selection=trialSelection(response="Hit"));
            B.Settings = hit;
            tc.verifyEqual(string(c.DefNote.Text), "changed", 'The settings differ from the definition shown.');
            % + after a change adds beside the one shown, not over it; every + adds one, numbered when taken
            c.DefAdd.ButtonPushedFcn(c.DefAdd, []);
            tc.verifyEqual([B.Definitions.name], ["StimOnset_AllTrials" "StimOffset_Hit"]);
            tc.verifyEqual(B.Definitions(1).ref, tc.Spike.ref, 'The first definition is not overwritten.');
            c.DefAdd.ButtonPushedFcn(c.DefAdd, []);
            tc.verifyEqual([B.Definitions.name], ["StimOnset_AllTrials" "StimOffset_Hit" "StimOffset_Hit_1"], 'Numbered when taken.');
            tc.verifyEqual(string(c.DefList.Value), "StimOffset_Hit_1", 'The new one is shown.');
            B.removeDefinition("StimOffset_Hit_1");
            tc.verifyEqual([B.Definitions.name], ["StimOnset_AllTrials" "StimOffset_Hit"]);
            B.Settings = hit;
            % a pick puts its event, window and trials in the settings; the rest stays
            B.Settings = epochMatrixSettings(B.Settings, binSec=0.02);
            pick("StimOnset_AllTrials", false);
            tc.verifyEqual(B.Settings.ref, tc.Spike.ref);
            tc.verifyEqual(B.Settings.window, tc.Spike.window);
            tc.verifyEqual(B.Settings.selection, tc.Spike.selection);
            tc.verifyEqual(B.Settings.binSec, 0.02);
            tc.verifyEqual(string(c.DefNote.Text), "");
            % a typed name applies nothing and names the next +; + replaces a definition of that name
            pick("mine", true);
            tc.verifyEqual(B.Settings.ref, tc.Spike.ref, 'Typing applies nothing.');
            c.DefAdd.ButtonPushedFcn(c.DefAdd, []);
            tc.verifyEqual([B.Definitions.name], ["StimOnset_AllTrials" "StimOffset_Hit" "mine"]);
            B.Settings = epochMatrixSettings(B.Settings, window=epochWindow(pre=-0.3, post=0.3));
            tc.verifyEqual([string(c.DefList.Value) string(c.DefNote.Text)], ["mine" "changed"]);
            pick("mine", true);   % the shown name typed: + replaces it
            c.DefAdd.ButtonPushedFcn(c.DefAdd, []);
            tc.verifyEqual(numel(B.Definitions), 3, 'Replaced, not added.');
            tc.verifyEqual(B.Definitions(3).window.pre, -0.3);
            tc.verifyEqual(string(c.DefNote.Text), "");
            % the drop-down follows the settings to the definition they match
            B.Settings = epochMatrixSettings(hit, binSec=0.02);
            tc.verifyEqual(string(c.DefList.Value), "StimOffset_Hit");
            % a definition the other settings reject is not applied
            B.Settings = epochMatrixSettings(B.Settings, window=epochWindow(pre=0.1, post=0.5));
            B.addDefinition("late");
            B.Settings = epochMatrixSettings(hit, normalize=struct('method', "zscore", 'baseline', [-0.5 0]));
            before = B.Settings;
            pick("late", false);
            tc.verifyEqual(B.Settings, before);
            tc.verifyTrue(startsWith(string(c.Status.Text), "Not applied"), c.Status.Text);
            tc.verifyError(@() B.useDefinition("nope"), 'DatasetBrowser:NoDefinition');
            tc.verifyError(@() B.removeDefinition("nope"), 'DatasetBrowser:NoDefinition');
            % saved in the settings file beside the settings; Load settings brings them back
            tmp = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            f = string(fullfile(tmp.Folder, "defs.json"));
            defs = B.Definitions;
            B.saveSettings(f);
            tc.verifyTrue(isfield(readJsonFile(f), 'definitions'));
            tc.verifyEqual(epochMatrixSettings(f), B.Settings, 'epochMatrixSettings reads the settings, the definitions left alone.');
            B.removeDefinition("mine");
            B.loadSettings(f);
            tc.verifyEqual(B.Definitions, defs);
            tc.verifyEqual(string(c.DefList.Items), [defs.name]);
            B3 = tc.open(Settings=f, Scan=false);
            tc.verifyEqual(B3.Definitions, defs, 'The Settings= file''s definitions.');
            % a file without definitions: none
            f2 = string(fullfile(tmp.Folder, "plain.json"));
            epochMatrixSettings(B.Settings, SaveAs=f2);
            B.loadSettings(f2);
            tc.verifyEmpty(B.Definitions);
            tc.verifyEmpty(c.DefList.Items);
            % one that does not check is left out with a warning
            f3 = string(fullfile(tmp.Folder, "bad.json"));
            good = struct('name', "ok", 'ref', tc.Spike.ref, 'window', tc.Spike.window, 'selection', tc.Spike.selection);
            bad = struct('name', "bad", 'ref', tc.Spike.ref, 'window', setfield(tc.Spike.window, 'mode', "between"),'selection', tc.Spike.selection);
            writeJsonFile(f3, struct('schema', "epoch-matrix-settings", 'version', 1, 'settings', tc.Spike, ...
                'definitions', {{good, bad, good}}), NonFinite="string");
            tc.verifyWarning(@() B.loadSettings(f3), 'DatasetBrowser:BadDefinition');
            tc.verifyEqual([B.Definitions.name], "ok", 'A window that is not fixed, and a name taken, are left out.');
            % the result file keeps them
            B.loadSettings(f);
            B.save();
            B2 = tc.open(ResultFile=B.ResultFile, Scan=false);
            tc.verifyEqual(B2.Definitions, defs);
        end

        function dropDownLoadsOneSource(tc)
            B = tc.open();
            c = B.Ctl;
            tc.verifyEqual(B.Runner.Sources.Count, uint64(0));
            c.Align.Line.DropDownOpeningFcn(c.Align.Line, []);
            tc.verifyEqual(B.Runner.Sources.Count, uint64(1), 'Opening a list loads one source.');
            tc.verifyTrue(isKey(B.Runner.Sources, char(B.Selected(1))), 'The first ticked dataset''s.');
            A = c.Align;
            tc.verifyTrue(all(ismember({'Trial', 'Stim'}, cellstr(A.Line.Items))));
            tc.verifyTrue(all(ismember({'(none)', 'Depth'}, cellstr(A.Group1.Items))));
            tc.verifyTrue(ismember('Depth', cellstr(A.ShiftParam.Items)));
            % a clicked row's dataset is the one listed
            T = c.Table.Data;
            r = find(T.Key == tc.Keys(2));
            c.Table.CellSelectionCallback(c.Table, struct('Indices', [r 2]));
            A.Group1.DropDownOpeningFcn(A.Group1, []);
            tc.verifyTrue(isKey(B.Runner.Sources, char(tc.Keys(2))));
            tc.verifyEqual(B.Runner.Sources.Count, uint64(2));
            % the Epoch Diagram shows that dataset, follows the settings and closes with the browser
            A.Diagram.ButtonPushedFcn(A.Diagram, []);
            d = B.EpochWindow;
            tc.verifyTrue(~isempty(d) && d.isOpen(), 'Epoch Diagram opens the window.');
            tc.verifyEqual(string(d.Fig.Name), "How the epochs are cut");
            B.formEdit("Pre", -0.5);
            tc.verifyTrue(d.isOpen());
            delete(B);
            tc.verifyFalse(isvalid(d) && d.isOpen(), 'It closes with the browser.');
        end

        function channelsTabYoked(tc)
            B = tc.open();
            c = B.Ctl;
            B.Settings = tc.Spike;
            tc.verifyEqual(B.Runner.Sources.Count, uint64(0));
            B.showProbe();
            tc.verifyEqual(c.SettingsTabs.SelectedTab, c.ProbeTab);
            tc.verifyEqual(B.Runner.Sources.Count, uint64(1), 'Showing the tab reads one source, for its probe.');
            tc.verifyNotEmpty(c.ProbeNote.Text);
            % two shanks of 4 sites (recording channels 1-8, chanMap 0-based), drawn in the picker
            probe = struct('chanMap', 0:7, 'xc', [0 0 20 20 200 200 220 220], 'yc', [0 40 20 60 0 40 20 60], ...
                'kcoords', [1 1 1 1 2 2 2 2]);
            c.Probe.setProbe(probe);
            P = c.Probe;
            keptCh = @() reshape(P.Sites.channel(P.kept()), 1, []);
            tc.verifyEqual(height(P.Sites), 8);
            tc.verifyEqual(keptCh(), 1:8, 'Both fields blank: every site.');
            % a site click starts the channel list, a second adds to it; the field and the settings follow
            B.pickProbe("site", 3);
            tc.verifyEqual(B.Settings.units.channels, 3);
            tc.verifyEqual(string(c.Channels.Value), "3");
            B.pickProbe("site", 6);
            tc.verifyEqual(B.Settings.units.channels, [3 6]);
            tc.verifyEqual(keptCh(), [3 6]);
            % a shank click: only the sites on both lists are kept
            B.pickProbe("shank", 2);
            tc.verifyEqual(B.Settings.units.shanks, 2);
            tc.verifyEqual(string(c.Shanks.Value), "2");
            tc.verifyEqual(keptCh(), 6);
            % a field typed: the probe follows
            B.formEdit("Channels", "1:4 7");
            tc.verifyEqual(P.Channels, [1 2 3 4 7]);
            tc.verifyEqual(keptCh(), 7);
            B.formEdit("Shanks", "");
            tc.verifyEmpty(P.Shanks);
            tc.verifyEqual(keptCh(), [1 2 3 4 7]);
            % dropping the last channel leaves the field blank: all again
            B.formEdit("Channels", "5");
            B.pickProbe("site", 5);
            tc.verifyEmpty(B.Settings.units.channels);
            tc.verifyEqual(string(c.Channels.Value), "");
            tc.verifyEqual(keptCh(), 1:8);
            % each kind of data keeps its own picks: a signal's go into signal
            B.pickProbe("site", 2);
            B.formEdit("Data", "LFP");
            tc.verifyEqual(string(c.Channels.Value), "", 'LFP shows its own channels (none picked).');
            tc.verifyEqual(keptCh(), 1:8);
            B.pickProbe("site", 8);
            tc.verifyEqual(B.Settings.signal.channels, 8);
            tc.verifyEqual(B.Settings.units.channels, 2, 'The units'' pick stays.');
            % All: both fields blank
            B.formEdit("Shanks", "1");
            c.ProbeAll.ButtonPushedFcn(c.ProbeAll, []);
            tc.verifyEmpty(B.Settings.signal.channels);
            tc.verifyEmpty(B.Settings.signal.shanks);
            tc.verifyEqual([string(c.Channels.Value) string(c.Shanks.Value)], ["" ""]);
            % AUX has no probe: the picker is off and cleared, Channels are its columns
            B.formEdit("Data", "AUX");
            tc.verifyEqual([c.Shanks.Enable P.Enable c.Channels.Enable], matlab.lang.OnOffSwitchState([0 0 1]));
            tc.verifyEqual(height(P.Sites), 0);
            tc.verifyTrue(startsWith(string(c.ProbeNote.Text), "AUX"));
            B.pickProbe("site", 1);
            tc.verifyEmpty(B.Settings.signal.channels, 'A click does nothing with the probe off.');
            % the picker on its own: the toggle rule
            tc.verifyEqual(ProbePicker.toggle([], 4), 4);
            tc.verifyEqual(ProbePicker.toggle([2 4], 3), [2 3 4]);
            tc.verifyEmpty(ProbePicker.toggle(4, 4));
        end

        function computeEqualsEpochMatrix(tc)
            B = tc.open(Settings=tc.Spike);
            tc.verifyTrue(isnat(B.Computed), 'No compute yet.');
            before = datetime('now');
            R = B.compute();
            tc.verifyClass(B.Computed, 'datetime');
            tc.verifyEqual(B.Computed, R.created);
            tc.verifyTrue(B.Computed >= before && B.Computed <= datetime('now'), 'Stamped by the compute.');
            R0 = epochMatrix(B.Runner, tc.Spike, Datasets=B.Selected, LogFcn=[]);
            tc.verifyEqual(R.data, R0.data);
            tc.verifyEqual(R.rows, R0.rows);
            tc.verifyEqual(R.t, R0.t);
            tc.verifyEqual(R.groupLabels, R0.groupLabels);
            tc.verifyEqual(R.keys, R0.keys);
            tc.verifyEqual(B.Result, R);
            tc.verifyTrue(B.ResultCurrent);
            tc.verifyTrue(all(startsWith(B.Table.Cached, "✓")), 'The Cached column.');
            tc.verifyTrue(contains(B.Ctl.Summary.Text, sprintf("%d units × %d bins × %d groups from 2 of 2 datasets; 2 computed, 0 reused", ...
                height(R.rows), numel(R.t), numel(R.groupLabels))), B.Ctl.Summary.Text);
            % a dataset ticked later is the only one computed
            D = B.Datasets.key;   % the order the datasets are computed in
            B.Selected = D(1);
            tc.verifyFalse(B.ResultCurrent);
            tc.verifyTrue(startsWith(B.Ctl.Summary.Text, "Out of date: ticks changed"), B.Ctl.Summary.Text);
            B.forget();
            B.compute();
            tc.verifyEqual(B.Runs.Last.status, "done");
            B.tick(D(2));
            B.compute();
            tc.verifyEqual(B.Runs.Last.status, ["cached"; "done"]);
            tc.verifyTrue(contains(B.Ctl.Summary.Text, "1 computed, 1 reused"), B.Ctl.Summary.Text);
            % a settings change computes all again; a signal option does not
            B.Settings = epochMatrixSettings(B.Settings, signal=struct('detrend', true));
            tc.verifyTrue(B.ResultCurrent, 'A signal option leaves a spike result current.');
            B.Settings = epochMatrixSettings(B.Settings, binSec=0.02);
            tc.verifyTrue(startsWith(B.Ctl.Summary.Text, "Out of date: settings changed"), B.Ctl.Summary.Text);
            tc.verifyTrue(all(B.Table.Cached == "old"));
            tc.verifyEqual(rowTints(B.Ctl.Table), {[0.98 0.96 0.86], [1 2]}, 'Old rows are tinted yellow.');
            B.compute();
            tc.verifyEqual(rowTints(B.Ctl.Table), {[0.90 0.96 0.90], [1 2]}, 'Cached rows are tinted green.');
            tc.verifyEqual(B.Runs.Last.status, ["done"; "done"]);
            tc.verifyTrue(isfile(B.ResultFile), 'The result file is written after a compute.');
            B.untickAll();
            tc.verifyError(@() B.compute(), 'DatasetBrowser:NoneTicked');
        end

        function loadSessionsOnTheirOwnClock(tc)
            B = tc.open(Settings=tc.Spike);
            tc.verifyEmpty(B.Sessions);
            [D, T] = B.loadSessions();
            tc.verifyEqual(T.status, ["done"; "done"]);
            tc.verifyEqual(B.Sessions, D);
            tc.verifyEqual([D.key].', B.Selected);
            tc.verifyEmpty(B.Runs.Entries, 'Nothing is cached.');
            tc.verifyEmpty(B.Result, 'Nothing is computed.');
            S = B.Settings;
            for k = 1:numel(D)
                src = B.source(D(k).key);
                [st, u] = selectUnits(src, S.units, Ref=S.ref, Selection=S.selection);
                tc.verifyEqual(D(k).spikes, st, 'The units Compute uses, whole.');
                tc.verifyEqual(D(k).units, u);
                tc.verifyEmpty(D(k).signal);
                tc.verifyEqual(D(k).events, src.events);
                tc.verifyEqual(D(k).trials, src.trials, 'Every trial.');
                [mask, G] = selectTrials(src, S.selection);
                tc.verifyEqual(D(k).kept, mask);
                tc.verifyEqual(D(k).groups, G);
                % the events on the spikes' clock, bit for bit as epochTable puts them
                E = epochTable(src, S.ref, Window=S.window, Selection=S.selection);
                tc.verifyTrue(all(ismember(E.t0Continuous, D(k).eventsContinuous.Stim(:, 1))));
                tc.verifyEqual(D(k).eventsContinuous.Stim, D(k).toContinuous(src.events.Stim));
            end
            % a signal: whole, the channels kept
            B.Settings = epochMatrixSettings(B.Settings, data="AUX", signal=struct('channels', 1));
            B.Ctl.LoadSessions.ButtonPushedFcn(B.Ctl.LoadSessions, []);
            D = B.Sessions;
            tc.verifyNumElements(D, 2);
            src = B.source(D(1).key);
            [Y, fs] = selectChannels(src, "AUX", Channels=1);
            tc.verifyEqual(D(1).signal, Y);
            tc.verifyEqual(D(1).signalFs, fs);
            tc.verifyEqual(height(D(1).channels), 1);
            tc.verifyEmpty(D(1).spikes);
            tc.verifyTrue(contains(B.Ctl.ProgMsg.Text, "2 session(s) loaded"), B.Ctl.ProgMsg.Text);
            % trials only: no spikes, no signal, the trials and lines as above
            B.Ctl.LoadTrials.ButtonPushedFcn(B.Ctl.LoadTrials, []);
            D = B.Sessions;
            tc.verifyNumElements(D, 2);
            tc.verifyEqual([D.data], ["trials" "trials"]);
            tc.verifyEmpty(D(1).spikes);
            tc.verifyEmpty(D(1).signal);
            tc.verifyEmpty(D(1).channels);
            src = B.source(D(1).key);
            tc.verifyEqual(D(1).trials, src.trials);
            tc.verifyEqual(D(1).events, src.events);
            tc.verifyEqual(D(1).kept, selectTrials(src, B.Settings.selection));
            tc.verifyTrue(contains(B.Ctl.ProgMsg.Text, "2 session(s) loaded in B.Sessions (trials)"), B.Ctl.ProgMsg.Text);
            B.untickAll();
            tc.verifyError(@() B.loadSessions(), 'DatasetBrowser:NoneTicked');
        end

        function exportedScriptEqualsCompute(tc)
            % trials kept and grouped, units' shanks, a normalization: all written out
            S = epochMatrixSettings(tc.Spike, measure="count", ...
                selection=trialSelection(response=["Hit" "Miss"], groupBy="Depth", groupOrder="descending"), ...
                units=struct('shanks', 0), normalize=struct('method', "zscore"));
            B = tc.open(Settings=S);
            B.setFilter(Tags="ofc");
            B.Selected = B.Datasets.key(2);
            R = B.compute();
            tmp = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            file = fullfile(tmp.Folder, "compute_export.m");
            txt = B.exportScript(file);
            tc.verifyTrue(isfile(file));
            tc.verifyEqual(string(fileread(file)), txt);
            tc.verifyFalse(contains(txt, "DatasetBrowser("), 'No browser in the script.');
            tc.verifyTrue(contains(txt, "% (The browser's filter: Tags=""ofc"", TagMode=""any"".)"), txt);
            tc.verifyTrue(contains(txt, """" + B.Datasets.key(2) + """") && ~contains(txt, """" + B.Datasets.key(1) + """"), ...
                'Only the ticked dataset.');
            tc.verifyFalse(contains(txt, "signal="), 'Fields that do not apply to the data are left out.');
            tc.verifyFalse(contains(txt, "binSec="), 'Defaults are left out.');
            R1 = runScript(file);
            tc.verifyEqual(R1.data, R.data);
            tc.verifyEqual(R1.rows, R.rows);
            tc.verifyEqual(R1.t, R.t);
            tc.verifyEqual(R1.groupLabels, R.groupLabels);
            tc.verifyEqual(DatasetRuns.idText(R1.settings), DatasetRuns.idText(R.settings));
            % the defaults: one line of settings
            B.Settings = epochMatrixSettings();
            tc.verifyTrue(contains(B.exportScript(""), "S = epochMatrixSettings();"));
            B.untickAll();
            tc.verifyError(@() B.exportScript(""), 'DatasetBrowser:NoneTicked');
        end

        function normalizeAppliesWithoutCompute(tc)
            B = tc.open(Settings=tc.Spike);
            R = B.compute();
            tc.verifyEqual(R.normalization.method, "none");
            B.formEdit("Normalize", "zscore");
            tc.verifyTrue(B.ResultCurrent, 'Normalized again in place: still current.');
            Rz = B.Result;
            tc.verifyEqual(Rz.created, R.created, 'Nothing was assembled again.');
            tc.verifyEqual(Rz.data, epochMatrixNormalize(R, struct('method', "zscore")).data);
            tc.verifyEqual(Rz.raw, R.data);
            tc.verifyEqual(Rz.valueUnits, "z");
            tc.verifyTrue(contains(B.Ctl.Summary.Text, "z-scored against the baseline -0.5 to 0 s"), B.Ctl.Summary.Text);
            B.formEdit("NormScope", "group");
            B.formEdit("NormBaseline", "-0.2 0");
            tc.verifyEqual(B.Result.normalization.scope, "group");
            tc.verifyEqual(B.Result.normalization.baseline, [-0.2 0]);
            tc.verifyEqual(B.Settings.normalize.baseline, [-0.2 0]);
            % a compute gives the same, from the kept parts
            Rg = B.Result;
            R2 = B.compute();
            tc.verifyEqual(B.Runs.Last.status, ["cached"; "cached"]);
            tc.verifyEqual(R2.data, Rg.data);
            % "none": the values as computed
            B.formEdit("Normalize", "none");
            tc.verifyEqual(B.Result.data, R.data);
            tc.verifyEmpty(B.Result.raw);
            % another setting changed too: out of date, not normalized in place
            B.Settings = epochMatrixSettings(B.Settings, binSec=0.02, normalize=struct('method', "subtract"));
            tc.verifyFalse(B.ResultCurrent);
            tc.verifyEqual(B.Result.normalization.method, "none");
        end

        function resultNameFromTagsEventTrialsMeasure(tc)
            B = tc.open(Settings=tc.Spike);
            tc.verifyEqual(B.ResultName, "", 'No name before a compute.');
            mc = ?DatasetBrowser;
            mp = findobj(mc.PropertyList, 'Name', 'ResultName');
            tc.verifyEqual(mp.SetAccess, 'private', 'ResultName is read-only.');
            R = B.compute();
            tc.verifyEqual(R.labels.aligned, "Stim onset");
            tc.verifyEqual(B.ResultName, "ofc_StimOnset_AllTrials_FiringRate", ...
                'No filter tags: the tags every dataset holds.');
            tc.verifyEqual(R.name, B.ResultName);
            B.setFilter(Tags="pilot, ofc", TagMode="all");
            B.Settings = epochMatrixSettings(B.Settings, measure="count", ...
                selection=trialSelection(response=["Hit" "Miss"], groupBy="Depth", groupOrder="descending"));
            B.tickShown();
            B.compute();
            tc.verifyEqual(B.ResultName, "ofc_pilot_StimOnset_HitOrMiss_SpikeCount");
            B.setFilter(TagMode="any");
            tc.verifyEqual(B.ResultName, "ofc_pilot_StimOnset_HitOrMiss_SpikeCount", 'A filter edit keeps the computed name.');
            B.compute();
            tc.verifyEqual(B.ResultName, "ofc_or_pilot_StimOnset_HitOrMiss_SpikeCount");
        end

        function resultFileRestores(tc)
            tmp = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            f = string(fullfile(tmp.Folder, "keep.mat"));
            B = tc.open(Settings=tc.Spike, ResultFile=f);
            B.setFilter(Tags="ofc");
            B.Selected = tc.Keys(2);
            R = B.compute();
            B.close();
            raw = load(f);
            tc.verifyEqual(sort(string(fieldnames(raw))).', ["browser" "result" "runs" "schema" "version"]);
            tc.verifyEqual(raw.schema, "dataset-browser-results");
            % Scan=false: the result, without touching the root
            B2 = tc.open(ResultFile=f, Scan=false);
            tc.verifyEmpty(B2.Runner);
            tc.verifyEqual(B2.Result.data, R.data);
            tc.verifyEqual(B2.Result.rows, R.rows);
            tc.verifyEqual(B2.Result.labels, R.labels);
            tc.verifyEqual(B2.ResultName, R.name, 'The name is kept in the result file.');
            tc.verifyEqual(B2.Selected, tc.Keys(2));
            tc.verifyEqual(B2.Settings, B.Settings);
            tc.verifyEqual(B2.Filter.Tags, "ofc");
            tc.verifyError(@() B2.compute(), 'DatasetBrowser:NotScanned');
            % a scan restores the ticks and the cache, and computes nothing
            B3 = tc.open(ResultFile=f);
            tc.verifyEqual(B3.Runner.Sources.Count, uint64(0));
            tc.verifyEqual(B3.Selected, tc.Keys(2));
            tc.verifyTrue(B3.ResultCurrent);
            T = B3.Table;
            tc.verifyTrue(startsWith(T.Cached(T.Key == tc.Keys(2)), "✓"));
            B3.compute();
            tc.verifyEqual(B3.Runs.Last.status, "cached");
            % options override the file
            B4 = tc.open(ResultFile=f, Scan=false, Settings=epochMatrixSettings(tc.Spike, binSec=0.02));
            tc.verifyEqual(B4.Settings.binSec, 0.02);
            tc.verifyFalse(B4.ResultCurrent);
            % a file that is not one: a warning, the defaults
            bad = string(fullfile(tmp.Folder, "bad.mat"));
            schema = "something-else";
            save(bad, 'schema');
            B5 = tc.verifyWarning(@() DatasetBrowser(tc.Root, ResultFile=bad, Visible=false, Scan=false), ...
                'DatasetBrowser:BadResultFile');
            tc.addTeardown(@() delete(B5));
            tc.verifyEmpty(B5.Result);
            % the default file is beside the root
            B6 = DatasetBrowser(tc.Root, Visible=false, Scan=false);
            tc.addTeardown(@() delete(B6));
            tc.verifyEqual(B6.ResultFile, string(fullfile(tc.Root, "DatasetBrowser_results.mat")));
        end

        function keepEpochsRoundTrip(tc)
            tmp = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            f = string(fullfile(tmp.Folder, "epochs.mat"));
            B = tc.open(Settings=tc.Spike, ResultFile=f);
            R0 = B.compute();
            tc.verifyEmpty(R0.epochs);
            B.formEdit("KeepEpochs", true);
            tc.verifyFalse(B.ResultCurrent, 'A result without epochs is out of date.');
            tc.verifyTrue(all(B.Table.Cached == ""), 'The parts with epochs are kept apart: none yet.');
            R = B.compute();
            tc.verifyEqual(B.Runs.Last.status, ["done"; "done"]);
            tc.verifyEqual(R.data, R0.data);
            tc.verifyEqual(numel(R.epochs), numel(R.keys));
            tc.verifyTrue(contains(B.Ctl.Summary.Text, "epochs kept (R.epochs)"), B.Ctl.Summary.Text);
            % off again: the parts without epochs are still kept
            B.formEdit("KeepEpochs", false);
            tc.verifyTrue(all(startsWith(B.Table.Cached, "✓")));
            B.formEdit("KeepEpochs", true);
            B.close();
            % the result file leaves the epochs to the kept parts; a restore assembles them again
            raw = load(f);
            tc.verifyEmpty(raw.result.epochs);
            B2 = tc.open(ResultFile=f, Scan=false);
            tc.verifyEqual(B2.Result.epochs, R.epochs);
            tc.verifyTrue(B2.ResultCurrent);
            % without its parts the result comes back without epochs, and says so
            B3 = tc.open(ResultFile=f, Scan=false);
            B3.forget();
            B3.save();
            B4 = tc.verifyWarning(@() tc.open(ResultFile=f, Scan=false), 'DatasetBrowser:BadResultFile');
            tc.verifyEmpty(B4.Result.epochs);
            tc.verifyEqual(B4.Result.data, R.data);
        end

        function trialRasters(tc)
            S = epochMatrixSettings(tc.Spike, measure="count", keepEpochs=true);
            B = tc.open(Settings=S);
            tc.verifyError(@() B.showRasters(), 'DatasetBrowser:NoResult');
            tc.verifyError(@() B.raster(1), 'DatasetBrowser:NoResult');
            R = B.compute();
            % every row's raster: the spikes of its epochs, in group order; the counts average to R.data (measure count)
            for row = 1:height(R.rows)
                X = B.raster(row);
                k = find(R.keys == R.rows.Dataset(row));
                e = R.epochs(k);
                i = find(e.rows == row);
                tc.verifyEqual([X.row X.key X.label], [row R.keys(k) string(R.rows.label(row))]);
                tc.verifyEqual(sort(X.E.epochRow), (1:height(e.E)).');
                tc.verifyTrue(issorted(X.E.resultGroup), 'By group: the groups in order.');
                tc.verifyEqual(X.nPerGroup, arrayfun(@(g) nnz(e.E.resultGroup == g), (1:numel(R.groupLabels)).'));
                tc.verifyEqual(X.times, double(e.spikes(i).times(:)));
                tc.verifyEqual(X.E.epochRow(X.trial), double(e.spikes(i).epoch(:)), 'Each spike on its own epoch''s line.');
                tc.verifySize(X.counts, [height(X.E) numel(R.t)]);
                for g = 1:numel(R.groupLabels)
                    in = X.E.resultGroup == g;
                    if ~any(in); continue; end
                    tc.verifyEqual(mean(X.counts(in, :), 1), R.data(row, :, g), 'AbsTol', 1e-9);
                end
                tc.verifyEmpty(X.data);
            end
            Xt = B.raster(1, Order="time");
            tc.verifyTrue(issorted(Xt.E.t0), 'By time: the epochs in time order.');
            tc.verifyEqual(sort(Xt.times), sort(B.raster(1).times));

            % the window: a row, the next one, the order; it follows the result
            B.showRasters(2);
            w = B.RasterWindow;
            tc.verifyTrue(~isempty(w) && w.isOpen(), 'Trial rasters opens the window.');
            tc.verifyEqual(string(w.Fig.Name), "Trial rasters");
            tc.verifyEqual(w.Row, 2);
            tc.verifyEqual(w.Raster, B.raster(2));
            tc.verifyEqual(w.Message, "");
            w.step(1);
            tc.verifyEqual(w.Row, min(3, height(R.rows)));
            w.setOrder("time");
            tc.verifyEqual(w.Raster, B.raster(w.Row, Order="time"));
            w.setOrder("group");
            r0 = w.Row;
            B.formEdit("Normalize", "zscore");   % the result normalized again: redrawn, its row kept
            tc.verifyEqual(w.Row, r0);
            tc.verifyEqual(w.Result.normalization.method, "zscore");
            B.formEdit("Normalize", "none");

            % a signal: each epoch's trace, whose group mean is R.data
            setSettings(B, epochMatrixSettings(B.Settings, data="LFP"));
            R2 = B.compute();
            X = B.raster(1);
            tc.verifyEqual(X.rowKind, "channel");
            tc.verifySize(X.data, [height(X.E) numel(R2.t)]);
            tc.verifyEmpty(X.times);
            tc.verifyEmpty(X.counts);
            for g = 1:numel(R2.groupLabels)
                in = X.E.resultGroup == g;
                if ~any(in); continue; end
                m = R2.data(1, :, g);
                tc.verifyEqual(double(mean(X.data(in, :), 1)), m, 'AbsTol', 1e-4 * max(1, max(abs(m))));
            end
            tc.verifyEqual(w.Raster, B.raster(w.Row), 'The window follows the new result.');

            % a result without epochs: said in the window and by the methods
            B.formEdit("KeepEpochs", false);
            B.compute();
            tc.verifyEmpty(w.Raster);
            tc.verifyTrue(contains(w.Message, "keeps no epochs"), w.Message);
            tc.verifyError(@() B.showRasters(), 'epochMatrixRaster:NoEpochs');
            tc.verifyError(@() B.raster(1), 'epochMatrixRaster:NoEpochs');
            tc.verifyError(@() epochMatrixRaster(R, height(R.rows) + 1), 'epochMatrixRaster:BadRow');
            delete(B);
            tc.verifyFalse(isvalid(w) && w.isOpen(), 'It closes with the browser.');
        end

        function forEachCachesAndCancels(tc)
            B = tc.open(Workers=0);   % here: a pool left open by another suite would run FN on copies of B, which cannot cancel
            fn = @(src, info) string(info.name) + ":" + numel(fieldnames(src.events));
            [v, T] = B.forEach(fn, Name="probe");
            tc.verifyEqual(T.status, ["done"; "done"]);
            tc.verifyTrue(startsWith(v{1}, B.Datasets.name(B.Datasets.key == T.key(1)) + ":"), 'FN(src, info) gets the info row.');
            [v2, T2] = B.forEach(fn, Name="probe");
            tc.verifyEqual(T2.status, ["cached"; "cached"]);
            tc.verifyEqual(v2, v);
            [~, T3] = B.forEach(fn, Name="probe", Datasets=tc.Keys(2), Recompute=true);
            tc.verifyEqual(T3.status, "done");
            % a cancel keeps what finished
            stop = @(src) cancelFrom(B);
            tc.verifyError(@() B.forEach(stop, Name="stop"), 'DatasetRuns:NeedId', 'B is a handle: Id is needed.');
            tc.verifyError(@() B.forEach(stop, Name="stop", Id="stop-1"), 'DatasetRuns:Canceled');
            tc.verifyEqual(B.Runs.status("stop", B.Selected, "stop-1"), ["current"; ""]);
            tc.verifyFalse(B.Busy);
            tc.verifyTrue(isfile(B.ResultFile), 'A canceled forEach that added parts writes the file.');
        end

        function progressStrip(tc)
            B = tc.open();
            c = B.Ctl;
            B.progressStart("Histograms", Total=4);
            tc.verifyTrue(B.Busy);
            tc.verifyEqual(c.Cancel.Enable, matlab.lang.OnOffSwitchState(true));
            tc.verifyEqual(c.Compute.Enable, matlab.lang.OnOffSwitchState(false));
            tc.verifyEqual(c.Bar.ColumnWidth, {0, '1x'});
            B.progressStep(2, "Session 2");
            tc.verifyEqual(c.Bar.ColumnWidth, {'500x', '500x'});
            tc.verifyEqual(string(c.ProgMsg.Text), "2/4 Session 2");
            B.progress(0.25, "a quarter");
            tc.verifyEqual(c.Bar.ColumnWidth, {'250x', '750x'});
            tc.verifyTrue(contains(string(c.ProgTime.Text), "elapsed"), c.ProgTime.Text);
            c.Cancel.ButtonPushedFcn(c.Cancel, []);
            tc.verifyTrue(B.CancelRequested);
            tc.verifyError(@() B.checkCancel(), 'DatasetBrowser:Canceled');
            B.progressFinish("Histograms done");
            tc.verifyEqual(c.Bar.ColumnWidth, {'1x', 0});
            tc.verifyTrue(startsWith(string(c.ProgTime.Text), "done in"));
            tc.verifyFalse(B.Busy);
            tc.verifyEqual(c.Cancel.Enable, matlab.lang.OnOffSwitchState(false));
            tc.verifyEqual(c.Compute.Enable, matlab.lang.OnOffSwitchState(true));
            B.progressStart("Again");
            tc.verifyFalse(B.CancelRequested, 'progressStart clears a cancel.');
            B.progressStep(3, "no total");
            tc.verifyEqual(string(c.ProgMsg.Text), "3 no total");
            B.progressFinish("x");
            % hidden: at most a line every 2 s, and one at the finish
            B.progressStart("Loop", Total=50);
            txt = evalc('for i = 1:50, B.progressStep(i, "item"); end, B.progressFinish("Loop done");');
            lines = splitlines(strtrim(string(txt)));
            tc.verifyLessThanOrEqual(numel(lines), 3, txt);
            tc.verifyTrue(contains(lines(1), "Loop: 1/50 item"), txt);
            tc.verifyTrue(contains(lines(end), "Loop done") && contains(lines(end), "done in"), txt);
        end

        function computeOnTheStrip(tc)
            B = tc.open(Settings=tc.Spike, Workers=0);   % here, one dataset after the other, whatever pool another suite left open
            seen = containers.Map();
            B.ProgressHook = @(b, f, m) cancelAtSecond(b, f, seen);
            tc.verifyError(@() B.compute(), 'epochMatrix:Canceled');
            tc.verifyEqual(seen('busy'), [true true true true], 'Busy, Compute and the table off, Cancel on, while computing.');
            [~, ID] = epochMatrixSettings(tc.Spike);
            tc.verifyEqual(B.Runs.status("epochMatrix/units", B.Selected, ID), ["current"; ""], 'The finished part is kept.');
            tc.verifyFalse(B.Busy);
            c = B.Ctl;
            tc.verifyEqual([string(c.Compute.Enable) string(c.Table.Enable) string(c.Data.Enable) string(c.Cancel.Enable)], ["on" "on" "on" "off"]);
            tc.verifyEqual(c.Merge.Enable, matlab.lang.OnOffSwitchState(false), 'The blocks come back as Data says.');
            tc.verifyTrue(isfile(B.ResultFile));
            B.ProgressHook = [];
            B.compute();
            tc.verifyEqual(B.Runs.Last.status, ["cached"; "done"]);
            % the Compute button's error goes to the status line
            B.untickAll();
            c.Compute.ButtonPushedFcn(c.Compute, []);
            tc.verifyTrue(contains(string(c.Status.Text), "Tick at least one"), c.Status.Text);
        end

        function changedOutputsReadOld(tc)
            B = tc.open(Settings=tc.Spike);
            B.compute();
            k = tc.Keys(1);
            tc.verifyTrue(all(B.Datasets.stamp ~= ""), 'The scan keeps each dataset''s stamp.');
            f = string(B.Runner.Outputs(B.Runner.index(k)).ManifestFile);
            tc.assumeTrue(isfile(f), 'The fixture''s dataset has no manifest.');
            tc.verifyTrue(contains(B.Datasets.stamp(B.Datasets.key == k), "manifest "), 'The manifest is stamped.');
            jf = java.io.File(char(f));
            t0 = jf.lastModified();
            tc.addTeardown(@() java.io.File(char(f)).setLastModified(t0));   % the shared fixture as it was
            jf.setLastModified(t0 - 120 * 1000);
            T = B.Table;
            tc.verifyTrue(all(startsWith(T.Cached, "✓")), 'The stamps are the last scan''s.');
            B.scan();
            T = B.Table;
            tc.verifyEqual(T.Cached(T.Key == k), "old");
            tc.verifyTrue(all(startsWith(T.Cached(T.Key ~= k), "✓")), 'The other dataset is still cached.');
            B.compute();
            L = B.Runs.Last;
            tc.verifyEqual(L.status(L.key == k), "done");
            tc.verifyTrue(all(L.status(L.key ~= k) == "cached"));
            tc.verifyTrue(all(startsWith(B.Table.Cached, "✓")));
        end

        function forgetTickedNoneKeepsCache(tc)
            B = tc.open(Settings=tc.Spike);
            B.compute();
            n = numel(B.Runs.Entries);
            tc.verifyEqual(n, numel(tc.Keys));
            B.untickAll();
            B.forgetTicked();
            tc.verifyEqual(numel(B.Runs.Entries), n, 'Nothing ticked: nothing forgotten.');
            tc.verifyTrue(contains(string(B.Ctl.Status.Text), "Nothing is ticked"), B.Ctl.Status.Text);
            B.Selected = tc.Keys(1);
            B.forgetTicked();
            tc.verifyEqual(numel(B.Runs.Entries), n - 1);
            T = B.Table;
            tc.verifyEqual(T.Cached(T.Key == tc.Keys(1)), "");
        end

        function checkCancelEndsScriptRun(tc)
            B = tc.open();
            c = B.Ctl;
            B.progressStart("Loop", Total=4);
            B.progressStep(1, "one");
            c.Cancel.ButtonPushedFcn(c.Cancel, []);
            tc.verifyTrue(B.Busy, 'Cancel only asks; the loop stops at its check.');
            tc.verifyError(@() B.checkCancel(), 'DatasetBrowser:Canceled');
            tc.verifyFalse(B.Busy);
            tc.verifyEqual(string(c.ProgMsg.Text), "Canceled");
            tc.verifyEqual(c.Bar.ColumnWidth, {'250x', '750x'}, 'The bar is left as it was.');
            tc.verifyEqual([string(c.Compute.Enable) string(c.Table.Enable) string(c.Data.Enable) string(c.Cancel.Enable)], ...
                ["on" "on" "on" "off"]);
            tc.verifyError(@() B.checkCancel(), 'DatasetBrowser:Canceled', 'Later checks still stop the loop.');
            tc.verifyFalse(B.Busy);
        end

        function secondCancelEndsOpenScriptRun(tc)
            B = tc.open();
            c = B.Ctl;
            B.progressStart("Script", Total=2);
            B.progressStep(1, "first");
            % the script stops on an error here: nothing ends its run
            c.Cancel.ButtonPushedFcn(c.Cancel, []);
            tc.verifyTrue(B.Busy);
            tc.verifyTrue(B.CancelRequested);
            c.Cancel.ButtonPushedFcn(c.Cancel, []);
            tc.verifyFalse(B.Busy, 'A second Cancel ends a script''s open run.');
            tc.verifyEqual(string(c.ProgMsg.Text), "Canceled");
            tc.verifyEqual(c.Bar.ColumnWidth, {'500x', '500x'});
            tc.verifyEqual([string(c.Compute.Enable) string(c.Cancel.Enable)], ["on" "off"]);
            % the browser's own compute is not ended early by a second Cancel
            B.Settings = tc.Spike;
            seen = containers.Map();
            B.ProgressHook = @(b, f, m) cancelTwice(b, f, seen);
            tc.verifyError(@() B.compute(), 'epochMatrix:Canceled');
            tc.verifyTrue(seen('busy'), 'Compute stays Busy until it stops itself.');
            tc.verifyFalse(B.Busy);
            tc.verifyTrue(startsWith(string(c.ProgMsg.Text), "Canceled: "), c.ProgMsg.Text);
            B.ProgressHook = [];
        end

        function waitAndDone(tc)
            B = tc.open();
            t0 = tic;
            B.wait();
            tc.verifyLessThan(toc(t0), 2, 'Hidden: wait returns at once.');
            V = tc.open(Visible=true);
            seen = containers.Map();
            V.OnChange = @(~, what) count(seen, what);
            t = timer('StartDelay', 1, 'TimerFcn', @(~, ~) V.done());
            tc.addTeardown(@() delete(t));
            start(t);
            t0 = tic;
            V.wait(Timeout=60);
            tc.verifyLessThan(toc(t0), 30, 'Done ends the wait.');
            tc.verifyTrue(seen.isKey('done'));
            tc.verifyTrue(isvalid(V.Fig), 'Done keeps the window.');
            % the Compute button ends the wait once the result is there
            W = tc.open(Visible=true, Settings=tc.Spike, Workers=0);
            t2 = timer('StartDelay', 1, 'TimerFcn', @(~, ~) W.Ctl.Compute.ButtonPushedFcn(W.Ctl.Compute, []));
            tc.addTeardown(@() delete(t2));
            start(t2);
            t0 = tic;
            W.wait(Timeout=120);
            tc.verifyLessThan(toc(t0), 110, 'Compute ends the wait.');
            tc.verifyNotEmpty(W.Result, 'The result is there when wait returns.');
            tc.verifyTrue(isvalid(W.Fig), 'Compute keeps the window.');
        end

        function openFindsTheOpenWindow(tc)
            H = tc.open();
            tmp = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            file = fullfile(tmp.Folder, "results.mat");
            B = DatasetBrowser.open(tc.Root, ResultFile=file, Visible=true);
            tc.addTeardown(@() delete(B));
            tc.verifyNotSameHandle(B, H, 'A hidden browser is never returned.');
            tc.verifyEqual(string(B.Fig.Visible), "on");
            tc.verifySameHandle(DatasetBrowser.open(tc.Root + filesep), B, 'The window open on the root (a trailing separator ignored).');
            if ispc
                tc.verifySameHandle(DatasetBrowser.open(upper(tc.Root)), B, 'Case is ignored on Windows.');
            end
            tc.verifySameHandle(DatasetBrowser.open(""), B, 'No root: any open window.');
            other = DatasetBrowser.open(string(tmp.Folder), Visible=false, Scan=false);
            tc.addTeardown(@() delete(other));
            tc.verifyNotSameHandle(other, B, 'Another root: a new browser.');
            B.Fig.CloseRequestFcn(B.Fig, []);
            C = DatasetBrowser.open(tc.Root, ResultFile=file, Visible=false, Scan=false);
            tc.addTeardown(@() delete(C));
            tc.verifyNotSameHandle(C, B, 'A closed window is not returned.');
        end

        function closingKeepsTheObject(tc)
            B = tc.open(Settings=tc.Spike);
            seen = containers.Map();
            B.OnChange = @(~, what) count(seen, what);
            R = B.compute();
            B.Fig.CloseRequestFcn(B.Fig, []);
            tc.verifyTrue(isvalid(B));
            tc.verifyFalse(isvalid(B.Fig));
            tc.verifyTrue(seen.isKey('closed'));
            tc.verifyEqual(B.Result, R);
            R2 = B.compute();
            tc.verifyEqual(R2.data, R.data);
            tc.verifyEqual(B.Runs.Last.status, ["cached"; "cached"]);
            B.setFilter(Tags="pilot");   % refreshes skip the closed window
            tc.verifyEqual(B.Shown, tc.Keys(1));
            txt = evalc('B.progressStart("After"); B.progress(0.5, "half"); B.progressFinish("over");');
            tc.verifyTrue(contains(txt, "After: half") && contains(txt, "over"), txt);
            tc.verifyTrue(AppPrefs.ispref("DatasetBrowser", "Root"));
            tc.verifyEqual(string(AppPrefs.getpref("DatasetBrowser", "Root")), tc.Root);
            tc.verifyTrue(AppPrefs.ispref("DatasetBrowser", "Position"));
        end

        function workersPreference(tc)
            B = tc.open(Scan=false, Workers=3);
            tc.verifyEqual(B.Workers, 3);
            tc.verifyEqual(B.Ctl.Workers.Value, 3, 'The Workers field shows the option.');
            B.Ctl.Workers.Value = 2;
            B.Ctl.Workers.ValueChangedFcn(B.Ctl.Workers, []);
            tc.verifyEqual(B.Workers, 2, 'The Workers field sets Workers.');
            B.close();
            tc.verifyEqual(AppPrefs.getpref("DatasetBrowser", "Workers"), 2);
            B2 = tc.open(Scan=false);
            want = 2;
            pool = gcp('nocreate');
            if isa(pool, 'parallel.ProcessPool'); want = pool.NumWorkers; end
            tc.verifyEqual(B2.Workers, want, 'Workers comes back from the preferences, or is the open process pool''s size.');
            B2.Workers = 0;
            B2.close();
        end
    end

    methods (Test)
        function keepOnTop(tc)
            B = tc.open(Scan=false);
            tc.verifyFalse(B.OnTop);
            tc.verifyEqual(string(B.Fig.WindowStyle), "normal");
            B.Ctl.OnTop.Value = true;
            B.Ctl.OnTop.ValueChangedFcn(B.Ctl.OnTop, []);
            tc.verifyTrue(B.OnTop, 'The checkbox sets OnTop.');
            tc.verifyEqual(string(B.Fig.WindowStyle), "alwaysontop");
            B.close();
            tc.verifyTrue(logical(AppPrefs.getpref("DatasetBrowser", "OnTop")));
            B2 = tc.open(Scan=false);
            tc.verifyTrue(B2.OnTop, 'OnTop comes back from the preferences.');
            tc.verifyTrue(B2.Ctl.OnTop.Value);
            tc.verifyEqual(string(B2.Fig.WindowStyle), "alwaysontop");
            B2.OnTop = false;
            tc.verifyEqual(string(B2.Fig.WindowStyle), "normal");
            tc.verifyFalse(B2.Ctl.OnTop.Value);
            B2.close();
        end

        function postProcessingScript(tc)
            tmp = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            good = fullfile(string(tmp.Folder), "S_postTest.m");
            bad = fullfile(string(tmp.Folder), "S_postBad.m");
            writelines(["if ~exist('postRuns', 'var'), postRuns = 0; end" "postRuns = postRuns + 1;" ...
                "postSize = size(B.Result.data);"], good);
            writelines(["postX = 1;" "error('Post:Bad', 'broken');"], bad);
            before = evalin('base', 'who');
            tc.addTeardown(@() clearBaseExcept(before));
            B = tc.open(Settings=tc.Spike);
            bundled = endsWith(B.Scripts, "S_PrepareDatasetBrowserOutputForPlots.m");
            tc.verifyTrue(any(bundled), 'The first list holds the scripts of analysis\scripts.');
            tc.verifyEqual(B.Script, B.Scripts(1));
            tc.verifyFalse(B.ScriptAfterCompute);
            tc.verifyEqual(string(B.Ctl.ScriptRun.Enable), "off", 'Run now is off before a result.');

            B.addScript(good);
            tc.verifyTrue(endsWith(B.Script, "S_postTest.m"));
            tc.verifyEqual(B.Script, B.Scripts(end));
            tc.verifyEqual(string(B.Ctl.ScriptList.Value), B.Script, 'The drop-down shows the script added.');
            R = B.compute();
            tc.verifyFalse(evalin('base', 'exist(''postSize'', ''var'') == 1'), 'compute alone runs no script.');
            tc.verifyEqual(string(B.Ctl.ScriptRun.Enable), "on");

            B.Ctl.ScriptAfter.Value = true;
            B.Ctl.ScriptAfter.ValueChangedFcn(B.Ctl.ScriptAfter, []);
            tc.verifyTrue(B.ScriptAfterCompute, 'The box sets ScriptAfterCompute.');
            B.Ctl.Compute.ButtonPushedFcn(B.Ctl.Compute, []);
            tc.verifyEqual(evalin('base', 'postSize'), size(R.data), 'Compute ran the script in the base workspace.');
            tc.verifyEqual(evalin('base', 'postRuns'), 1);
            tc.verifyTrue(evalin('base', 'B') == B, 'The script sees this browser as B.');
            tc.verifyTrue(contains(B.Ctl.Status.Text, "S_postTest ran"), B.Ctl.Status.Text);
            B.Ctl.ScriptRun.ButtonPushedFcn(B.Ctl.ScriptRun, []);
            tc.verifyEqual(evalin('base', 'postRuns'), 2, 'Run now runs it again.');

            B.Script = bad;
            tc.verifyError(@() B.runScript(), 'DatasetBrowser:ScriptFailed');
            try
                B.runScript();
            catch ME
                tc.verifySubstring(ME.message, "S_postBad failed at line 2: broken");
            end
            B.Ctl.ScriptRun.ButtonPushedFcn(B.Ctl.ScriptRun, []);
            tc.verifySubstring(string(B.Ctl.Status.Text), "S_postBad failed");
            n = numel(B.Scripts);
            B.removeScript();
            tc.verifyEqual(numel(B.Scripts), n - 1);
            tc.verifyFalse(any(endsWith(B.Scripts, "S_postBad.m")));
            tc.verifyTrue(isfile(bad), 'Removing a script keeps its file.');
            tc.verifyTrue(endsWith(B.Script, "S_postTest.m"), 'The next one listed is picked.');

            B.Script = B.Scripts(find(bundled, 1));
            evalc('B.runScript()');
            tc.verifyEqual(evalin('base', 'size(R.data)'), size(R.data), 'The bundled script runs on the result.');
            tc.verifyTrue(evalin('base', 'exist(''data_'', ''var'') == 1'));

            B.close();
            tc.verifyEqual(string(AppPrefs.getpref("DatasetBrowser", "Scripts")), B.Scripts);
            B2 = tc.open(Scan=false);
            tc.verifyEqual(B2.Scripts, B.Scripts, 'The list comes back from the preferences.');
            tc.verifyEqual(B2.Script, B.Script);
            tc.verifyTrue(B2.ScriptAfterCompute);
            B2.ScriptAfterCompute = false;
            B2.close();
        end
    end

    methods (Test, TestTags = {'Slow'})
        function computeOnWorkersEqualsHere(tc)
            tc.assumeTrue(~isempty(ver('parallel')) && license('test', 'Distrib_Computing_Toolbox'), ...
                'No Parallel Computing Toolbox.');
            B = tc.open(Settings=tc.Spike, Workers=2);
            R = B.compute();
            tc.verifyEqual(B.Runs.Last.status, ["done"; "done"]);
            R0 = epochMatrix(B.Runner, tc.Spike, Datasets=B.Selected, LogFcn=[]);
            tc.verifyEqual(R.data, R0.data);
            tc.verifyEqual(R.rows, R0.rows);
            tc.verifyEqual(R.groupLabels, R0.groupLabels);
            tc.verifyTrue(all(startsWith(B.Table.Cached, "✓")), 'The Cached column.');
            B.compute();
            tc.verifyEqual(B.Runs.Last.status, ["cached"; "cached"]);
            [v, T] = B.forEach(@(src) src.name, Name="names", Workers=2);
            tc.verifyEqual(T.status, ["done"; "done"]);
            v0 = B.forEach(@(src) src.name, Name="names here", Workers=0);
            tc.verifyEqual(v, v0);
        end
    end
end


function R = runScript(file)
%runScript  Run an exported script in this function's workspace (no browser, no base variables); its R.
run(file);
end


function setSettings(B, S)
B.Settings = S;
end


function c = rowTints(tbl)
%rowTints  {color, rows} of the table's one row style (it must be the only background tint).
S = tbl.StyleConfigurations;
c = {S.Style(1).BackgroundColor, S.TargetIndex{1}(:).'};
end


function clearBaseExcept(keep)
%clearBaseExcept  Clear the base workspace's variables but KEEP (what a post-processing script left).
names = setdiff(evalin('base', 'who'), keep);
if ~isempty(names); evalin('base', char("clear " + strjoin(string(names), " "))); end
end


function count(map, what)
what = char(what);
if isKey(map, what); n = map(what); else; n = 0; end
map(what) = n + 1; %#ok<NASGU> a containers.Map is a handle
end


function v = cancelFrom(B)
%cancelFrom  A forEach function that presses Cancel: the next dataset stops.
B.cancel();
v = 1;
end


function cancelTwice(B, f, seen)
%cancelTwice  ProgressHook: at the second dataset, press Cancel twice and note whether the compute is still Busy.
if f > 0 && ~isKey(seen, 'busy')
    B.cancel();
    B.cancel();
    seen('busy') = B.Busy; %#ok<NASGU> a containers.Map is a handle
end
end


function cancelAtSecond(B, f, seen)
%cancelAtSecond  ProgressHook: at the second dataset, note the controls and press Cancel.
if f > 0 && ~isKey(seen, 'busy')
    c = B.Ctl;
    seen('busy') = [B.Busy, c.Compute.Enable == "off" && c.Table.Enable == "off", c.Cancel.Enable == "on", ...
        c.Data.Enable == "off"]; %#ok<NASGU> a containers.Map is a handle
    B.cancel();
end
end
