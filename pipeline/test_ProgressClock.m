classdef test_ProgressClock < matlab.unittest.TestCase
    %test_ProgressClock  The elapsed time and time-left estimate of long operations (ProgressClock).
    %   The words (durationText, leftText, elapsedText, join) at the edges
    %   of their roundings; no estimate before 1% and 5 s and none once
    %   done; a steady rate gives the time left exactly and message adds it
    %   after a middle dot; smoothing moves the time left only part of the
    %   way after an uneven piece and settles on a new steady rate
    %   (Smoothing 0 follows each estimate); restart, the MinFraction /
    %   MinSeconds options and fractions outside 0..1. The times are given
    %   (update's T), so nothing waits.
    %
    %   Usage:  runtests("test_ProgressClock")

    methods (Test)
        function words(tc)
            D = arrayfun(@ProgressClock.durationText, [0 4.4 9.6 12 57 58 97 98 125 3569 3571 3600 4800 7210]);
            tc.verifyEqual(D, ["0 s" "4 s" "10 s" "10 s" "55 s" "60 s" "95 s" "2 min" "2 min" "59 min" ...
                "1 h" "1 h" "1 h 20 min" "2 h"], "durationText: seconds (to 5 s from 10 s), minutes from 100 s, hours and minutes");
            tc.verifyEqual([ProgressClock.leftText(3) ProgressClock.leftText(42) ProgressClock.leftText(185) ...
                ProgressClock.leftText(NaN)], ["a few seconds left" "about 40 s left" "about 3 min left" "a few seconds left"], ...
                "leftText");
            tc.verifyEqual([ProgressClock.elapsedText(7) ProgressClock.elapsedText(190)], ["7 s elapsed" "3 min elapsed"], ...
                "elapsedText");
            tc.verifyEqual(ProgressClock.join("Window 3/9", "about 2 min left"), "Window 3/9 " + char(183) + " about 2 min left", ...
                "join: after a middle dot");
            tc.verifyEqual(ProgressClock.join("Window 3/9", ""), "Window 3/9", "join: the text alone without a time left");
        end

        function whenThereIsAnEstimate(tc)
            c = ProgressClock();
            tc.verifyEqual(c.update(0.5, 4), "", "no estimate before 5 s, however far the work is");
            tc.verifyTrue(isnan(c.Left) && c.Elapsed == 4 && c.Fraction == 0.5, "Left NaN; Elapsed and Fraction kept");
            tc.verifyEqual(c.update(0.005, 30), "", "no estimate before 1% of the work");
            c = ProgressClock();
            tc.verifyEqual(c.update(0.1, 10), "about 90 s left", "a steady rate: 10% in 10 s leaves 90 s");
            tc.verifyEqual(c.Left, 90, "AbsTol", 1e-9);
            tc.verifyEqual(c.update(0.5, 50), "about 50 s left", "still steady: the same rate, nothing to smooth");
            tc.verifyEqual(c.update(1, 100), "", "done: no time left shown");
            tc.verifyEqual(c.Left, 0);
            c = ProgressClock();
            tc.verifyEqual(c.message("Window 12/80", 0.25, 40), "Window 12/80 " + char(183) + " about 2 min left", "message");
            tc.verifyEqual(c.message("Window 1/80", 0, 0), "Window 1/80", "message: the text alone without an estimate");
        end

        function smoothing(tc)
            c = ProgressClock();
            c.update(0.2, 20);                     % 80 s left at this rate (finish at 100 s)
            c.update(0.21, 30);                    % a slow piece: alone it says finish at ~143 s
            raw = 30 / 0.21 - 30;
            tc.verifyTrue(c.Left > 70 && c.Left < raw - 10, ...
                sprintf("a slow piece moves the time left part of the way (%.1f s, alone %.1f s)", c.Left, raw));
            for t = 40:10:400
                c.update(0.21 + (t - 30) / 500, t);   % a new steady rate, 1/500 a second
            end
            fin = 30 + (1 - 0.21) * 500;          % where the new rate finishes
            tc.verifyLessThan(abs(c.Elapsed + c.Left - fin) / fin, 0.08, ...
                sprintf("it settles on the new rate (finish %.0f s, the rate says %.0f s)", c.Elapsed + c.Left, fin));
            c0 = ProgressClock(Smoothing=0);
            c0.update(0.2, 20);
            c0.update(0.21, 30);
            tc.verifyEqual(c0.Left, raw, "AbsTol", 1e-9, "Smoothing 0: each estimate as it is");
        end

        function restartOptionsAndOddFractions(tc)
            c = ProgressClock();
            c.update(0.2, 20);
            c.restart();
            tc.verifyTrue(isnan(c.Left) && c.Fraction == 0 && c.Elapsed == 0, "restart: no estimate");
            tc.verifyEqual(c.update(0.5, 2), "", "restart: the clock from 0 (before 5 s)");
            tc.verifyEqual(c.update(0.6, 6), "a few seconds left", "after a restart the estimate starts afresh");
            tc.verifyEqual(c.Left, 4, "AbsTol", 1e-9, "no smoothing toward the old estimate");
            q = ProgressClock(MinFraction=0, MinSeconds=0);
            tc.verifyNotEqual(q.update(0.001, 0.1), "", "MinFraction=0, MinSeconds=0: an estimate from the first update");
            tc.verifyEqual(q.update(-1, 1), ""); tc.verifyEqual(q.Fraction, 0, "a fraction below 0 is 0");
            tc.verifyEqual(q.update(NaN, 1), ""); tc.verifyEqual(q.Fraction, 0, "NaN is 0");
            tc.verifyEqual(q.update(2, 1), ""); tc.verifyEqual(q.Fraction, 1, "above 1 is 1 (done)");
            t0 = tic;
            r = ProgressClock();
            r.update(0.5);
            tc.verifyTrue(r.Elapsed >= 0 && r.Elapsed <= toc(t0) + 1e-3, "without T it reads its own clock");
        end
    end
end
