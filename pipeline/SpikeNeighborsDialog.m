classdef SpikeNeighborsDialog < handle
    % SpikeNeighborsDialog  Which sites are neighbors at the coincident-spike radius.
    %   A window that draws the channels' sites on the probe, each at its
    %   own x and y, and lists each site's neighbors: the sites within the
    %   radius of it (siteNeighbors), the ones EphysDataset.detectSpikes
    %   compares when it looks for one spike's copies (Coincidence). Click a
    %   site, or a row of the table, to circle the radius around it and mark
    %   its neighbors. Editing the radius here calls OnChange(radiusUm) at
    %   once, so the Spikes tab follows.
    %
    %     L = ds.channelLayout(ProbeFile=pf);
    %     dlg = SpikeNeighborsDialog([L.x; L.y].', Channels=1:numel(L.x), RadiusUm=50, ...
    %         OnChange=@(r) disp(r));
    %
    %   Properties: Fig, RadiusUm, Selected (the site circled, 0 = none),
    %   Neighbors ({1 x n}, as siteNeighbors gives them), Summary (the line
    %   under the plot), OnChange. Methods: setRadius, setSites, select,
    %   delete. Opened by EphysPipelineApp from the Spikes tab
    %   (onSpikesNeighbors).
    %
    %   See also siteNeighbors, EphysDataset.detectSpikes, EphysDataset.channelLayout.

    properties (SetAccess = private)
        Fig                               % the uifigure
        RadiusUm (1,1) double = 50        % the neighbor distance drawn
        Selected (1,1) double = 0         % the site circled (index into the sites; 0 = none)
        Neighbors = {}                    % {1 x n} the sites within RadiusUm of each
    end

    properties
        OnChange = []                     % called as OnChange(radiusUm) after the radius is edited here
    end

    properties (Dependent)
        Summary                           % the line under the plot
    end

    properties (Access = private)
        Pos = zeros(0, 2)                 % [n x 2] um (NaN = off the probe)
        Channels (1,:) double = []        % recording channel of each site
        Names (1,:) string = string.empty(1, 0)
        Ctl = struct()                    % the controls
    end

    methods
        function obj = SpikeNeighborsDialog(pos, opts)
            %SpikeNeighborsDialog  The window over the sites POS ([n x 2] um).
            %   dlg = SpikeNeighborsDialog(POS, Channels=, Names=, RadiusUm=,
            %   Title=, OnChange=, Parent=, Visible=)
            arguments
                pos (:,2) double
                opts.Channels (1,:) double = []
                opts.Names (1,:) string = string.empty(1, 0)
                opts.RadiusUm (1,1) double {mustBePositive} = 50
                opts.Title (1,1) string = ""
                opts.OnChange = []
                opts.Parent = []
                opts.Visible (1,1) logical = true
            end
            obj.OnChange = opts.OnChange;
            obj.RadiusUm = opts.RadiusUm;
            obj.build(opts.Parent, opts.Visible);
            obj.setSites(pos, Channels=opts.Channels, Names=opts.Names, Title=opts.Title);
        end

        function delete(obj)
            if ~isempty(obj.Fig) && isvalid(obj.Fig); delete(obj.Fig); end
        end

        function t = get.Summary(obj)
            t = string(obj.Ctl.Summary.Text);
        end

        function setSites(obj, pos, opts)
            %setSites  Show other sites (another dataset or probe); the selection is cleared.
            arguments
                obj
                pos (:,2) double
                opts.Channels (1,:) double = []
                opts.Names (1,:) string = string.empty(1, 0)
                opts.Title (1,1) string = ""
            end
            n = size(pos, 1);
            obj.Pos = pos;
            obj.Channels = opts.Channels;
            if numel(obj.Channels) ~= n; obj.Channels = 1:n; end
            obj.Names = opts.Names;
            if numel(obj.Names) ~= n; obj.Names = "ch" + string(obj.Channels); end
            name = "Spike neighbors";
            if opts.Title ~= ""; name = name + ": " + opts.Title; end
            obj.Fig.Name = name;
            obj.Selected = 0;
            obj.recompute();
        end

        function setRadius(obj, r)
            %setRadius  Draw the neighbors at radius R (um); OnChange is not called.
            arguments
                obj
                r (1,1) double {mustBePositive}
            end
            obj.RadiusUm = r;
            obj.Ctl.Radius.Value = r;
            obj.recompute();
        end

        function select(obj, k)
            %select  Circle site K (0 = none) and mark its neighbors.
            if k < 0 || k > size(obj.Pos, 1) || (k > 0 && any(isnan(obj.Pos(k, :))))
                k = 0;
            end
            obj.Selected = k;
            obj.draw();
        end
    end

    methods (Access = private)
        function build(obj, parent, visible)
            fig = uifigure("Name", "Spike neighbors", "Visible", "off", "Position", [100 100 980 640]);
            if ~isempty(parent) && isvalid(parent)
                p = parent.Position;
                fig.Position(1:2) = p(1:2) + max(0, (p(3:4) - fig.Position(3:4)) / 2);
            end
            obj.Fig = fig;
            g = uigridlayout(fig, [3 2]);
            g.RowHeight = {'fit', '1x', 30};
            g.ColumnWidth = {'1x', 430};
            intro = uilabel(g, "WordWrap", "on", "FontColor", [0.3 0.3 0.3], "Text", ...
                "One spike is often detected on several neighboring sites. Sites within the radius of each " + ...
                "other (their true distance on the probe) are neighbors: detection takes events on neighbors " + ...
                "whose troughs lie within the jitter as copies of one spike. Click a site, or a row, to circle " + ...
                "the radius around it. The radius goes into the Spikes tab (Spikes.CoincidenceRadiusUm) at once.");
            intro.Layout.Row = 1; intro.Layout.Column = [1 2];

            c = struct();
            c.Axes = uiaxes(g);
            c.Axes.Layout.Row = 2; c.Axes.Layout.Column = 1;
            disableDefaultInteractivity(c.Axes);
            c.Table = uitable(g, "RowName", {}, "SelectionType", "row", "Multiselect", "off", ...
                "ColumnName", {'Ch', 'Name', 'x (um)', 'y (um)', 'Neighbors', 'Neighbor channels'}, ...
                "ColumnWidth", {40, 60, 55, 55, 78, 'auto'}, ...
                "CellSelectionCallback", @(~, evt) obj.onTableSelected(evt));
            c.Table.Layout.Row = 2; c.Table.Layout.Column = 2;
            bg = uigridlayout(g, [1 3]);
            bg.Layout.Row = 3; bg.Layout.Column = [1 2];
            bg.ColumnWidth = {'fit', 90, '1x'};
            bg.RowHeight = {30};
            bg.Padding = [0 0 0 0];
            uilabel(bg, "Text", "Site radius (um):");
            c.Radius = uieditfield(bg, "numeric", "Value", obj.RadiusUm, "Limits", [0 Inf], ...
                "LowerLimitInclusive", "off", "ValueDisplayFormat", "%.10g", ...
                "Tooltip", "Sites at most this far apart are neighbors (Spikes.CoincidenceRadiusUm).", ...
                "ValueChangedFcn", @(src, ~) obj.onRadiusEdited(src.Value));
            c.Summary = uilabel(bg, "Text", "", "FontColor", [0.3 0.3 0.3]);
            obj.Ctl = c;
            fig.Visible = matlab.lang.OnOffSwitchState(visible);
        end

        function onRadiusEdited(obj, r)
            obj.setRadius(r);
            if ~isempty(obj.OnChange)
                obj.OnChange(r);
            end
        end

        function onTableSelected(obj, evt)
            if isempty(evt.Indices); return; end
            obj.select(evt.Indices(1, 1));
        end

        function onAxesClicked(obj, evt)
            % The site nearest the click, in the axes' data units.
            on = find(all(isfinite(obj.Pos), 2));
            if isempty(on); return; end
            p = evt.IntersectionPoint(1:2);
            [~, j] = min(hypot(obj.Pos(on, 1) - p(1), obj.Pos(on, 2) - p(2)));
            obj.select(on(j));
        end

        function recompute(obj)
            obj.Neighbors = siteNeighbors(obj.Pos, obj.RadiusUm);
            n = size(obj.Pos, 1);
            on = all(isfinite(obj.Pos), 2).';
            nNb = cellfun(@numel, obj.Neighbors);
            D = cell(n, 6);
            for k = 1:n
                list = strjoin(string(obj.Channels(obj.Neighbors{k})), ", ");
                if ~on(k); list = "off the probe"; end
                D(k, :) = {obj.Channels(k), char(obj.Names(k)), round(obj.Pos(k, 1), 2), ...
                    round(obj.Pos(k, 2), 2), nNb(k), char(list)};
            end
            obj.Ctl.Table.Data = D;
            if any(on)
                s = sprintf("%d site(s); neighbors per site at %g um: %d to %d (median %g)", ...
                    nnz(on), obj.RadiusUm, min(nNb(on)), max(nNb(on)), median(nNb(on)));
                none = nnz(on & nNb == 0);
                if none > 0
                    s = s + sprintf("; %d with none, so never a copy", none);
                end
            else
                s = "No site on the probe";
            end
            if any(~on)
                s = s + sprintf("; %d channel(s) off the probe", nnz(~on));
            end
            obj.Ctl.Summary.Text = s + ".";
            obj.draw();
        end

        function draw(obj)
            ax = obj.Ctl.Axes;
            cla(ax);
            on = all(isfinite(obj.Pos), 2);
            if ~any(on)
                title(ax, "No site on the probe");
                return
            end
            x = obj.Pos(:, 1);
            y = obj.Pos(:, 2);
            hold(ax, "on");
            k = obj.Selected;
            nbr = false(size(on));
            if k > 0
                nbr(obj.Neighbors{k}) = true;
                r = obj.RadiusUm;
                rectangle(ax, "Position", [x(k) - r, y(k) - r, 2*r, 2*r], "Curvature", [1 1], ...
                    "EdgeColor", [0.85 0.33 0.10], "LineWidth", 1.2, "LineStyle", "--", "PickableParts", "none");
            end
            rest = on & ~nbr;
            if k > 0; rest(k) = false; end
            h = scatter(ax, x(rest), y(rest), 40, [0.55 0.65 0.80], "filled", ...
                "MarkerEdgeColor", [0.2 0.2 0.2], "DisplayName", "site");
            h.ButtonDownFcn = @(~, evt) obj.onAxesClicked(evt);
            if k > 0
                h = scatter(ax, x(nbr), y(nbr), 52, [0.93 0.69 0.13], "filled", ...
                    "MarkerEdgeColor", [0.2 0.2 0.2], "DisplayName", "neighbor");
                h.ButtonDownFcn = @(~, evt) obj.onAxesClicked(evt);
                h = scatter(ax, x(k), y(k), 64, [0.85 0.33 0.10], "filled", ...
                    "MarkerEdgeColor", [0.1 0.1 0.1], "DisplayName", "selected");
                h.ButtonDownFcn = @(~, evt) obj.onAxesClicked(evt);
            end
            dx = 0.02 * max(max(x(on)) - min(x(on)), 20);
            text(ax, x(on) + dx, y(on), string(obj.Channels(on)), "FontSize", 8, ...
                "Color", [0.25 0.25 0.25], "PickableParts", "none", "Clipping", "on");
            hold(ax, "off");
            ax.ButtonDownFcn = @(~, evt) obj.onAxesClicked(evt);
            axis(ax, "equal");
            pad = max(obj.RadiusUm, 20);
            xlim(ax, [min(x(on)) - pad, max(x(on)) + pad]);
            ylim(ax, [min(y(on)) - pad, max(y(on)) + pad]);
            box(ax, "on");
            xlabel(ax, "x (\mum)");
            ylabel(ax, "y (\mum)");
            if k > 0
                title(ax, sprintf("Channel %g: %d neighbor(s) within %g \\mum", obj.Channels(k), ...
                    numel(obj.Neighbors{k}), obj.RadiusUm));
            else
                title(ax, "Click a site");
            end
        end
    end
end
