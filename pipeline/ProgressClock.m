classdef ProgressClock < handle
    % ProgressClock  The time a long operation has taken and an estimate of the time it has left.
    %   C = ProgressClock() starts the clock. S = C.update(FRACTION) takes
    %   how far the work is (0 to 1) and returns the time left as short
    %   text, "about 3 min left", or "" while there is too little of the
    %   work to go on: until MinFraction of it (1%) is done and MinSeconds
    %   (5 s) have passed, and once it is done. C.message(TEXT, FRACTION)
    %   is TEXT + " · about 3 min left" (TEXT alone while there is no
    %   estimate), the form the apps' progress dialogs and status lines
    %   show. Both apps use it for every time left they show, so the words
    %   are the same everywhere.
    %
    %     clock = ProgressClock();
    %     for i = 1:n
    %         dlg.Value = (i - 1) / n;
    %         dlg.Message = clock.message(sprintf("File %d/%d", i, n), (i - 1) / n);
    %         ...
    %     end
    %
    %   The estimate is the time per fraction so far, ELAPSED * (1 - F) / F,
    %   smoothed: the finish time it implies moves toward each new estimate
    %   with the time constant Smoothing (10 s), so the time left counts
    %   down steadily instead of jumping with every uneven piece of work.
    %   C.restart() starts again, for a new phase of work whose fraction
    %   starts again from 0. C.Elapsed and C.Left (NaN while there is no
    %   estimate) are in seconds, as of the last update. The clock does no
    %   drawing; the caller keeps its own drawnow limitrate.
    %
    %   For tests, update(FRACTION, T) and message(TEXT, FRACTION, T) take
    %   T, the seconds since the clock started, instead of reading the
    %   clock.
    %
    %   Static
    %     ProgressClock.leftText(SECS)     "a few seconds left", "about 40 s
    %                                      left", "about 3 min left", "about
    %                                      1 h 20 min left"
    %     ProgressClock.elapsedText(SECS)  "12 s elapsed", "3 min elapsed",
    %                                      "1 h 5 min elapsed"
    %     ProgressClock.durationText(SECS) "40 s", "3 min", "1 h 20 min"
    %
    %   See also EphysPipelineApp.onPipelineProgress, EphysAnalysisApp.onRunExport.

    properties
        MinFraction (1,1) double {mustBeNonnegative} = 0.01   % no estimate before this much of the work is done
        MinSeconds (1,1) double {mustBeNonnegative} = 5       % ... nor before this many seconds have passed
        Smoothing (1,1) double {mustBeNonnegative} = 10       % seconds: the time constant of the finish time (0 = none)
    end

    properties (SetAccess = private)
        Fraction (1,1) double = 0     % as of the last update
        Elapsed (1,1) double = 0      % seconds since the clock started, as of the last update
        Left (1,1) double = NaN       % seconds left, as of the last update (NaN: no estimate yet)
    end

    properties (Access = private)
        Started uint64                % tic of the start
        Finish (1,1) double = NaN     % the smoothed finish time, seconds since the start
        Last (1,1) double = NaN       % Elapsed at the last estimate
    end

    methods
        function obj = ProgressClock(opts)
            %ProgressClock  Start a clock; MinFraction=, MinSeconds= and Smoothing= set those properties.
            arguments
                opts.MinFraction (1,1) double {mustBeNonnegative} = 0.01
                opts.MinSeconds (1,1) double {mustBeNonnegative} = 5
                opts.Smoothing (1,1) double {mustBeNonnegative} = 10
            end
            obj.MinFraction = opts.MinFraction;
            obj.MinSeconds = opts.MinSeconds;
            obj.Smoothing = opts.Smoothing;
            obj.restart();
        end

        function restart(obj)
            %restart  Start again from now, with no estimate.
            obj.Started = tic;
            obj.Fraction = 0;
            obj.Elapsed = 0;
            obj.Left = NaN;
            obj.Finish = NaN;
            obj.Last = NaN;
        end

        function s = update(obj, fraction, t)
            %update  Take how far the work is; return the time left as text ("" without an estimate).
            %   T (default: the clock) is the seconds since the start.
            if nargin < 3; t = toc(obj.Started); end
            f = double(fraction);
            if ~isfinite(f); f = 0; end
            f = min(max(f, 0), 1);
            obj.Fraction = f;
            obj.Elapsed = t;
            s = "";
            if f >= 1
                obj.Left = 0;
                return
            end
            if f <= 0 || f < obj.MinFraction || t < obj.MinSeconds
                obj.Left = NaN;
                return
            end
            raw = t / f;                           % the finish time this fraction implies
            if isnan(obj.Finish) || obj.Smoothing == 0
                obj.Finish = raw;
            else
                a = 1 - exp(-max(t - obj.Last, 0) / obj.Smoothing);
                obj.Finish = obj.Finish + a * (raw - obj.Finish);
            end
            obj.Last = t;
            obj.Left = max(obj.Finish - t, 0);
            s = ProgressClock.leftText(obj.Left);
        end

        function s = message(obj, text, fraction, t)
            %message  TEXT + " · about 3 min left", or TEXT alone while there is no estimate.
            if nargin < 4
                left = obj.update(fraction);
            else
                left = obj.update(fraction, t);
            end
            s = ProgressClock.join(text, left);
        end
    end

    methods (Static)
        function s = leftText(secs)
            %leftText  "about 3 min left" for SECS seconds left.
            if ~(secs >= 10)
                s = "a few seconds left";
            else
                s = "about " + ProgressClock.durationText(secs) + " left";
            end
        end

        function s = elapsedText(secs)
            %elapsedText  "12 s elapsed" for SECS seconds.
            s = ProgressClock.durationText(secs) + " elapsed";
        end

        function s = durationText(secs)
            %durationText  SECS as a short, rounded span: "40 s" (to 5 s from 10 s), "3 min" (from 100 s), "1 h 20 min".
            secs = max(double(secs), 0);
            if secs < 10
                s = sprintf("%d s", round(secs));
            elseif secs < 97.5
                s = sprintf("%d s", 5 * round(secs / 5));
            elseif secs < 59.5 * 60
                s = sprintf("%d min", max(1, round(secs / 60)));
            else
                m = round(secs / 60);
                h = floor(m / 60);
                m = m - 60 * h;
                if m == 0
                    s = sprintf("%d h", h);
                else
                    s = sprintf("%d h %d min", h, m);
                end
            end
        end

        function s = join(text, left)
            %join  TEXT + " · " + LEFT, or TEXT alone when LEFT is "".
            s = string(text);
            left = string(left);
            if strlength(left) > 0
                s = s + " " + char(183) + " " + left;
            end
        end
    end
end
