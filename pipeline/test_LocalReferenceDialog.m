classdef test_LocalReferenceDialog < matlab.unittest.TestCase
    %test_LocalReferenceDialog  The Local reference window: the probe colored by reference, clicks per shank or per probe, the table, a map that does not follow the shanks kept, Save and Cancel; ProbePicker's click hook and group colors.
    %   Built hidden (Visible=false) and driven through its methods, the
    %   same paths as the clicks, on a probe of two shanks of four sites
    %   (recording channels 1-8, chanMap 0-based, kcoords 1 and 2) in a
    %   recording of 64 channels.
    %
    %   Usage:  runtests("test_LocalReferenceDialog")

    properties
        Saved      % what OnSave got ("unset" until it was called)
        Probe = struct('chanMap', 0:7, 'xc', [0 0 20 20 200 200 220 220], 'yc', [0 40 20 60 0 40 20 60], ...
            'kcoords', [1 1 1 1 2 2 2 2])
    end

    methods (TestMethodSetup)
        function setUp(tc)
            tc.Saved = "unset";
        end
    end

    methods (Test)
        function drawsTheProbeColoredByReference(tc)
            M2 = struct('reference', {2, 7}, 'channels', {1:4, 5:8});
            dlg = tc.open(M2);
            P = dlg.Picker;
            tc.verifyEqual(P.BodyChannels, {1:4, 5:8}, 'Two shanks, left to right, with their channels.');
            tc.verifyEqual(P.BodyNames, ["Shank 1" "Shank 2"]);
            tc.verifyEqual(dlg.Map, M2, 'The map, as opened.');
            tc.verifyEqual(dlg.Scope, "shank");
            C = dlg.siteColors();
            S = P.Sites;
            one = C(S.channel <= 4, :);
            two = C(S.channel > 4, :);
            tc.verifyEqual(one, repmat(one(1, :), 4, 1), 'Every site of shank 1 in its reference''s color.');
            tc.verifyEqual(two, repmat(two(1, :), 4, 1));
            tc.verifyNotEqual(one(1, :), two(1, :), 'Two references, two colors.');
            tc.verifyNotEqual(one(1, :), [1 1 1], 'Assigned sites are not white.');
            tc.verifyEqual(dlg.Colors, [one(1, :); two(1, :)], 'Colors: one per group of Map, in its order.');
            D = dlg.Ctl.Table.Data;
            tc.verifyEqual(D(:, 1).', {'Shank 1', 'Shank 2'});
            tc.verifyEqual(D(:, 2).', {'1-4', '5-8'});
            tc.verifyEqual([D{:, 3}], [2 7]);
            tc.verifySubstring(string(D{1, 4}), "becomes zeros");
            t = string(dlg.Ctl.Summary.Text);
            tc.verifySubstring(t, "2 of 2 shank(s) have a reference");
            tc.verifySubstring(t, "Channel(s) 2,7");
            tc.verifyEmpty(dlg.Problems);
            tc.verifyEqual(string(dlg.Ctl.Problems.Text), "");
        end

        function aSiteClickSetsItsShank(tc)
            dlg = tc.open([]);
            tc.verifyEqual(dlg.siteColors(), ones(8, 3), 'No map: every site white.');
            tc.verifySubstring(dlg.Problems, "No reference for channel(s) 1-8");
            dlg.clickSite(3);
            tc.verifyEqual(dlg.Map, struct('reference', 3, 'channels', 1:4), ...
                'A site click with no shank picked: the reference of its own shank.');
            C = dlg.siteColors();
            S = dlg.Picker.Sites;
            tc.verifyEqual(C(S.channel > 4, :), ones(4, 3), 'The other shank stays white.');
            tc.verifySubstring(dlg.Problems, "5-8");
            dlg.clickShank(2);
            tc.verifyEqual(dlg.Selected, 2, 'A shank click picks it.');
            tc.verifySubstring(string(dlg.Ctl.Summary.Text), "Picked: Shank 2");
            dlg.clickSite(1);
            tc.verifyEqual(dlg.Map, struct('reference', {3, 1}, 'channels', {1:4, 5:8}), ...
                'Then a site click: the reference of the shank picked, wherever the site is.');
            tc.verifyEmpty(dlg.Selected, 'The pick is used up.');
            tc.verifyEqual(string(dlg.Ctl.Table.Data{2, 4}), "on shank 1");
            tc.verifyEmpty(dlg.Problems);
            dlg.clickShank(1);
            dlg.clickShank(2);
            dlg.clickShank(1);
            tc.verifyEqual(dlg.Selected, 2, 'A second click drops a shank.');
            dlg.clickShank(1);
            dlg.clickSite(6);
            tc.verifyEqual(dlg.Map, struct('reference', 6, 'channels', 1:8), 'Two shanks picked: one reference for both.');
            C = dlg.siteColors();
            tc.verifyEqual(C, repmat(C(1, :), 8, 1));
        end

        function oneReferenceForTheWholeProbe(tc)
            dlg = tc.open([]);
            dlg.setScope("probe");
            dlg.clickSite(5);
            tc.verifyEqual(dlg.Map, struct('reference', 5, 'channels', 1:8));
            dlg.clickShank(1);
            tc.verifyEmpty(dlg.Selected, 'Whole probe: a shank is not picked.');
            tc.verifySubstring(string(dlg.Ctl.Message.Text), "click the site");
            tc.verifyError(@() dlg.setScope("column"), 'LocalReferenceDialog:BadScope');
            dlg2 = tc.open(struct('reference', 5, 'channels', 1:8));
            tc.verifyEqual(dlg2.Scope, "probe", 'One reference over every shank opens as the whole probe.');
            tc.verifyEqual(string(dlg2.Ctl.Scope.Value), "probe");
        end

        function theTableSetsAndClears(tc)
            dlg = tc.open(struct('reference', {2, 7}, 'channels', {1:4, 5:8}));
            dlg.setReference(1, 40);
            tc.verifyEqual(dlg.Map, struct('reference', {40, 7}, 'channels', {1:4, 5:8}), ...
                'A channel off the probe (a reference wire) can be typed.');
            tc.verifyEqual(string(dlg.Ctl.Table.Data{1, 4}), "off the probe drawn");
            dlg.setReference(1, 99);
            tc.verifySubstring(string(dlg.Ctl.Message.Text), "1 to 64");
            tc.verifyEqual(dlg.Map(1).reference, 40, 'A channel past the recording changes nothing.');
            dlg.setReference(1, NaN);
            tc.verifyEqual(dlg.Map, struct('reference', 7, 'channels', 5:8), 'Cleared: the shank has none.');
            tc.verifyEmpty(dlg.Ctl.Table.Data{1, 3});
            dlg.clearAll();
            tc.verifyEmpty(dlg.Map);
            tc.verifyEqual(dlg.siteColors(), ones(8, 3));
        end

        function keepsAMapThatDoesNotFollowTheShanks(tc)
            M = struct('reference', {2, 7}, 'channels', {[1 2 5 6 20], [3 4 7 8]});
            dlg = tc.open(M);
            tc.verifyEqual(dlg.Map, M, 'Opened and read back unchanged, channel 20 (off the probe) included.');
            tc.verifySubstring(string(dlg.Ctl.Table.Data{1, 4}), "mixed");
            tc.verifySubstring(string(dlg.Ctl.Summary.Text), "off the probe drawn: channel(s) 20");
            dlg.clickSite(1);
            tc.verifyEqual(dlg.Map, struct('reference', {1, 2, 7}, 'channels', {1:4, [5 6 20], [7 8]}), ...
                'A shank set by a click takes all of its channels; the rest stays as it was.');
        end

        function saveAndCancel(tc)
            dlg = tc.open([], Ticked=0, OnSave=@(m, t) tc.save(m, t, ""));
            tc.verifyEqual(string(dlg.Ctl.SaveTicked.Enable), "off", 'Nothing ticked: Save to ticked is off.');
            dlg.clickSite(2);
            dlg.clickSite(7);
            dlg.save(false);
            tc.verifyEqual(tc.Saved.map, struct('reference', {2, 7}, 'channels', {1:4, 5:8}));
            tc.verifyFalse(tc.Saved.ticked);
            tc.verifyFalse(dlg.isOpen(), 'Saved: the window closes.');

            tc.Saved = "unset";
            dlg = tc.open([], Ticked=3, OnSave=@(m, t) tc.save(m, t, "Not saved: rec9 (probe other.json)."));
            tc.verifyEqual(string(dlg.Ctl.SaveTicked.Text), "Save to 3 ticked dataset(s)");
            dlg.save(true);
            tc.verifyTrue(tc.Saved.ticked);
            tc.verifyTrue(dlg.isOpen(), 'Not saved: the window stays open and says why.');
            tc.verifySubstring(string(dlg.Ctl.Message.Text), "rec9");

            tc.Saved = "unset";
            dlg = tc.open([], OnSave=@(m, t) tc.save(m, t, ""));
            dlg.clickSite(2);
            dlg.cancel();
            tc.verifyEqual(tc.Saved, "unset", 'Cancel saves nothing.');
            tc.verifyFalse(dlg.isOpen());
        end

        function noProbe(tc)
            dlg = LocalReferenceDialog([], Probe=[], Dataset="rec2", Visible=false);
            tc.addTeardown(@() delete(dlg));
            tc.verifyEqual(height(dlg.Picker.Sites), 0);
            tc.verifySubstring(string(dlg.Ctl.Summary.Text), "No probe to draw");
        end

        function pickerKeepsItsSelectionWithoutTheHook(tc)
            fig = uifigure("Visible", "off");
            tc.addTeardown(@() delete(fig));
            P = ProbePicker(fig);
            P.setProbe(tc.Probe);
            P.clickBody(2);
            tc.verifyEqual(P.Shanks, 2, 'No OnClick: a body click toggles its shank, as a click on it always did.');
            P.OnClick = @(kind, v) tc.noteClick(kind, v);
            tc.Saved = {};
            P.clickBody(1);
            P.click("site", 3);   % the selection's own path stays the selection's
            tc.verifyEqual(tc.Saved, {"body", 1}, 'With OnClick: the owner gets the body, the selection is left.');
            tc.verifyEqual(P.Shanks, 2);
            tc.verifyEqual(P.Channels, 3);
            P.Enable = "off";
            tc.Saved = {};
            P.clickBody(1);
            tc.verifyEmpty(tc.Saved, 'Enable off: clicks do nothing.');
            P.Enable = "on";
            tc.verifyError(@() P.paintGroups(ones(3, 3)), 'ProbePicker:BadColors');
            P.paintGroups([NaN(4, 3); repmat([1 0 0], 4, 1)], NaN(2, 3), struct('channel', 6, 'color', [1 0 0]));
            C = P.siteColors();
            tc.verifyEqual(C(P.Sites.channel > 4, :), repmat([1 0 0], 4, 1), 'paintGroups: the sites in their color.');
            tc.verifyEqual(C(P.Sites.channel <= 4, :), ones(4, 3), 'NaN: white.');
            P.select(3, []);
            P.paintGroups([]);
            C = P.siteColors();
            tc.verifyEqual(C(P.Sites.channel == 3, :), [0.16 0.45 0.80], 'paintGroups([]): the selection again.');
            tc.verifyEqual(C(P.Sites.channel ~= 3, :), ones(7, 3));
        end
    end

    methods
        function dlg = open(tc, map, varargin)
            %open  The window, hidden, on MAP and the two-shank probe in a 64-channel recording.
            dlg = LocalReferenceDialog(map, varargin{:}, Probe=tc.Probe, NumChannels=64, Dataset="rec1", ...
                ProbeName="two_shanks.json", Visible=false);
            tc.addTeardown(@() delete(dlg));
        end

        function why = save(tc, map, ticked, why)
            tc.Saved = struct('map', map, 'ticked', ticked);
        end

        function noteClick(tc, kind, v)
            tc.Saved = [tc.Saved, {string(kind), v}];
        end
    end
end
