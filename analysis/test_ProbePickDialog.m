classdef test_ProbePickDialog < matlab.unittest.TestCase
    %test_ProbePickDialog  The Probe... window: the probe drawn, clicks and fields yoked, All, a bad field refused, OK and Cancel, a pick of channels only.
    %   Built hidden (Visible=false) and driven through its methods, the
    %   same paths as the clicks, on a probe of two shanks of four sites
    %   (recording channels 1-8, chanMap 0-based). Also parseNumbers and
    %   numbersText, which its fields read and write.
    %
    %   Usage:  runtests("test_ProbePickDialog")

    properties
        R          % what OnDone got ("unset" until it was called)
        Probe = struct('chanMap', 0:7, 'xc', [0 0 20 20 200 200 220 220], 'yc', [0 40 20 60 0 40 20 60], ...
            'kcoords', [1 1 1 1 2 2 2 2])
    end

    methods (TestMethodSetup)
        function setUp(tc)
            tc.R = "unset";
        end
    end

    methods (Test)
        function drawsTheProbeWithThePick(tc)
            dlg = tc.open([6 3], 2);
            P = dlg.Picker;
            tc.verifyEqual(height(P.Sites), 8);
            tc.verifyEqual(P.Channels, [3 6], 'The pick, sorted, drawn.');
            tc.verifyEqual(P.Shanks, 2);
            tc.verifyEqual(string(dlg.Ctl.Channels.Value), "3 6");
            tc.verifyEqual(string(dlg.Ctl.Shanks.Value), "2");
            tc.verifyEqual(tc.keptChannels(dlg), 6, 'A site is kept when both lists hold it.');
            tc.verifySubstring(string(dlg.Ctl.Note.Text), "rec1: 8 sites on 2 shanks");
            tc.verifyEqual(string(dlg.Ctl.Count.Text), "Kept: 1 of 8 sites.");
            tc.verifySubstring(string(dlg.Ctl.Intro.Text), "a shank to pick or drop the shank");
            tc.verifyEqual(dlg.ErrorText, "");
        end

        function clicksAndFieldsFollowEachOther(tc)
            dlg = tc.open([], []);
            tc.verifyEqual(string(dlg.Ctl.Count.Text), "Kept: every site (8).");
            dlg.click("site", 3);
            tc.verifyEqual(dlg.Channels, 3, 'A site click starts the list.');
            tc.verifyEqual(string(dlg.Ctl.Channels.Value), "3");
            dlg.click("site", 4);
            dlg.click("site", 2);
            tc.verifyEqual(string(dlg.Ctl.Channels.Value), "2:4", 'A run is written a:b.');
            dlg.click("shank", 1);
            tc.verifyEqual(dlg.Shanks, 1);
            tc.verifyEqual(string(dlg.Ctl.Shanks.Value), "1");
            tc.verifyEqual(tc.keptChannels(dlg), 2:4);
            % a field typed: the probe follows
            dlg.setChannels("1:2, 7");
            tc.verifyEqual(dlg.Picker.Channels, [1 2 7]);
            tc.verifyEqual(string(dlg.Ctl.Channels.Value), "1 2 7", 'The field shows the pick as read.');
            tc.verifyEqual(tc.keptChannels(dlg), [1 2]);
            tc.verifySubstring(string(dlg.Ctl.Count.Text), "Kept: 2 of 8 sites.");
            dlg.setShanks("");
            tc.verifyEmpty(dlg.Picker.Shanks);
            tc.verifyEqual(tc.keptChannels(dlg), [1 2 7]);
            % dropping the last channel leaves the field blank: all again
            dlg.setChannels(5);
            dlg.click("site", 5);
            tc.verifyEmpty(dlg.Channels);
            tc.verifyEqual(string(dlg.Ctl.Channels.Value), "");
            % All: both blank
            dlg.setChannels([1 8]);
            dlg.setShanks(2);
            dlg.Ctl.All.ButtonPushedFcn(dlg.Ctl.All, []);
            tc.verifyEmpty(dlg.Channels);
            tc.verifyEmpty(dlg.Shanks);
            tc.verifyEqual([string(dlg.Ctl.Channels.Value) string(dlg.Ctl.Shanks.Value)], ["" ""]);
        end

        function namesPicksTheProbeLacks(tc)
            dlg = tc.open([2 70 71], 5);
            t = string(dlg.Ctl.Count.Text);
            tc.verifySubstring(t, "Kept: 0 of 8 sites.");
            tc.verifySubstring(t, "Not on this probe: channels 70 71.");
            tc.verifySubstring(t, "Not on this probe: shank 5.");
            tc.verifyEqual(dlg.Ctl.Count.FontColor, [0.75 0.1 0.1], 'Nothing kept: in red.');
        end

        function refusesABadField(tc)
            dlg = tc.open(3, []);
            dlg.setChannels("2 x");
            tc.verifySubstring(dlg.ErrorText, "Channels:");
            tc.verifyEqual(string(dlg.Ctl.Channels.Value), "2 x", 'The bad text stays in the field.');
            tc.verifyEqual(dlg.Channels, 3, 'The pick stays as it was.');
            dlg.ok();
            tc.verifyTrue(dlg.isOpen(), 'OK with a bad field keeps the window open.');
            tc.verifyEqual(tc.R, "unset");
            dlg.setChannels("0 2");
            tc.verifySubstring(dlg.ErrorText, "whole numbers from 1");
            dlg.setShanks("1.5");
            tc.verifySubstring(dlg.ErrorText, "Shanks: whole numbers");
            dlg.setShanks("1");
            tc.verifyTrue(contains(dlg.ErrorText, "Channels"), 'Channels still marked: its reason is shown.');
            dlg.setChannels("2");
            tc.verifyEqual(dlg.ErrorText, "");
            dlg.ok();
            tc.verifyFalse(dlg.isOpen());
            tc.verifyEqual(tc.R, struct('channels', 2, 'shanks', 1));
        end

        function okAndCancel(tc)
            dlg = tc.open([], []);
            dlg.ok();
            tc.verifyEmpty(tc.R, 'OK without a change: [].');
            tc.verifyFalse(dlg.isOpen());

            tc.R = "unset";
            dlg = tc.open(4, []);
            dlg.click("site", 5);
            dlg.cancel();
            tc.verifyEmpty(tc.R, 'Cancel: [].');

            tc.R = "unset";
            dlg = tc.open(4, []);
            dlg.click("site", 5);
            dlg.click("shank", 2);
            dlg.ok();
            tc.verifyEqual(tc.R, struct('channels', [4 5], 'shanks', 2));

            tc.R = "unset";
            dlg = tc.open([1 2], []);
            dlg.pickAll();
            dlg.ok();
            tc.verifyEqual(tc.R, struct('channels', [], 'shanks', []), 'All: both blank ([]).');

            tc.R = "unset";
            dlg = tc.open(1, []);
            dlg.Fig.CloseRequestFcn(dlg.Fig, []);
            tc.verifyEmpty(tc.R, 'Closing the window cancels it.');
            tc.verifyFalse(dlg.isOpen());
        end

        function channelsOnly(tc)
            dlg = tc.open(2, [], Shanks=false, ChannelsName="observe.channels");
            tc.verifyFalse(isfield(dlg.Ctl, 'Shanks'), 'No Shanks field.');
            tc.verifySubstring(string(dlg.Ctl.Channels.Tooltip), "Script name: observe.channels");
            tc.verifySubstring(string(dlg.Ctl.Intro.Text), "a shank to pick or drop all its channels");
            tc.verifyEqual(dlg.Picker.ShankPick, "channels");
            dlg.click("shank", 2);
            tc.verifyEqual(dlg.Channels, [2 5 6 7 8], 'A shank click adds its channels.');
            tc.verifyEmpty(dlg.Shanks);
            tc.verifyEqual(string(dlg.Ctl.Channels.Value), "2 5:8");
            dlg.click("shank", 2);
            tc.verifyEqual(dlg.Channels, 2, 'Again: its channels dropped.');
            dlg.click("shank", 1);
            dlg.click("shank", 1);
            tc.verifyEmpty(dlg.Channels, 'Every channel dropped: blank (all).');
            tc.verifyError(@() dlg.setShanks(1), 'ProbePickDialog:NoShanks');
            dlg.click("shank", 1);
            dlg.ok();
            tc.verifyEqual(tc.R, struct('channels', 1:4, 'shanks', []));
        end

        function noProbe(tc)
            dlg = ProbePickDialog(3, [], Dataset="rec2", Visible=false, OnDone=@(r) tc.done(r));
            tc.addTeardown(@() delete(dlg));
            tc.verifyEqual(height(dlg.Picker.Sites), 0);
            tc.verifySubstring(string(dlg.Ctl.Note.Text), "rec2 has no probe map: type the shanks and channels.");
            tc.verifyEqual(string(dlg.Ctl.Count.Text), "");
            dlg.setChannels("3 4");
            dlg.ok();
            tc.verifyEqual(tc.R, struct('channels', [3 4], 'shanks', []), 'The fields still take numbers typed.');

            dlg2 = ProbePickDialog([], [], Visible=false);
            tc.addTeardown(@() delete(dlg2));
            tc.verifySubstring(string(dlg2.Ctl.Note.Text), "No dataset open");
        end

        function numbersReadAndWritten(tc)
            tc.verifyEqual(parseNumbers("1:4"), 1:4);
            tc.verifyEqual(parseNumbers("[1, 3; 5]"), [1 3 5]);
            tc.verifyEqual(parseNumbers("1:2:7"), [1 3 5 7]);
            tc.verifyEmpty(parseNumbers("  "));
            tc.verifyError(@() parseNumbers("1 x", "Channels"), 'parseNumbers:BadValue');
            tc.verifyError(@() parseNumbers("1 x", "Channels", ErrorId="DatasetBrowser:BadValue"), 'DatasetBrowser:BadValue');
            tc.verifyEqual(numbersText([]), "");
            tc.verifyEqual(numbersText(1:4), "1:4");
            tc.verifyEqual(numbersText([1 2]), "1 2");
            tc.verifyEqual(numbersText([1:16 33:48]), "1:16 33:48");
            tc.verifyEqual(numbersText([1:4 7]), "1:4 7");
            tc.verifyEqual(numbersText([-0.2 0]), "-0.2 0");
            for v = {[], 3, [1 3 7], 1:16, [2 5:8 10], [-0.2 0]}
                tc.verifyEqual(parseNumbers(numbersText(v{1})), v{1}, 'numbersText is read back by parseNumbers.');
            end
        end

        function pickerShankPickRule(tc)
            tc.verifyEqual(ProbePicker.toggleAll([], [5 6]), [5 6]);
            tc.verifyEqual(ProbePicker.toggleAll([1 5], [5 6]), [1 5 6], 'Some held: the rest added.');
            tc.verifyEqual(ProbePicker.toggleAll([1 5 6], [5 6]), 1, 'All held: dropped.');
            tc.verifyEqual(ProbePicker.toggleAll(3, []), 3);
        end
    end

    methods
        function dlg = open(tc, channels, shanks, varargin)
            %open  The window, hidden, on CHANNELS and SHANKS and the two-shank probe; OnDone kept in tc.R.
            dlg = ProbePickDialog(channels, shanks, varargin{:}, Probe=tc.Probe, Dataset="rec1", Visible=false, ...
                OnDone=@(r) tc.done(r));
            tc.addTeardown(@() delete(dlg));
        end

        function done(tc, r)
            tc.R = r;
        end
    end

    methods (Static)
        function ch = keptChannels(dlg)
            P = dlg.Picker;
            ch = reshape(P.Sites.channel(P.kept()), 1, []);
        end
    end
end
