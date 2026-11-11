classdef test_FilterDialog < matlab.unittest.TestCase
    %test_FilterDialog  The Filter window: the list to start from, the settings, the plots, Save and Delete, OK and Cancel, one filter or one per signal.
    %   Built hidden (Visible=false) and driven through its methods, the
    %   same paths as the clicks, with the saved filters in a temporary
    %   preference store (AppPrefs.useTemporary).
    %
    %   Usage:  runtests("test_FilterDialog")

    properties
        R          % what OnDone got ("unset" until it was called)
        Restore    % the preference store put back after the test
    end

    methods (TestMethodSetup)
        function setUp(tc)
            tc.R = "unset";
            tc.Restore = AppPrefs.useTemporary();
        end
    end

    methods (TestMethodTeardown)
        function tearDown(tc)
            tc.Restore = [];
        end
    end

    methods (Test)
        function opensOnNoFilter(tc)
            dlg = tc.open([], Rate=1000);
            tc.verifyEqual(dlg.Picked, "none");
            tc.verifyEqual(string(dlg.Ctl.List.Value), "none");
            tc.verifySubstring(string(dlg.Ctl.Describe.Text), "No filter");
            tc.verifyEqual(string(dlg.Ctl.Mag.Title.String), "No filter");
            tc.verifyEmpty(findobj(dlg.Ctl.Mag, 'Tag', 'gain'), 'Nothing drawn.');
            items = string(dlg.Ctl.List.Items);
            tc.verifyTrue(all(ismember(["No filter" "Custom (your settings)" "Theta  4-8 Hz" "High gamma  60-150 Hz" ...
                "60 Hz line noise  58-62 Hz"], items)), 'No filter, Custom, the EEG bands and the notches.');
            tc.verifySubstring(string(dlg.Ctl.RateNote.Text), "1000 Hz");
            tc.verifyFalse(contains(string(dlg.Ctl.Intro.Text), "Each signal has its own filter"), 'A panel''s words.');
        end

        function picksAPresetAndDrawsIt(tc)
            dlg = tc.open([], Rate=1000);
            dlg.pick("Theta");
            f = dlg.Filter;
            tc.verifyEqual(dlg.Picked, "preset:theta");
            tc.verifyEqual(f, SignalFilter.preset("theta"));
            tc.verifyEqual([dlg.Ctl.Low.Value dlg.Ctl.High.Value], [4 8]);
            tc.verifyEqual(string(dlg.Ctl.Design.Value), "butter");
            tc.verifyNotEmpty(findobj(dlg.Ctl.Mag, 'Tag', 'gain'), 'The gain drawn.');
            tc.verifyNotEmpty(findall(dlg.Ctl.Mag, 'Tag', 'passband'), 'The passband shaded (kept out of the legend).');
            tc.verifyEqual(dlg.Ctl.Mag.XScale, 'log');
            tc.verifySubstring(string(dlg.Ctl.Mag.Title.String), "squared");
            imp = findobj(dlg.Ctl.Imp, 'Tag', 'impulse');
            tc.verifyNotEmpty(imp);
            tc.verifyEqual(imp.YData, fliplr(imp.YData), 'AbsTol', 1e-9, 'Zero-phase: a symmetric impulse response.');
            tc.verifySubstring(string(dlg.Ctl.Describe.Text), "Theta 4-8 Hz band-pass, Butterworth order 4, zero-phase");
            tc.verifyEqual(dlg.ErrorText, "");
        end

        function editsBecomeCustom(tc)
            dlg = tc.open([], Rate=1000);
            dlg.pick("theta");
            dlg.setPhase("causal");
            tc.verifyEqual(dlg.Picked, "custom", 'Changed from the preset: Custom.');
            tc.verifyEqual(dlg.Filter.name, "Theta", 'The band is the preset''s: its name stays.');
            tc.verifySubstring(string(dlg.Ctl.Describe.Text), "Delayed about");
            imp = findobj(dlg.Ctl.Imp, 'Tag', 'impulse');
            tc.verifyEqual(max(abs(imp.YData(imp.XData < 0))), 0, 'Causal: nothing before the impulse.');
            tc.verifySubstring(string(dlg.Ctl.Imp.Title.String), "causal");
            dlg.setCutoff(5, 9);
            tc.verifyEqual(dlg.Filter.cutoff, [5 9]);
            tc.verifyEqual(dlg.Filter.name, "", 'Another band: no name.');
            dlg.setDesign("fir");
            tc.verifyEqual(dlg.Filter.order, 0, 'An FIR starts automatic.');
            tc.verifySubstring(string(dlg.Ctl.Describe.Text), "taps");
            dlg.setDesign("ellip");
            tc.verifyEqual(dlg.Filter.order, 4, 'Back to an IIR design: order 4.');
            tc.verifyEqual([string(dlg.Ctl.Ripple.Enable) string(dlg.Ctl.Attenuation.Enable)], ["on" "on"]);
            dlg.setDesign("cheby2");
            tc.verifyEqual([string(dlg.Ctl.Ripple.Enable) string(dlg.Ctl.Attenuation.Enable)], ["off" "on"]);
            dlg.setAttenuation(60);
            dlg.setOrder(6);
            tc.verifyEqual([dlg.Filter.attenuation dlg.Filter.order], [60 6]);
            dlg.setType("lowpass");
            tc.verifyEqual(dlg.Filter.cutoff, 9, 'A low-pass takes the high cutoff.');
            tc.verifyEqual(string(dlg.Ctl.Low.Enable), "off");
            dlg.setType("highpass");
            tc.verifyEqual(dlg.Filter.cutoff, 5, 'A high-pass the low one.');
            tc.verifyEqual(string(dlg.Ctl.High.Enable), "off");
            dlg.pick("none");
            tc.verifyFalse(dlg.Filter.enabled);
            dlg.setOrder(3);
            tc.verifyTrue(dlg.Filter.enabled, 'An edit after No filter turns it on.');
            tc.verifyEqual(dlg.Picked, "custom");
        end

        function refusesWhatCannotRun(tc)
            dlg = tc.open([], Rate=250);
            dlg.pick("High gamma");
            tc.verifySubstring(dlg.ErrorText, "Nyquist frequency (125 Hz)");
            tc.verifyEmpty(findobj(dlg.Ctl.Mag, 'Tag', 'gain'));
            dlg.ok();
            tc.verifyEqual(tc.R, "unset", 'The signal''s rate is known: OK refuses, the window stays.');
            tc.verifyTrue(dlg.isOpen());
            dlg.setCutoff(60, 100);
            dlg.ok();
            tc.verifyEqual(tc.R.cutoff, [60 100]);
            tc.verifyFalse(dlg.isOpen());
            % rate unknown: drawn at the rate typed, not refused
            dlg = tc.open([]);
            tc.verifyEqual(dlg.PreviewRate, FilterDialog.DefaultRate);
            tc.verifySubstring(string(dlg.Ctl.RateNote.Text), "not known");
            dlg.setPreviewRate(250);
            dlg.pick("High gamma");
            tc.verifySubstring(dlg.ErrorText, "the signal's own is not known");
            dlg.ok();
            tc.verifyEqual(tc.R.name, "High gamma", 'With the rate not known, OK keeps it (a layer that cannot use it is skipped).');
            dlg = tc.open([]);
            dlg.pick("theta");
            dlg.setCutoff(8, 4);
            tc.verifySubstring(dlg.ErrorText, "two cutoffs");
            tc.R = "unset";
            dlg.ok();
            tc.verifyEqual(tc.R, "unset", 'Bad settings are refused, rate or not.');
        end

        function savesAndDeletesYourFilters(tc)
            dlg = tc.open([], Rate=1000);
            dlg.pick("theta");
            dlg.setCutoff(6, 10);
            dlg.saveAs("Rat theta");
            tc.verifyEqual(dlg.Picked, "saved:Rat theta");
            tc.verifyEqual(dlg.Filter.name, "Rat theta");
            tc.verifyTrue(ismember("Rat theta  (saved)", string(dlg.Ctl.List.Items)));
            tc.verifyEqual(string(dlg.Ctl.Delete.Enable), "on");
            tc.verifyEqual(SignalFilter.find("rat theta").cutoff, [6 10]);
            dlg.saveAs("");
            tc.verifySubstring(dlg.ErrorText, "Type a name");
            dlg.pick("beta");
            tc.verifyEqual(string(dlg.Ctl.Delete.Enable), "off", 'Only a saved filter can be deleted.');
            dlg.pick("Rat theta");
            tc.verifyEqual(dlg.Filter.cutoff, [6 10], 'Picked again by its name.');
            dlg.deleteSaved();
            tc.verifyEmpty(SignalFilter.saved());
            tc.verifyEqual(dlg.Picked, "custom", 'Its settings stay, as Custom.');
            tc.verifyEqual(dlg.Filter.cutoff, [6 10]);
            % a window opened on a saved filter shows it picked
            SignalFilter.save("Rat theta", dlg.Filter);
            dlg2 = tc.open(SignalFilter.find("Rat theta"), Rate=1000);
            tc.verifyEqual(dlg2.Picked, "saved:Rat theta");
            dlg3 = tc.open(SignalFilter.preset("alpha"), Rate=1000);
            tc.verifyEqual(dlg3.Picked, "preset:alpha");
        end

        function okAndCancel(tc)
            dlg = tc.open(SignalFilter.preset("theta"), Rate=1000);
            dlg.ok();
            tc.verifyEmpty(tc.R, 'OK without a change: [].');
            tc.verifyFalse(isvalid(dlg.Fig), 'OK closes the window.');
            dlg = tc.open(SignalFilter.preset("theta"), Rate=1000);
            dlg.pick("none");
            dlg.ok();
            tc.verifyFalse(tc.R.enabled, 'No filter: off, its settings kept.');
            tc.verifyEqual(tc.R.cutoff, [4 8]);
            dlg = tc.open([], Rate=1000);
            dlg.pick("beta");
            dlg.cancel();
            tc.verifyEmpty(tc.R);
            dlg = tc.open([], Rate=1000);
            dlg.pick("beta");
            tc.R = "unset";
            dlg.Fig.CloseRequestFcn(dlg.Fig, []);
            tc.verifyEmpty(tc.R, 'Closed: canceled.');
        end

        function aFilterPerSignal(tc)
            S = struct('LFP', SignalFilter.preset("beta"), 'AUX', []);
            dlg = tc.open(S, Signals=["LFP" "MUA" "SPIKE" "AUX"], Rates=struct('LFP', 1000, 'AUX', 100), ...
                RateNotes=struct('LFP', "LFP of rec1 is read at 1000 Hz"), Used=["LFP" "AUX"]);
            tc.verifyEqual(dlg.Signal, "LFP");
            tc.verifyEqual(dlg.Picked, "preset:beta");
            tc.verifyEqual(string(dlg.Ctl.Signal.Items), ["LFP: Beta 13-30 Hz" "MUA: no filter  (no figure reads it)" ...
                "SPIKE: no filter  (no figure reads it)" "AUX: no filter"]);
            tc.verifySubstring(string(dlg.Ctl.RateNote.Text), "rec1");
            tc.verifySubstring(string(dlg.Ctl.Intro.Text), "Each signal has its own filter");
            dlg.setSignal("AUX");
            tc.verifyEqual(dlg.Picked, "none");
            tc.verifyEqual(dlg.PreviewRate, 100);
            dlg.pick("custom");
            dlg.setType("lowpass");
            dlg.setCutoff([], 60);
            dlg.ok();
            tc.verifyEqual(tc.R, "unset", 'AUX at 100 Hz: a 60 Hz cutoff is past Nyquist.');
            tc.verifySubstring(dlg.ErrorText, "AUX: ");
            dlg.setCutoff([], 20);
            dlg.setSignal("LFP");
            tc.verifyEqual(dlg.Filter.name, "Beta", 'Each signal keeps its pending filter.');
            dlg.ok();
            r = tc.R;
            tc.verifyEqual(string(fieldnames(r)).', ["LFP" "MUA" "SPIKE" "AUX"]);
            tc.verifyEqual(r.AUX.cutoff, 20);
            tc.verifyFalse(r.MUA.enabled);
            tc.verifyEqual(FilterDialog.describeSignals(r), "LFP Beta 13-30 Hz, AUX low-pass 20 Hz");
            tc.verifyEqual(FilterDialog.describeSignals(struct('LFP', SignalFilter.defaults())), "");
            tc.verifyError(@() dlg.setSignal("EEG"), 'FilterDialog:BadSignal');
        end
    end

    methods
        function dlg = open(tc, filters, varargin)
            dlg = FilterDialog(filters, varargin{:}, Visible=false, OnDone=@(r) tc.got(r));
            tc.addTeardown(@() delete(dlg));
        end

        function got(tc, r)
            tc.R = r;
        end
    end
end
