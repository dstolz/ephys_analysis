classdef ProbePicker < handle
    %ProbePicker  A probe drawn in an axes, its shanks and recording channels picked by clicking.
    %   P = ProbePicker(PARENT) puts an axes in PARENT (P.Axes; a grid's
    %   caller places it with P.Axes.Layout). P.setProbe(PROBE) draws the
    %   probe map PROBE (decoded JSON: chanMap 0-based, xc, yc, kcoords;
    %   the connected sites only, when it has connected) at its true site
    %   positions: each physical shank (probeColumns: sites grouped by x,
    %   whatever their kcoords) as a body with a tip, named under its tip
    %   by the kcoords group holding most of its sites, and each site as a
    %   dot, its recording channel (chanMap + 1) beside it when the labels
    %   fit. P.setProbe([], NOTE) clears the axes and shows NOTE.
    %
    %   P.select(CH, SH) shows a selection: CH recording channels (1-based)
    %   and SH shanks (kcoords values), [] = all. A site is kept when both
    %   hold it, the rule of selectUnits and epochMatrix: kept sites are
    %   filled, a site in CH on a shank SH leaves out is ringed, the rest
    %   are gray. With SH set, the bodies of its shanks are tinted.
    %
    %   Clicking a site toggles its channel in CH; clicking a shank's body
    %   or name toggles that shank in SH. A click on a blank CH (SH: all)
    %   starts the list with the one clicked; taking the last one off leaves
    %   it blank (all again). After a click OnPick(CH, SH) is called with
    %   the new lists: the owner applies them and calls select back with
    %   what it took. P.click("site", CH) and P.click("shank", K) do what a
    %   click does (scripts, tests). With Enable "off" clicks do nothing.
    %
    %   See also DatasetBrowser, probeColumns, probeSites, selectUnits, epochMatrix.

    properties
        OnPick = []                                % OnPick(CH, SH) after a click
        Enable matlab.lang.OnOffSwitchState = "on" % "off": clicks do nothing
    end

    properties (SetAccess = private)
        Axes                                       % the uiaxes
        Channels (1,:) double = []                 % the recording channels picked ([] = all)
        Shanks (1,:) double = []                   % the shanks (kcoords) picked ([] = all)
        Sites table                                % the sites drawn: channel, x, y, shank (kcoords)
    end

    properties (Access = private)
        Bodies = gobjects(0)                       % one patch per physical shank
        BodyShank (1,:) double = []                % the kcoords group each body picks
        Kept = []                                  % the kept sites (line)
        Ringed = []                                % picked sites on a shank left out (line)
        Off = []                                   % the other sites (line)
    end

    properties (Constant, Access = private)
        Pick = [0.16 0.45 0.80]
        Steel = [0.42 0.45 0.50]
    end

    methods
        function P = ProbePicker(parent)
            P.Axes = uiaxes(parent);
            ax = P.Axes;
            disableDefaultInteractivity(ax);   % a click picks; no data tips, pan or zoom
            ax.Toolbar.Visible = "off";
            ax.Visible = "off";
            ax.XLimMode = "manual";
            ax.YLimMode = "manual";
            P.Sites = ProbePicker.sitesOf([]);
            P.setProbe([]);
        end

        function setProbe(P, probe, note)
            %setProbe  Draw the probe map PROBE ([]: none, NOTE shown instead) with the selection as it is.
            if nargin < 3; note = ""; end
            ax = P.Axes;
            cla(ax);
            P.Bodies = gobjects(0);
            P.BodyShank = [];
            P.Sites = ProbePicker.sitesOf(probe);
            S = P.Sites;
            if height(S) == 0
                P.Kept = []; P.Ringed = []; P.Off = [];
                axis(ax, [0 1 0 1]);
                text(ax, 0.5, 0.5, string(note), "HorizontalAlignment", "center", "Color", P.Steel, ...
                    "FontSize", 11, "PickableParts", "none");
                return
            end

            % the geometry (um), as renderProbeMap draws it
            [col, C] = probeColumns(S.x, S.shank);
            nC = numel(C.center);
            yr = [min(S.y) max(S.y)];
            ySpan = diff(yr);
            if ~(ySpan > 0); ySpan = 100; end
            siteR = ProbePicker.siteRadius(S.x, S.y);
            pad = min(max(1.5 * siteR, 8), 25);
            gaps = C.lo(2:end) - C.hi(1:end-1);
            if ~isempty(gaps); pad = min(pad, 0.25 * min(gaps)); end
            hw = (C.hi - C.lo) / 2 + pad;
            taper = max(1.5 * max(hw), 0.06 * ySpan);
            yTip = zeros(1, nC);
            for c = 1:nC
                yTip(c) = min(S.y(col == c)) - max(1.2 * siteR, 0.03 * ySpan) - taper;
            end
            below = 0.09 * (nC > 1) + 0.03 * (nC == 1);   % room for the shanks' names under their tips
            yl = [min([yTip yr(1)]) - below * ySpan, yr(2) + max(2 * siteR, 0.05 * ySpan)];
            if nC > 1
                xm = max(1.5 * pad, 0.06 * (max(C.center + hw) - min(C.center - hw)));
                xl = [min(C.center - hw) - xm, max(C.center + hw) + xm];
            else
                xl = C.center + [-1 1] * max(4 * hw, 0.2 * ySpan);
            end

            hold(ax, "on");
            for c = 1:nC   % the bodies run past the top: the probe goes on above
                k = C.shank(c);
                P.Bodies(c) = patch(ax, "XData", C.center(c) + hw(c) * [-1 -1 0 1 1], ...
                    "YData", [yl(2) + ySpan, yTip(c) + taper, yTip(c), yTip(c) + taper, yl(2) + ySpan], ...
                    "LineWidth", 0.75, "ButtonDownFcn", @(~, ~) P.click("shank", k));
                P.BodyShank(c) = k;
                if nC > 1
                    text(ax, C.center(c), yTip(c) - 0.02 * ySpan, sprintf("Shank %g", k), "HorizontalAlignment", "center", ...
                        "VerticalAlignment", "top", "FontSize", 9, "Color", P.Steel, ...
                        "ButtonDownFcn", @(~, ~) P.click("shank", k));
                end
            end
            onSite = @(~, e) P.onSiteClick(e);
            P.Off = plot(ax, NaN, NaN, "o", "MarkerSize", 6, "Color", P.Steel, "MarkerFaceColor", [1 1 1], ...
                "LineWidth", 0.75, "ButtonDownFcn", onSite);
            P.Ringed = plot(ax, NaN, NaN, "o", "MarkerSize", 6, "Color", P.Pick, "MarkerFaceColor", [1 1 1], ...
                "LineWidth", 1.5, "ButtonDownFcn", onSite);
            P.Kept = plot(ax, NaN, NaN, "o", "MarkerSize", 6, "Color", 0.6 * P.Pick, "MarkerFaceColor", P.Pick, ...
                "LineWidth", 0.75, "ButtonDownFcn", onSite);
            axis(ax, [xl yl]);
            % the channels beside their sites, on the outer side of a shank's column, when they fit
            px = ax.InnerPosition(4);
            if 2 * siteR / diff(yl) * px >= 10
                for c = 1:nC
                    m = find(col == c);
                    left = S.x(m) < C.center(c) - 1e-6;
                    gap = string(blanks(2));
                    for j = reshape(m(left), 1, [])
                        text(ax, S.x(j), S.y(j), S.channel(j) + gap, "HorizontalAlignment", "right", ...
                            "FontSize", 7, "Color", P.Steel, "PickableParts", "none");
                    end
                    for j = reshape(m(~left), 1, [])
                        text(ax, S.x(j), S.y(j), gap + S.channel(j), "HorizontalAlignment", "left", ...
                            "FontSize", 7, "Color", P.Steel, "PickableParts", "none");
                    end
                end
            end
            hold(ax, "off");
            P.paint();
        end

        function select(P, channels, shanks)
            %select  Show CHANNELS (recording channels) and SHANKS (kcoords) as picked; [] = all.
            P.Channels = sort(unique(reshape(double(channels), 1, [])));
            P.Shanks = sort(unique(reshape(double(shanks), 1, [])));
            P.paint();
        end

        function click(P, kind, value)
            %click  What a click does: KIND "site" toggles recording channel VALUE, "shank" shank VALUE; then OnPick.
            if P.Enable == "off"; return; end
            switch string(kind)
                case "site";  P.Channels = ProbePicker.toggle(P.Channels, value);
                case "shank"; P.Shanks = ProbePicker.toggle(P.Shanks, value);
                otherwise
                    error('ProbePicker:BadKind', 'click takes "site" or "shank" (got "%s").', kind);
            end
            P.paint();
            if ~isempty(P.OnPick); P.OnPick(P.Channels, P.Shanks); end
        end

        function tf = kept(P)
            %kept  Which of Sites the selection keeps (both lists hold it).
            S = P.Sites;
            tf = true(height(S), 1);
            if ~isempty(P.Channels); tf = tf & ismember(S.channel, P.Channels); end
            if ~isempty(P.Shanks); tf = tf & ismember(S.shank, P.Shanks); end
        end
    end

    methods (Access = private)
        function paint(P)
            %paint  The sites and bodies in the colors of the selection.
            if isempty(P.Kept) || ~isvalid(P.Kept); return; end
            S = P.Sites;
            keep = P.kept();
            ring = ~keep & ~isempty(P.Channels) & ismember(S.channel, P.Channels);
            off = ~keep & ~ring;
            set(P.Kept, "XData", S.x(keep), "YData", S.y(keep));
            set(P.Ringed, "XData", S.x(ring), "YData", S.y(ring));
            set(P.Off, "XData", S.x(off), "YData", S.y(off));
            for c = 1:numel(P.Bodies)
                if ~isempty(P.Shanks) && ismember(P.BodyShank(c), P.Shanks)
                    set(P.Bodies(c), "FaceColor", 0.80 + 0.20 * P.Pick, "EdgeColor", P.Pick);
                else
                    set(P.Bodies(c), "FaceColor", 0.86 + 0.14 * P.Steel, "EdgeColor", 0.55 + 0.45 * P.Steel);
                end
            end
        end

        function onSiteClick(P, e)
            %onSiteClick  The site nearest the click (in the axes' own proportions) toggles.
            S = P.Sites;
            if height(S) == 0; return; end
            ax = P.Axes;
            q = e.IntersectionPoint(1:2);
            d = ((S.x - q(1)) / diff(ax.XLim)).^2 + ((S.y - q(2)) / diff(ax.YLim)).^2;
            [~, j] = min(d);
            P.click("site", S.channel(j));
        end
    end

    methods (Static)
        function v = toggle(v, x)
            %toggle  X taken off V when there, else added; a blank V (all) starts with X alone.
            if ismember(x, v)
                v = v(v ~= x);
            else
                v = sort([v x]);
            end
        end

        function S = sitesOf(probe)
            %sitesOf  The probe map's sites (connected ones, finite positions): channel (1-based), x, y, shank (kcoords).
            S = table(zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), 'VariableNames', {'channel', 'x', 'y', 'shank'});
            if isempty(probe) || ~isstruct(probe) || ~all(isfield(probe, {'chanMap', 'xc', 'yc'})); return; end
            ch = double(probe.chanMap(:)) + 1;
            x = double(probe.xc(:));
            y = double(probe.yc(:));
            n = min([numel(ch) numel(x) numel(y)]);
            ch = ch(1:n); x = x(1:n); y = y(1:n);
            k = zeros(n, 1);
            if isfield(probe, 'kcoords') && numel(probe.kcoords) >= n; k = reshape(double(probe.kcoords(1:n)), [], 1); end
            ok = isfinite(x) & isfinite(y);
            if isfield(probe, 'connected') && numel(probe.connected) >= n
                ok = ok & reshape(logical(probe.connected(1:n)), [], 1);
            end
            S = table(ch(ok), x(ok), y(ok), k(ok), 'VariableNames', {'channel', 'x', 'y', 'shank'});
        end
    end

    methods (Static, Access = private)
        function r = siteRadius(x, y)
            %siteRadius  Half the median distance from each site to its nearest neighbor (10 um for one site).
            r = 10;
            n = numel(x);
            if n < 2; return; end
            d = sqrt((x - x.').^2 + (y - y.').^2);
            d(1:n+1:end) = Inf;
            m = min(d, [], 2);
            m = m(isfinite(m) & m > 0);
            if ~isempty(m); r = median(m) / 2; end
        end
    end
end
