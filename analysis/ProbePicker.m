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
    %   are gray. With SH set, the bodies of its shanks are tinted (with
    %   ShankPick "channels": the shanks whose every site CH holds).
    %
    %   Clicking a site toggles its channel in CH; clicking a shank's body
    %   or name toggles that shank in SH. A click on a blank CH (SH: all)
    %   starts the list with the one clicked; taking the last one off leaves
    %   it blank (all again). After a click OnPick(CH, SH) is called with
    %   the new lists: the owner applies them and calls select back with
    %   what it took. P.click("site", CH) and P.click("shank", K) do what a
    %   click does (scripts, tests). With Enable "off" clicks do nothing.
    %
    %   P.ShankPick = "channels" is for a pick that has channels only (a
    %   signal's columns): a click on a shank then picks every channel of
    %   its sites into CH, or drops them all when CH holds every one of
    %   them already; SH stays as it is (blank). The default, "shanks",
    %   toggles the shank in SH.
    %
    %   P.OnClick = @(KIND, VALUE) ... takes the clicks instead, for an
    %   owner with picks of its own (LocalReferenceDialog): a click on a
    %   site calls OnClick("site", CH) with its recording channel, a click
    %   on a shank's body or name OnClick("body", B) with the body's index
    %   (a physical shank, left to right: BodyChannels{B} are the channels
    %   of its sites). The selection is left as it is. P.clickBody(B) does
    %   what a click on body B does. With Enable "off" clicks do nothing.
    %
    %   P.paintGroups(SITECOLOR, BODYCOLOR, MARKED) colors the probe by
    %   the owner's groups instead of the selection: SITECOLOR [n x 3] one
    %   RGB per row of Sites (a NaN row: unassigned, white), BODYCOLOR
    %   [nBody x 3] a tint per body (NaN: the steel of no group), MARKED a
    %   struct array (channel, color) of sites drawn larger as diamonds in
    %   COLOR (a group's reference). P.paintGroups([]) goes back to
    %   painting the selection. P.outlineBodies(B) outlines bodies B (the
    %   owner's selected shanks). setProbe clears both.
    %
    %   See also DatasetBrowser, ProbePickDialog, probeColumns, probeSites, selectUnits, epochMatrix,
    %   LocalReferenceDialog.

    properties
        OnPick = []                                % OnPick(CH, SH) after a click
        Enable matlab.lang.OnOffSwitchState = "on" % "off": clicks do nothing
        ShankPick (1,1) string {mustBeMember(ShankPick, ["shanks" "channels"])} = "shanks"   % what a shank click toggles: the shank, or its sites' channels
        OnClick = []                               % OnClick(KIND, VALUE) in place of the selection: "site", channel | "body", index
    end

    properties (SetAccess = private)
        Axes                                       % the uiaxes
        Channels (1,:) double = []                 % the recording channels picked ([] = all)
        Shanks (1,:) double = []                   % the shanks (kcoords) picked ([] = all)
        Sites table                                % the sites drawn: channel, x, y, shank (kcoords)
        BodyChannels = {}                          % {1 x nBody} the recording channels of each physical shank, left to right
        BodyNames (1,:) string = string.empty(1, 0) % the name under each body ("Shank k": its kcoords group)
    end

    properties (Access = private)
        Bodies = gobjects(0)                       % one patch per physical shank
        BodyShank (1,:) double = []                % the kcoords group each body picks
        Kept = []                                  % the kept sites (line)
        Ringed = []                                % picked sites on a shank left out (line)
        Off = []                                   % the other sites (line)
        Colored = []                               % the sites in their group's color (scatter, paintGroups)
        Marked = []                                % the groups' reference sites (scatter, paintGroups)
        Groups = []                                % paintGroups' colors ([] = paint the selection)
        Outlined (1,:) double = []                 % bodies outlined (outlineBodies)
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
            P.BodyChannels = {};
            P.BodyNames = string.empty(1, 0);
            P.Groups = [];
            P.Outlined = [];
            P.Sites = ProbePicker.sitesOf(probe);
            S = P.Sites;
            if height(S) == 0
                P.Kept = []; P.Ringed = []; P.Off = []; P.Colored = []; P.Marked = [];
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
                    "LineWidth", 0.75, "ButtonDownFcn", @(~, ~) P.clickBody(c));
                P.BodyShank(c) = k;
                P.BodyChannels{c} = reshape(S.channel(col == c), 1, []);
                P.BodyNames(c) = sprintf("Shank %g", k);
                if nC > 1
                    text(ax, C.center(c), yTip(c) - 0.02 * ySpan, P.BodyNames(c), "HorizontalAlignment", "center", ...
                        "VerticalAlignment", "top", "FontSize", 9, "Color", P.Steel, ...
                        "ButtonDownFcn", @(~, ~) P.clickBody(c));
                end
            end
            onSite = @(~, e) P.onSiteClick(e);
            P.Off = plot(ax, NaN, NaN, "o", "MarkerSize", 6, "Color", P.Steel, "MarkerFaceColor", [1 1 1], ...
                "LineWidth", 0.75, "ButtonDownFcn", onSite);
            P.Ringed = plot(ax, NaN, NaN, "o", "MarkerSize", 6, "Color", P.Pick, "MarkerFaceColor", [1 1 1], ...
                "LineWidth", 1.5, "ButtonDownFcn", onSite);
            P.Kept = plot(ax, NaN, NaN, "o", "MarkerSize", 6, "Color", 0.6 * P.Pick, "MarkerFaceColor", P.Pick, ...
                "LineWidth", 0.75, "ButtonDownFcn", onSite);
            P.Colored = scatter(ax, NaN, NaN, 40, [1 1 1], "filled", "Marker", "o", ...
                "MarkerEdgeColor", P.Steel, "LineWidth", 0.75, "ButtonDownFcn", onSite);
            P.Marked = scatter(ax, NaN, NaN, 110, [1 1 1], "filled", "Marker", "d", ...
                "MarkerEdgeColor", [0.1 0.1 0.1], "LineWidth", 1.25, "ButtonDownFcn", onSite);
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
            %click  What a click does: KIND "site" toggles recording channel VALUE, "shank" shank VALUE (or, ShankPick "channels", its sites' channels); then OnPick.
            if P.Enable == "off"; return; end
            switch string(kind)
                case "site";  P.Channels = ProbePicker.toggle(P.Channels, value);
                case "shank"
                    if P.ShankPick == "channels"
                        P.Channels = ProbePicker.toggleAll(P.Channels, P.Sites.channel(P.Sites.shank == value));
                    else
                        P.Shanks = ProbePicker.toggle(P.Shanks, value);
                    end
                otherwise
                    error('ProbePicker:BadKind', 'click takes "site" or "shank" (got "%s").', kind);
            end
            P.paint();
            if ~isempty(P.OnPick); P.OnPick(P.Channels, P.Shanks); end
        end

        function clickBody(P, b)
            %clickBody  What a click on body B (a physical shank, left to right) does: OnClick("body", B), else toggle its shank.
            if P.Enable == "off" || b < 1 || b > numel(P.BodyShank); return; end
            if ~isempty(P.OnClick)
                P.OnClick("body", b);
            else
                P.click("shank", P.BodyShank(b));
            end
        end

        function paintGroups(P, siteColor, bodyColor, marked)
            %paintGroups  Color the sites and bodies by the owner's groups; paintGroups([]) paints the selection again.
            %   SITECOLOR [height(Sites) x 3] (NaN row: white), BODYCOLOR
            %   [nBody x 3] (NaN row: steel), MARKED struct array with
            %   fields channel and color (the sites drawn as diamonds).
            if nargin < 2 || isempty(siteColor)
                P.Groups = [];
            else
                if nargin < 3; bodyColor = NaN(numel(P.Bodies), 3); end
                if nargin < 4; marked = struct('channel', {}, 'color', {}); end
                if size(siteColor, 1) ~= height(P.Sites) || size(siteColor, 2) ~= 3
                    error('ProbePicker:BadColors', 'paintGroups takes one RGB row per site (%d).', height(P.Sites));
                end
                if size(bodyColor, 1) ~= numel(P.Bodies) || size(bodyColor, 2) ~= 3
                    error('ProbePicker:BadColors', 'paintGroups takes one RGB row per body (%d).', numel(P.Bodies));
                end
                P.Groups = struct('site', double(siteColor), 'body', double(bodyColor), 'marked', marked);
            end
            P.paint();
        end

        function outlineBodies(P, b)
            %outlineBodies  Draw bodies B (indices, left to right) with a heavy outline: the owner's selected shanks.
            P.Outlined = reshape(double(b), 1, []);
            P.paint();
        end

        function C = siteColors(P)
            %siteColors  The fill color of each row of Sites as painted now (white: unassigned or not kept).
            S = P.Sites;
            C = ones(height(S), 3);
            if ~isempty(P.Groups)
                C = P.Groups.site;
                C(any(isnan(C), 2), :) = 1;
            else
                C(P.kept(), :) = repmat(P.Pick, nnz(P.kept()), 1);
            end
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
            %paint  The sites and bodies in the colors of the selection, or of the owner's groups (paintGroups).
            if isempty(P.Kept) || ~isvalid(P.Kept); return; end
            if ~isempty(P.Groups)
                P.paintGroupsNow();
                return
            end
            if ~isempty(P.Colored) && isvalid(P.Colored)
                set(P.Colored, "XData", NaN, "YData", NaN, "CData", [1 1 1]);
                set(P.Marked, "XData", NaN, "YData", NaN, "CData", [1 1 1]);
            end
            S = P.Sites;
            keep = P.kept();
            ring = ~keep & ~isempty(P.Channels) & ismember(S.channel, P.Channels);
            off = ~keep & ~ring;
            set(P.Kept, "XData", S.x(keep), "YData", S.y(keep));
            set(P.Ringed, "XData", S.x(ring), "YData", S.y(ring));
            set(P.Off, "XData", S.x(off), "YData", S.y(off));
            for c = 1:numel(P.Bodies)
                k = P.BodyShank(c);
                picked = ~isempty(P.Shanks) && ismember(k, P.Shanks);
                if P.ShankPick == "channels"   % a shank whose every site is picked
                    picked = ~isempty(P.Channels) && any(S.shank == k) && all(ismember(S.channel(S.shank == k), P.Channels));
                end
                if picked
                    set(P.Bodies(c), "FaceColor", 0.80 + 0.20 * P.Pick, "EdgeColor", P.Pick);
                else
                    set(P.Bodies(c), "FaceColor", 0.86 + 0.14 * P.Steel, "EdgeColor", 0.55 + 0.45 * P.Steel);
                end
            end
            P.paintOutlines();
        end

        function paintGroupsNow(P)
            %paintGroupsNow  The sites in their group's color, the bodies tinted, the references as diamonds.
            S = P.Sites;
            G = P.Groups;
            set([P.Kept, P.Ringed, P.Off], "XData", NaN, "YData", NaN);
            C = G.site;
            none = any(isnan(C), 2);
            C(none, :) = 1;   % unassigned: white, steel edge
            set(P.Colored, "XData", S.x, "YData", S.y, "CData", C);
            m = G.marked;
            if isempty(m)
                set(P.Marked, "XData", NaN, "YData", NaN, "CData", [1 1 1]);
            else
                [on, j] = ismember([m.channel], S.channel);
                j = j(on);
                MC = reshape([m(on).color], 3, []).';
                if isempty(j)
                    set(P.Marked, "XData", NaN, "YData", NaN, "CData", [1 1 1]);
                else
                    set(P.Marked, "XData", S.x(j), "YData", S.y(j), "CData", MC);
                end
            end
            for c = 1:numel(P.Bodies)
                b = G.body(c, :);
                if any(isnan(b))
                    set(P.Bodies(c), "FaceColor", 0.86 + 0.14 * P.Steel, "EdgeColor", 0.55 + 0.45 * P.Steel);
                else
                    set(P.Bodies(c), "FaceColor", 0.75 + 0.25 * b, "EdgeColor", 0.6 * b + 0.2);
                end
            end
            P.paintOutlines();
        end

        function paintOutlines(P)
            %paintOutlines  The outlined bodies (outlineBodies) heavy and dark, the others as painted.
            for c = 1:numel(P.Bodies)
                if ismember(c, P.Outlined)
                    set(P.Bodies(c), "LineWidth", 2.5, "EdgeColor", [0.1 0.1 0.1]);
                else
                    set(P.Bodies(c), "LineWidth", 0.75);
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
            if ~isempty(P.OnClick)
                if P.Enable == "off"; return; end
                P.OnClick("site", S.channel(j));
            else
                P.click("site", S.channel(j));
            end
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

        function v = toggleAll(v, xs)
            %toggleAll  Every one of XS taken off V when V holds them all, else XS added; a blank V (all) starts with XS.
            xs = reshape(double(xs), 1, []);
            if isempty(xs); return; end
            if all(ismember(xs, v))
                v = v(~ismember(v, xs));
            else
                v = unique([reshape(v, 1, []) xs]);
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
