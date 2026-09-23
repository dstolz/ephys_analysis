classdef EphysTraceViewer < handle
    % EphysTraceViewer  Fast multichannel trace view with spike overlays, one window at a time.
    %   V = EphysTraceViewer(AX) draws into the axes AX (a uiaxes or axes):
    %   one continuous signal (an EphysTraceSource: the recording, the
    %   Sorting .bin, or a derived LFP / MUA / SPIKE / AUX signal) as stacked
    %   lanes, spike layers over it (sorted units, detected spikes) and
    %   shaded periods (artifacts). It is what the app's Visualize tab shows.
    %
    %     v = EphysTraceViewer(ax, OverviewAxes=ax2);
    %     v.setSource(EphysTraceSource.recording(ds), 1:64);
    %     v.setLayers(EphysTraceViewer.unitLayer(ds.readSortedUnits()));
    %     v.setView(10, 2);            % 10 .. 12 s
    %
    %   Speed
    %   -----
    %   Only the window shown is read, with one window of margin on each
    %   side (less when a wide window would read more than MaxReadSamples),
    %   and each lane is reduced to one min / max pair per pixel column, so a
    %   draw costs about the same at any zoom and never scales with the
    %   recording's length. Panning inside the margin moves the axes limits
    %   only; a zoom or a pan past the margin draws again from the samples
    %   kept in memory (CacheSamples) and reads the disk only for rows it
    %   does not hold. Lanes of one colour are drawn as one line, and each
    %   spike colour as one line, so the number of graphics objects stays
    %   small whatever the channel or unit count. Interactions that arrive
    %   faster than a draw are merged (RenderDelay).
    %
    %   Lanes
    %   -----
    %   Lane k is centred at y = -(k-1), one unit apart; a signal value v is
    %   drawn at centre + (v - offset) / Spacing, so Spacing is the voltage
    %   between neighbouring lanes (source units, microvolts). The trace
    %   lanes (Channels, in order) come first; a spike layer placed on its
    %   own lanes ("raster") adds one lane per unit or channel after them.
    %   Row k of the source is drawn at (k-1)/Fs s and a spike at its time,
    %   so both share the recording's clock. A binned point is drawn at its
    %   bin's first sample.
    %
    %   Spike layers (unitLayer, detectedLayer) are drawn as
    %     "ticks"      a tick per spike: in the top half of its channel's
    %                  trace lane (detected spikes: the bottom half), or
    %                  across its own lane
    %     "waveforms"  on a trace lane, the trace itself is recoloured over
    %                  each spike's window (as phy's trace view does); on
    %                  its own lane (or with no trace), the stored waveform:
    %                  the detected snippet, or the unit's template. More
    %                  than MaxWaveforms spikes in view, or a trace below
    %                  10 kHz, fall back to ticks (LastRender.notes says so)
    %   Each unit or channel takes a colour of Palette.
    %
    %   Interaction (the app routes the figure's events here)
    %   -----------------------------------------------------
    %     handleScroll(count, mods, t)  wheel: zoom time about T; Ctrl: scale
    %                                   the voltage; Shift: scroll the lanes
    %     handleKey(key, mods)          arrows: pan time / scale voltage;
    %                                   Shift+arrows: zoom time / scroll lanes;
    %                                   PageUp/Down: a window; Home/End;
    %                                   a: auto scale; r: reset
    %     beginDrag / dragTo / endDrag  drag to pan time (and lanes)
    %     seekOverview(t)               centre the view on T (overview strip)
    %   and programmatically: setView, zoomTime, panTime, scaleVoltage,
    %   setSpacing, autoScale, scrollLanes, setVisibleLanes, resetView.
    %
    %   See also EphysTraceSource, EphysPreprocessingApp.

    properties (SetAccess = private)
        Axes                                   % the axes drawn into
        OverviewAxes = []                      % optional strip: the whole recording
        Source = []                            % EphysTraceSource, or [] (spikes only)
        Layers struct = EphysTraceViewer.emptyLayers()
        Channels (1,:) double = double.empty(1,0)   % source columns, in lane order
        TStart (1,1) double = 0                % left edge of the view (s)
        TWidth (1,1) double = 2                % width of the view (s)
        Spacing (1,1) double = 100             % source units between lanes
        FirstLane (1,1) double = 1             % top lane shown
        LastRender struct = struct('bin', NaN, 'read', false, 'seconds', 0, ...
            'nSpikes', 0, 'styles', strings(1, 0), 'notes', strings(1, 0), 'error', "")
    end

    properties
        VisibleLanes (1,1) double {mustBePositive} = 16   % lanes shown at once
        LaneColors = []                        % [numel(Channels) x 3]; [] = TraceColor
        LaneBreaks (1,:) double = double.empty(1,0)  % dotted line below these trace lanes
        TraceColor (1,3) double = [0.15 0.15 0.15]
        Mode (1,1) string {mustBeMember(Mode, ["traces" "heatmap"])} = "traces"
        Colormap (1,1) string = "turbo"
        Filter struct = struct('type', "", 'cutoff', [], 'order', 4)   % display filter ("" = none)
        Reference (1,1) string {mustBeMember(Reference, ["none" "car" "cmr"])} = "none"   % across the channels shown
        RemoveOffset (1,1) logical = true      % centre each lane on its median in view
        Shading struct = struct('intervals', {}, 'color', {}, 'alpha', {})   % shaded periods (s)
        Duration (1,1) double = NaN            % time axis length without a source (s)
        DefaultWidth (1,1) double = 2          % window of resetView (s)
        MaxReadSamples (1,1) double = 2^27     % samples x channels one draw may read
        CacheSamples (1,1) double = 2^26       % samples x channels kept at full rate
        PieceSamples (1,1) double = 2^23       % samples x channels per read
        MaxWaveforms (1,1) double = 4000       % more spikes in view: ticks
        RenderDelay (1,1) double = 0.03        % merge interactions this close (s); 0 = draw at once
        ViewChangedFcn = []                    % f(viewer) after the view changes
        BusyFcn = []                           % f(message) before a long read, f("") after
        Palette (:,3) double = EphysTraceViewer.defaultPalette()
    end

    properties (Dependent)
        TotalDuration   % the time axis: the source's length, else Duration (s)
        NumLanes        % trace lanes + raster lanes
    end

    properties (Access = private)
        TraceLines = gobjects(0, 1)
        SpikeLines = gobjects(0, 1)
        ShadePatches = gobjects(0, 1)
        Image = gobjects(0)
        BreakLine = gobjects(0)
        SelectPatch = gobjects(0)
        ScaleLine = gobjects(0)
        ScaleText = gobjects(0)
        Message = gobjects(0)
        OvView = gobjects(0)
        OvRate = gobjects(0)
        OvShade = gobjects(0, 1)
        Env = []            % reduced samples: key, b, r0, mn, mx, offset, set
        Cache = []          % processed full-rate samples: key, r0, X, set
        Drawn = []          % what the axes show: span, b
        Timer = []
        AxesListener = []   % deletes the viewer with its axes
        Drag = []
        AutoPending (1,1) logical = true
        Rate = []           % overview spike density ([] = work it out at the next draw)
    end

    methods
        function obj = EphysTraceViewer(ax, opts)
            arguments
                ax (1,1)
                opts.OverviewAxes = []
            end
            obj.Axes = ax;
            obj.OverviewAxes = opts.OverviewAxes;
            setupAxes(ax);
            obj.Image = image(ax, 'CData', zeros(1, 1, 'single'), 'CDataMapping', 'scaled', ...
                'Visible', 'off', 'HitTest', 'off', 'PickableParts', 'none');
            obj.BreakLine = line(ax, NaN, NaN, 'Color', [0.6 0.6 0.6], 'LineStyle', ':', ...
                'HitTest', 'off', 'PickableParts', 'none');
            obj.SelectPatch = patch(ax, 'XData', NaN, 'YData', NaN, 'FaceColor', [0.85 0.2 0.2], ...
                'FaceAlpha', 0.15, 'EdgeColor', 'none', 'Visible', 'off', 'HitTest', 'off', 'PickableParts', 'none');
            obj.ScaleLine = line(ax, NaN, NaN, 'Color', [0 0 0], 'LineWidth', 2, ...
                'HitTest', 'off', 'PickableParts', 'none', 'Clipping', 'off');
            obj.ScaleText = text(ax, NaN, NaN, "", 'HorizontalAlignment', 'right', ...
                'VerticalAlignment', 'middle', 'FontSize', 10, 'Interpreter', 'none', ...
                'BackgroundColor', [1 1 1], 'Margin', 1, 'HitTest', 'off', 'PickableParts', 'none');
            obj.Message = text(ax, 0.5, 0.5, "", 'Units', 'normalized', ...
                'HorizontalAlignment', 'center', 'Color', [0.4 0.4 0.4], 'FontSize', 12, ...
                'Interpreter', 'none', 'HitTest', 'off', 'PickableParts', 'none');
            if ~isempty(obj.OverviewAxes)
                ov = obj.OverviewAxes;
                setupAxes(ov);
                set(ov, 'YLim', [0 1], 'YTick', [], 'XLim', [0 1], 'Box', 'on');
                obj.OvRate = line(ov, NaN, NaN, 'Color', [0.35 0.35 0.35], 'HitTest', 'off', 'PickableParts', 'none');
                obj.OvView = patch(ov, 'XData', [0 1 1 0], 'YData', [0 0 1 1], 'FaceColor', [0 0.45 0.74], ...
                    'FaceAlpha', 0.25, 'EdgeColor', [0 0.45 0.74], 'HitTest', 'off', 'PickableParts', 'none');
            end
            obj.AxesListener = listener(ax, 'ObjectBeingDestroyed', @(~, ~) delete(obj));
            obj.render();
        end

        function delete(obj)
            if ~isempty(obj.Timer) && isvalid(obj.Timer)
                stop(obj.Timer);
                delete(obj.Timer);
            end
            delete(obj.AxesListener);
        end

        function d = get.TotalDuration(obj)
            if ~isempty(obj.Source)
                d = obj.Source.Duration;
            else
                d = obj.Duration;
            end
            if ~(d > 0); d = 1; end
        end

        function n = get.NumLanes(obj)
            n = numel(obj.Channels) + numel(rasterLanes(obj));
        end

        %% --- content ---------------------------------------------------------
        function setSource(obj, src, channels)
            %setSource  Show SRC (an EphysTraceSource, or [] for none) on CHANNELS.
            %   CHANNELS: source columns in lane order (default all). A new
            %   source is scaled automatically at its first draw.
            arguments
                obj (1,1) EphysTraceViewer
                src = []
                channels (1,:) double = []
            end
            same = ~isempty(src) && ~isempty(obj.Source) && src == obj.Source;
            obj.Source = src;
            if isempty(src)
                obj.Channels = double.empty(1, 0);
            elseif isempty(channels)
                obj.Channels = 1:src.NumChannels;
            else
                obj.Channels = channels(channels >= 1 & channels <= src.NumChannels);
            end
            if numel(obj.LaneColors) / 3 ~= numel(obj.Channels)
                obj.LaneColors = [];
            end
            if ~same
                obj.Env = [];
                obj.Cache = [];
                obj.AutoPending = true;
            end
            obj.Drawn = [];
            obj.FirstLane = 1;
            obj.clampView();
            obj.updateRate();
        end

        function setChannels(obj, channels, colors, breaks)
            %setChannels  Lanes: source columns CHANNELS, their COLORS ([] = one colour), BREAKS.
            arguments
                obj (1,1) EphysTraceViewer
                channels (1,:) double
                colors = []
                breaks (1,:) double = double.empty(1,0)
            end
            if isempty(obj.Source); return; end
            obj.Channels = channels(channels >= 1 & channels <= obj.Source.NumChannels);
            obj.LaneColors = colors;
            if size(colors, 1) ~= numel(obj.Channels); obj.LaneColors = []; end
            obj.LaneBreaks = breaks;
            obj.Drawn = [];
            obj.clampView();
        end

        function setLayers(obj, layers)
            %setLayers  Spike layers to overlay (unitLayer / detectedLayer structs).
            if isempty(layers)
                layers = EphysTraceViewer.emptyLayers();
            end
            obj.Layers = layers;
            obj.Drawn = [];
            obj.clampView();
            obj.updateRate();
        end

        function setLayerStyle(obj, name, style, placement)
            %setLayerStyle  STYLE ("ticks" | "waveforms" | "off") and PLACEMENT of layer NAME.
            arguments
                obj (1,1) EphysTraceViewer
                name (1,1) string
                style (1,1) string {mustBeMember(style, ["ticks" "waveforms" "off"])}
                placement (1,1) string {mustBeMember(placement, ["channels" "raster"])} = "channels"
            end
            i = find(string({obj.Layers.name}) == name, 1);
            if isempty(i); return; end
            obj.Layers(i).style = style;
            obj.Layers(i).placement = placement;
            obj.Drawn = [];
            obj.clampView();
            obj.updateRate();
        end

        function setLayerGroups(obj, name, show, order)
            %setLayerGroups  Which units / channels of layer NAME are drawn (SHOW), and their lane ORDER.
            arguments
                obj (1,1) EphysTraceViewer
                name (1,1) string
                show (1,:) logical
                order (1,:) double = []
            end
            i = find(string({obj.Layers.name}) == name, 1);
            if isempty(i); return; end
            if numel(show) == numel(obj.Layers(i).labels)
                obj.Layers(i).show = show;
            end
            if ~isempty(order)
                obj.Layers(i).order = order;
            end
            obj.Drawn = [];
            obj.clampView();
            obj.updateRate();
        end

        function setSelection(obj, iv)
            %setSelection  Shade [t0 t1] as a selection being made ([] = none).
            if isempty(iv)
                set(obj.SelectPatch, 'Visible', 'off', 'XData', NaN, 'YData', NaN);
                return
            end
            y = laneExtent(obj);
            set(obj.SelectPatch, 'XData', [iv(1) iv(2) iv(2) iv(1)], ...
                'YData', [y(1) y(1) y(2) y(2)], 'Visible', 'on');
        end

        %% --- view --------------------------------------------------------------
        function setView(obj, t0, width)
            %setView  Show T0 .. T0+WIDTH seconds (clamped to the recording).
            if nargin < 3 || isempty(width); width = obj.TWidth; end
            oldWidth = obj.TWidth;
            obj.TWidth = width;
            obj.TStart = t0;
            obj.clampView();
            D = obj.Drawn;
            if ~isempty(D) && abs(obj.TWidth - oldWidth) <= 1e-9 * oldWidth ...
                    && obj.TStart >= D.span(1) - 1e-12 && obj.TStart + obj.TWidth <= D.span(2) + 1e-12
                % Inside what is drawn: move the limits only.
                obj.Axes.XLim = [obj.TStart, obj.TStart + obj.TWidth];
                obj.placeScale();
                obj.updateOverviewView();
                obj.notifyView();
                return
            end
            obj.requestRender();
        end

        function zoomTime(obj, f, anchor)
            %zoomTime  The view F times wider, ANCHOR (s; default the centre) staying put.
            if nargin < 3 || isempty(anchor) || ~isfinite(anchor)
                anchor = obj.TStart + obj.TWidth / 2;
            end
            anchor = min(max(anchor, obj.TStart), obj.TStart + obj.TWidth);
            w = clampWidth(obj, obj.TWidth * f);
            obj.setView(anchor - (anchor - obj.TStart) * w / obj.TWidth, w);
        end

        function panTime(obj, frac)
            %panTime  Move the view by FRAC of its width.
            obj.setView(obj.TStart + frac * obj.TWidth, obj.TWidth);
        end

        function scaleVoltage(obj, f)
            %scaleVoltage  Traces F times taller.
            obj.setSpacing(obj.Spacing / f);
        end

        function setSpacing(obj, s)
            %setSpacing  S source units (microvolts) between neighbouring lanes.
            if ~(s > 0 && isfinite(s)); return; end
            obj.Spacing = s;
            obj.AutoPending = false;
            obj.requestRender();
        end

        function autoScale(obj)
            %autoScale  Pick Spacing from the signal in view (and draw).
            obj.AutoPending = true;
            obj.requestRender();
        end

        function scrollLanes(obj, n)
            %scrollLanes  Move the lanes shown by N (positive = further down).
            obj.setFirstLane(obj.FirstLane + n);
        end

        function setFirstLane(obj, k)
            %setFirstLane  Show lanes from K.
            k = min(max(1, round(k)), max(1, obj.NumLanes - obj.VisibleLanes + 1));
            if k == obj.FirstLane; return; end
            obj.FirstLane = k;
            obj.requestRender();
        end

        function setVisibleLanes(obj, n)
            %setVisibleLanes  Show N lanes at once.
            obj.VisibleLanes = max(1, round(n));
            obj.FirstLane = min(obj.FirstLane, max(1, obj.NumLanes - obj.VisibleLanes + 1));
            obj.requestRender();
        end

        function resetView(obj)
            %resetView  DefaultWidth from the current start, top lane, automatic scale.
            obj.FirstLane = 1;
            obj.TWidth = obj.DefaultWidth;
            obj.AutoPending = true;
            obj.clampView();
            obj.requestRender();
        end

        function seekOverview(obj, t)
            %seekOverview  Centre the view on T seconds.
            obj.setView(t - obj.TWidth / 2, obj.TWidth);
        end

        %% --- input -------------------------------------------------------------
        function handleScroll(obj, count, mods, t)
            %handleScroll  A wheel turn of COUNT notches with modifiers MODS at time T.
            mods = string(mods);
            if any(mods == "control" | mods == "command")
                obj.scaleVoltage(1.25 ^ (-count));
            elseif any(mods == "shift")
                obj.scrollLanes(sign(count) * max(1, round(obj.VisibleLanes / 8)) * abs(count));
            else
                obj.zoomTime(1.25 ^ count, t);
            end
        end

        function tf = handleKey(obj, key, mods)
            %handleKey  Act on KEY (a KeyData.Key) with modifiers MODS; TF = taken.
            mods = string(mods);
            tf = true;
            shift = any(mods == "shift");
            ctrl = any(mods == "control" | mods == "command");
            switch string(key)
                case "rightarrow"
                    if shift; obj.zoomTime(1 / 1.5); elseif ctrl; obj.panTime(1); else; obj.panTime(0.25); end
                case "leftarrow"
                    if shift; obj.zoomTime(1.5); elseif ctrl; obj.panTime(-1); else; obj.panTime(-0.25); end
                case "pagedown"
                    obj.panTime(1);
                case "pageup"
                    obj.panTime(-1);
                case "uparrow"
                    if shift; obj.scrollLanes(-1); else; obj.scaleVoltage(1.25); end
                case "downarrow"
                    if shift; obj.scrollLanes(1); else; obj.scaleVoltage(1 / 1.25); end
                case {"equal", "add"}
                    obj.scaleVoltage(1.25);
                case {"hyphen", "subtract"}
                    obj.scaleVoltage(1 / 1.25);
                case "home"
                    obj.setView(0, obj.TWidth);
                case "end"
                    obj.setView(obj.TotalDuration - obj.TWidth, obj.TWidth);
                case "a"
                    obj.autoScale();
                case "r"
                    obj.resetView();
                otherwise
                    tf = false;
            end
        end

        function beginDrag(obj, point)
            %beginDrag  Start panning at POINT (figure pixels).
            pp = plotPixels(obj.Axes);
            obj.Drag = struct('p0', point(1:2), 't0', obj.TStart, 'lane0', obj.FirstLane, ...
                'secPerPix', obj.TWidth / max(pp(3), 1), 'lanesPerPix', obj.VisibleLanes / max(pp(4), 1), ...
                'moved', false);
        end

        function dragTo(obj, point)
            %dragTo  Pan so the content follows the pointer to POINT (figure pixels).
            D = obj.Drag;
            if isempty(D); return; end
            d = point(1:2) - D.p0;
            obj.Drag.moved = D.moved || any(abs(d) >= 2);
            lane = D.lane0 + round(d(2) * D.lanesPerPix);
            if lane ~= obj.FirstLane && obj.NumLanes > obj.VisibleLanes
                obj.FirstLane = min(max(1, lane), max(1, obj.NumLanes - obj.VisibleLanes + 1));
                obj.Drawn = [];
            end
            obj.setView(D.t0 - d(1) * D.secPerPix, obj.TWidth);
        end

        function moved = endDrag(obj)
            %endDrag  Finish a pan; MOVED is false for a click that did not move.
            moved = ~isempty(obj.Drag) && obj.Drag.moved;
            obj.Drag = [];
        end

        function tf = isOver(obj, fig, ax)
            %isOver  True when FIG's pointer is inside AX (default the trace axes).
            if nargin < 3; ax = obj.Axes; end
            tf = false;
            if isempty(ax) || ~isvalid(ax); return; end
            pp = getpixelposition(ax, true);
            cp = fig.CurrentPoint;
            tf = cp(1) >= pp(1) && cp(1) <= pp(1) + pp(3) && cp(2) >= pp(2) && cp(2) <= pp(2) + pp(4);
        end

        %% --- drawing -------------------------------------------------------------
        function requestRender(obj)
            %requestRender  Draw soon, merging requests that come faster than RenderDelay.
            if obj.RenderDelay <= 0
                obj.render();
                return
            end
            if isempty(obj.Timer) || ~isvalid(obj.Timer)
                obj.Timer = timer('ExecutionMode', 'singleShot', 'StartDelay', obj.RenderDelay, ...
                    'Name', 'EphysTraceViewer', 'ObjectVisibility', 'off', ...
                    'TimerFcn', @(~, ~) onTimer(obj));
            end
            if strcmp(obj.Timer.Running, 'off')
                start(obj.Timer);
            end
        end

        function render(obj)
            %render  Draw the view now (reading what is not in memory).
            if ~isempty(obj.Timer) && isvalid(obj.Timer) && strcmp(obj.Timer.Running, 'on')
                stop(obj.Timer);
            end
            ax = obj.Axes;
            if ~isvalid(ax); return; end
            tic0 = tic;
            R = struct('bin', NaN, 'read', false, 'seconds', 0, 'nSpikes', 0, ...
                'styles', strings(1, 0), 'notes', strings(1, 0), 'error', "");
            obj.clampView();
            lanes = obj.laneTable();
            vis = obj.FirstLane : min(obj.NumLanes, obj.FirstLane + obj.VisibleLanes - 1);
            msg = "";
            T = [];                                    % the trace samples drawn
            span = [obj.TStart - 0.5 * obj.TWidth, obj.TStart + 1.5 * obj.TWidth];
            span = [max(0, span(1)), min(obj.TotalDuration, span(2))];
            try
                if ~isempty(obj.Source) && ~isempty(obj.Channels)
                    [T, R] = obj.traceSlice(span, vis, lanes, R);
                    if ~isempty(T); span = T.span; end   % empty: a source with no samples
                end
            catch ME
                R.error = string(ME.message);
                msg = "Could not read " + obj.Source.Name + ": " + R.error;
                T = [];
            end
            if isempty(obj.Source) && isempty(lanes.kind)
                msg = "Nothing to show: pick a signal or a spike layer.";
            end
            obj.drawTraces(T, lanes, vis);
            R = obj.drawSpikes(T, lanes, vis, span, R);
            obj.drawShading(span, lanes);
            obj.drawBreaks(span, lanes, vis);
            obj.Drawn = struct('span', span);
            obj.Message.String = msg;

            % Axes: the view, the lanes shown, their names.
            ax.XLim = [obj.TStart, obj.TStart + obj.TWidth];
            if isempty(vis)
                ax.YLim = [-0.5 0.5];
                ax.YTick = [];
            else
                ax.YLim = [-(vis(end) - 1) - 0.5, -(vis(1) - 1) + 0.5];
                every = max(1, ceil(numel(vis) / 48));
                shown = vis(end:-every:1);
                shown = shown(shown >= vis(1));
                ax.YTick = -(shown - 1);
                ax.YTickLabel = lanes.label(shown);
            end
            obj.placeScale();
            obj.updateOverview();
            R.seconds = toc(tic0);
            obj.LastRender = R;
            obj.notifyView();
        end
    end

    methods (Static)
        function L = emptyLayers()
            %emptyLayers  The struct every spike layer has (no layers).
            L = struct('name', {}, 'kind', {}, 'style', {}, 'placement', {}, 'labels', {}, ...
                'channels', {}, 'colorIndex', {}, 'order', {}, 'show', {}, 't', {}, 'g', {}, 'k', {}, ...
                'wf', {}, 'template', {}, 'wfTimeMs', {}, 'templateUV', {}, 'winMs', {});
        end

        function L = unitLayer(units, opts)
            %unitLayer  A spike layer of sorted units (the readSortedUnits / readPhyUnits struct).
            %   Order= gives the units' lane order (default by peak channel,
            %   then id). Each unit's lane label is its class and id
            %   ("su042"); its channel is its peak recording channel; its
            %   waveform is its template on the peak channel.
            arguments
                units (1,1) struct
                opts.Order (1,:) double = []
                opts.Name (1,1) string = "Sorted units"
                opts.Style (1,1) string = "ticks"
                opts.Placement (1,1) string = "channels"
                opts.Palette (:,3) double = EphysTraceViewer.defaultPalette()
            end
            nU = numel(units.unitId);
            times = reshape(units.times, [], 1);
            labels = strings(1, nU);
            for u = 1:nU
                labels(u) = string(regexp(char(units.label(u)), '^[a-z]+\d+', 'match', 'once'));
                if labels(u) == ""; labels(u) = string(units.label(u)); end
            end
            order = opts.Order;
            if isempty(order)
                [~, order] = sortrows([double(units.channel(:)), double(units.unitId(:))]);
                order = order(:).';
            end
            rank(order) = 1:numel(order);
            tmpl = cell(1, nU);
            tms = [];
            uv = false;
            if isfield(units, 'templateWaveform') && numel(units.templateWaveform) == nU
                tmpl = reshape(units.templateWaveform, 1, []);
                tms = double(units.templateTimeMs(:)).';
                uv = isfield(units, 'templateUnits') && string(units.templateUnits) == "uV";
            end
            win = [-0.5 1];
            if ~isempty(tms)
                win = [max(-1, tms(1)), min(1.5, tms(end))];
            end
            L = makeLayer(opts.Name, "units", times, labels, double(units.channel(:)).', ...
                mod(rank - 1, size(opts.Palette, 1)) + 1, order);
            L.template = tmpl;
            L.wfTimeMs = tms;
            L.templateUV = uv;
            L.winMs = win;
            L.style = opts.Style;
            L.placement = opts.Placement;
        end

        function L = detectedLayer(detected, opts)
            %detectedLayer  A spike layer of detected spikes (the spikes file's DETECTED struct).
            %   One lane per channel, coloured by channel; the waveforms are
            %   the stored snippets (detected.wf) when there are any.
            arguments
                detected (1,1) struct
                opts.Name (1,1) string = "Detected spikes"
                opts.Style (1,1) string = "ticks"
                opts.Placement (1,1) string = "channels"
                opts.Palette (:,3) double = EphysTraceViewer.defaultPalette()
            end
            ts = reshape(detected.ts, [], 1);
            nC = numel(ts);
            ch = 1:nC;
            if isfield(detected, 'channels') && numel(detected.channels) == nC
                ch = double(detected.channels(:)).';
            end
            names = compose("ch%d", ch);
            if isfield(detected, 'channelNames') && numel(detected.channelNames) == nC
                names = reshape(string(detected.channelNames), 1, []);
            end
            L = makeLayer(opts.Name, "detected", ts, names, ch, ...
                mod(ch - 1, size(opts.Palette, 1)) + 1, 1:nC);
            win = [-0.5 1.5];
            tms = [];
            if isfield(detected, 'info') && isstruct(detected.info)
                if isfield(detected.info, 'windowMs') && numel(detected.info.windowMs) == 2
                    win = double(detected.info.windowMs(:)).';
                end
                if isfield(detected.info, 'waveformTimeMs')
                    tms = double(detected.info.waveformTimeMs(:)).';
                end
            end
            if isfield(detected, 'wf') && numel(detected.wf) == nC && any(~cellfun(@isempty, detected.wf))
                L.wf = reshape(detected.wf, 1, []);
                if isempty(tms) || numel(tms) ~= size(L.wf{find(~cellfun(@isempty, L.wf), 1)}, 2)
                    nW = size(L.wf{find(~cellfun(@isempty, L.wf), 1)}, 2);
                    tms = linspace(win(1), win(2), nW);
                end
            end
            L.wfTimeMs = tms;
            L.winMs = win;
            L.style = opts.Style;
            L.placement = opts.Placement;
        end

        function P = defaultPalette()
            %defaultPalette  Twelve spike colours, distinct from the grey traces.
            P = [0.00 0.45 0.74
                 0.85 0.33 0.10
                 0.47 0.67 0.19
                 0.49 0.18 0.56
                 0.93 0.69 0.13
                 0.30 0.75 0.93
                 0.64 0.08 0.18
                 0.00 0.60 0.50
                 0.90 0.40 0.70
                 0.55 0.35 0.15
                 0.20 0.20 0.80
                 0.60 0.60 0.00];
        end

        function s = niceSpacing(v)
            %niceSpacing  V rounded up to 1, 2 or 5 times a power of ten.
            if ~(v > 0 && isfinite(v)); s = 100; return; end
            e = 10 ^ floor(log10(v));
            m = v / e;
            steps = [1 2 5 10];
            s = steps(find(steps >= m - 1e-9, 1)) * e;
        end
    end

    methods (Access = private)
        function clampView(obj)
            % Keep the view inside the recording and its width inside the limits.
            obj.TWidth = clampWidth(obj, obj.TWidth);
            dur = obj.TotalDuration;
            obj.TStart = min(max(0, obj.TStart), max(0, dur - obj.TWidth));
            obj.VisibleLanes = max(1, obj.VisibleLanes);
            obj.FirstLane = min(max(1, obj.FirstLane), max(1, obj.NumLanes - obj.VisibleLanes + 1));
        end

        function notifyView(obj)
            if ~isempty(obj.ViewChangedFcn)
                obj.ViewChangedFcn(obj);
            end
        end

        function busy(obj, msg)
            if ~isempty(obj.BusyFcn)
                obj.BusyFcn(msg);
            end
        end

        %% lanes
        function L = laneTable(obj)
            % Every lane: kind (1 trace, 2 raster), column or layer + group, label.
            nC = numel(obj.Channels);
            R = rasterLanes(obj);
            L = struct();
            L.kind = [ones(1, nC), 2 * ones(1, numel(R))];
            L.col = [obj.Channels, zeros(1, numel(R))];
            L.layer = [zeros(1, nC), [R.layer]];
            L.group = [zeros(1, nC), [R.group]];
            names = strings(1, 0);
            if nC > 0
                names = obj.Source.ChannelNames(obj.Channels);
            end
            L.label = [names, string({R.label})];
            % The recording channel of each trace lane, for spikes.
            L.traceChannel = double.empty(1, 0);
            if nC > 0
                L.traceChannel = obj.Source.RecordingChannels(obj.Channels);
            end
            % Raster lane of each layer's group.
            L.rasterLane = cell(1, numel(obj.Layers));
            for i = 1:numel(obj.Layers)
                L.rasterLane{i} = zeros(1, numel(obj.Layers(i).labels));
            end
            for j = 1:numel(R)
                L.rasterLane{R(j).layer}(R(j).group) = nC + j;
            end
        end

        function y = laneExtent(obj)
            % [bottom top] of every lane, for shading that covers them all.
            y = [-(max(obj.NumLanes, 1) - 1) - 0.5, 0.5];
        end

        %% traces
        function [T, R] = traceSlice(obj, span, vis, lanes, R)
            % The samples of the visible trace lanes over SPAN, reduced to
            % about one min / max pair per pixel column.
            src = obj.Source;
            fs = src.Fs;
            pp = plotPixels(obj.Axes);
            px = max(200, pp(3));
            b = max(1, floor(obj.TWidth * fs / px));
            env = obj.ensureEnvelope(b);
            b = env.b;   % a reused envelope may be finer than asked
            R.bin = b;
            R.read = env.didRead;
            if isempty(env.mn)
                T = [];
                return
            end
            % Bins of the envelope inside SPAN.
            k0 = max(1, floor((span(1) * fs - env.r0) / b) + 1);
            k1 = min(size(env.mn, 1), ceil((span(2) * fs - env.r0) / b) + 1);
            if k1 < k0
                k1 = k0;
            end
            k0 = min(k0, size(env.mn, 1));
            tb = (env.r0 + ((k0:k1).' - 1) * b) / fs;
            traceVis = vis(lanes.kind(vis) == 1);
            [~, cols] = ismember(lanes.col(traceVis), env.set);
            mn = env.mn(k0:k1, cols) - env.offset(cols);
            mx = env.mx(k0:k1, cols) - env.offset(cols);
            T = struct('b', b, 'fs', fs, 'r0', env.r0 + (k0 - 1) * b, 'lanes', traceVis, ...
                'mn', mn, 'mx', mx, 'span', [tb(1), tb(end) + b / fs]);
            if obj.AutoPending
                obj.Spacing = obj.autoSpacing(env, cols);
                obj.AutoPending = false;
            end
            if b == 1
                T.x = tb;
                T.y = mn;
            else
                T.x = reshape([tb.'; tb.'], [], 1);
                T.y = reshape(permute(cat(3, mn, mx), [3 1 2]), 2 * size(mn, 1), []);
            end
        end

        function env = ensureEnvelope(obj, b)
            % The reduced samples covering the view plus its margin, at bin
            % size B: reused when they cover the view at about this
            % resolution, else reduced again from memory or the disk.
            src = obj.Source;
            fs = src.Fs;
            key = obj.dataKey();
            set = unique(obj.Channels);
            view = [floor(obj.TStart * fs), ceil((obj.TStart + obj.TWidth) * fs)];
            E = obj.Env;
            if ~isempty(E) && E.key == key && all(ismember(set, E.set)) && E.b <= b && E.b * 2 > b ...
                    && E.r0 <= view(1) && E.r0 + size(E.mn, 1) * E.b >= min(view(2), src.NumSamples)
                env = E;
                env.didRead = false;
                return
            end
            % One window of margin each side, less when that would read too much.
            rate = src.NumChannels;
            w = obj.TWidth * fs;
            m = min(1, max(0, (obj.MaxReadSamples / (rate * max(w, 1)) - 1) / 2));
            a = max(0, floor(view(1) - m * w));
            z = min(src.NumSamples, ceil(view(2) + m * w));
            a = floor(a / b) * b;
            [mn, mx, didRead] = obj.reduceRows(a, z, b, set, key);
            env = struct('key', key, 'b', b, 'r0', a, 'mn', mn, 'mx', mx, 'set', set, ...
                'offset', zeros(1, numel(set), 'single'), 'didRead', didRead);
            if obj.RemoveOffset && ~isempty(mn)
                k0 = max(1, floor((view(1) - a) / b) + 1);
                k1 = min(size(mn, 1), max(k0, ceil((view(2) - a) / b)));
                mid = (mn(k0:k1, :) + mx(k0:k1, :)) / 2;
                off = median(mid, 1, 'omitnan');
                off(~isfinite(off)) = 0;
                env.offset = off;
            end
            obj.Env = env;
        end

        function [mn, mx, didRead] = reduceRows(obj, a, z, b, set, key)
            % Rows [A, Z) of the channels SET, processed, as min / max per B rows.
            didRead = false;
            C = obj.Cache;
            if ~isempty(C) && C.key == key && all(ismember(set, C.set)) ...
                    && C.r0 <= a && C.r0 + size(C.X, 1) >= z
                [~, cols] = ismember(set, C.set);
                [mn, mx] = EphysTraceSource.binMinMax(C.X(a - C.r0 + 1 : z - C.r0, cols), b);
                return
            end
            src = obj.Source;
            didRead = true;
            total = (z - a) * src.NumChannels;
            if total > obj.PieceSamples * 4
                obj.busy(sprintf("Reading %.3g s of %s...", (z - a) / src.Fs, src.Name));
                cleaner = onCleanup(@() obj.busy(""));
            end
            if total <= obj.CacheSamples
                X = obj.readProcessed(a, z, set);
                obj.Cache = struct('key', key, 'r0', a, 'X', X, 'set', set);
                [mn, mx] = EphysTraceSource.binMinMax(X, b);
                return
            end
            % Too long to keep: read in pieces of whole bins and reduce each
            % (as stored, when nothing is done to the samples).
            plain = obj.Reference == "none" && ~(isfield(obj.Filter, 'type') && obj.Filter.type ~= "");
            P = max(b, floor(obj.PieceSamples / src.NumChannels / b) * b);
            nb = ceil((z - a) / b);
            mn = zeros(nb, numel(set), 'single');
            mx = mn;
            k = 0;
            for p = a:P:z - 1
                if plain
                    [pmn, pmx] = src.readMinMax(p, min(p + P, z) - p, b, set);
                else
                    X = obj.readProcessed(p, min(p + P, z), set);
                    [pmn, pmx] = EphysTraceSource.binMinMax(X, b);
                end
                mn(k + (1:size(pmn, 1)), :) = pmn;
                mx(k + (1:size(pmx, 1)), :) = pmx;
                k = k + size(pmn, 1);
            end
            mn = mn(1:k, :);
            mx = mx(1:k, :);
        end

        function X = readProcessed(obj, a, z, set)
            % Rows [A, Z) of the channels SET, display-referenced and filtered.
            src = obj.Source;
            pad = obj.filterPad();
            a0 = max(0, a - pad);
            z0 = min(src.NumSamples, z + pad);
            X = src.read(a0, z0 - a0);
            if ~isequal(set, 1:src.NumChannels)
                X = X(:, set);
            end
            if obj.Reference ~= "none" && size(X, 2) > 1
                if obj.Reference == "car"
                    X = X - mean(X, 2);
                else
                    X = X - median(X, 2);
                end
            end
            f = obj.Filter;
            if isstruct(f) && isfield(f, 'type') && f.type ~= "" && size(X, 1) > 12 * f.order
                X = EphysDataset().filterContinuous(X, Type=f.type, Cutoff=f.cutoff, ...
                    Order=f.order, Fs=src.Fs);
            end
            X = X(a - a0 + 1 : min(size(X, 1), z - a0), :);
        end

        function pad = filterPad(obj)
            % Samples read beyond each end so the display filter settles.
            pad = 0;
            f = obj.Filter;
            if ~isstruct(f) || ~isfield(f, 'type') || f.type == "" || isempty(obj.Source); return; end
            lo = min(f.cutoff);
            pad = round(obj.Source.Fs * min(1, max(0.01, 3 / lo)));
        end

        function k = dataKey(obj)
            % Changes whenever the processed samples would.
            f = obj.Filter;
            fk = "";
            if isstruct(f) && isfield(f, 'type') && f.type ~= ""
                fk = f.type + mat2str(f.cutoff) + "o" + f.order;
            end
            k = obj.Source.key() + "|" + fk + "|" + obj.Reference + "|" + obj.RemoveOffset;
            if obj.Reference ~= "none"
                k = k + "|" + strjoin(string(unique(obj.Channels)), ",");
            end
        end

        function s = autoSpacing(obj, env, cols)
            % Twice the 99th percentile of |signal| in view, across the lanes, rounded up.
            fs = obj.Source.Fs;
            k0 = max(1, floor((obj.TStart * fs - env.r0) / env.b) + 1);
            k1 = min(size(env.mn, 1), max(k0, ceil(((obj.TStart + obj.TWidth) * fs - env.r0) / env.b)));
            if isempty(cols); cols = 1:numel(env.set); end
            V = [env.mn(k0:k1, cols); env.mx(k0:k1, cols)] - env.offset(cols);
            a = zeros(1, size(V, 2));
            for j = 1:size(V, 2)
                v = sort(abs(V(:, j)));
                v = v(isfinite(v));
                if isempty(v); continue; end
                a(j) = v(max(1, ceil(0.99 * numel(v))));
            end
            a = median(a(a > 0));
            if isempty(a) || ~(a > 0)
                s = obj.Spacing;
            else
                s = EphysTraceViewer.niceSpacing(2 * a);
            end
        end

        function drawTraces(obj, T, lanes, vis) %#ok<INUSD>
            % The visible trace lanes: one line per lane colour, or the heatmap.
            ax = obj.Axes;
            nUsed = 0;
            if ~isempty(T) && ~isempty(T.lanes) && obj.Mode == "traces"
                colors = repmat(obj.TraceColor, numel(obj.Channels), 1);
                if ~isempty(obj.LaneColors); colors = obj.LaneColors; end
                laneColor = colors(T.lanes, :);
                [uc, ~, ci] = unique(laneColor, 'rows', 'stable');
                centre = -(T.lanes - 1);
                Y = centre + T.y / obj.Spacing;
                nP = numel(T.x);
                for c = 1:size(uc, 1)
                    j = find(ci == c);
                    XX = repmat([T.x; NaN], numel(j), 1);
                    YY = [Y(:, j); NaN(1, numel(j))];
                    h = obj.poolLine("TraceLines", c);
                    set(h, 'XData', XX, 'YData', YY(:), 'Color', uc(c, :), 'Visible', 'on');
                end
                nUsed = size(uc, 1);
                if nP == 0; nUsed = 0; end
            end
            for c = nUsed + 1:numel(obj.TraceLines)
                set(obj.TraceLines(c), 'XData', [], 'YData', [], 'Visible', 'off');
            end
            % Heatmap: each bin's extreme per lane.
            if ~isempty(T) && ~isempty(T.lanes) && obj.Mode == "heatmap"
                ext = T.mx;
                useMin = abs(T.mn) > abs(T.mx);
                ext(useMin) = T.mn(useMin);
                tb = T.x(1:(1 + (T.b > 1)):end);
                set(obj.Image, 'CData', ext.', 'XData', [tb(1), tb(end)], ...
                    'YData', [-(T.lanes(1) - 1), -(T.lanes(end) - 1)], 'Visible', 'on');
                colormap(ax, char(obj.Colormap));
                ax.CLim = [-1 1] * obj.Spacing;
            else
                obj.Image.Visible = 'off';
            end
        end

        function h = poolLine(obj, pool, i)
            % Line I of POOL ("TraceLines" | "SpikeLines"), made when it is new.
            H = obj.(pool);
            if i <= numel(H) && isvalid(H(i))
                h = H(i);
                return
            end
            width = 0.5;
            if pool == "SpikeLines"; width = 1.2; end
            h = line(obj.Axes, NaN, NaN, 'LineWidth', width, 'HitTest', 'off', 'PickableParts', 'none');
            H(i, 1) = h;
            obj.(pool) = H;
            obj.restack();
        end

        function restack(obj)
            % Front to back: text, scale, selection, spikes, traces, breaks, shading, heatmap.
            ax = obj.Axes;
            front = [obj.Message; obj.ScaleText; obj.ScaleLine; obj.SelectPatch; obj.SpikeLines(:); ...
                obj.TraceLines(:); obj.BreakLine; obj.ShadePatches(:); obj.Image];
            front = front(isgraphics(front));
            kids = ax.Children;
            others = kids(~ismember(kids, front));
            ax.Children = [front; others];
        end

        %% spikes
        function R = drawSpikes(obj, T, lanes, vis, span, R)
            % Ticks and waveforms of every layer, one line per palette colour.
            nPal = size(obj.Palette, 1);
            X = cell(nPal, 1);
            Y = cell(nPal, 1);
            visSet = false(1, max(numel(lanes.kind), 1));
            visSet(vis) = true;
            pp = plotPixels(obj.Axes);
            px = max(200, pp(3));
            haveTrace = ~isempty(T) && ~isempty(T.lanes) && obj.Mode == "traces";
            for i = 1:numel(obj.Layers)
                L = obj.Layers(i);
                if L.style == "off" || isempty(L.t); continue; end
                i0 = bsearch(L.t, span(1)) + 1;
                i1 = bsearch(L.t, span(2));
                idx = (i0:i1).';
                g = double(L.g(idx));
                raster = L.placement == "raster" || isempty(obj.Source);
                if raster
                    lane = lanes.rasterLane{i}(g);
                    lane = lane(:);
                else
                    % The first trace lane of each group's channel (0 = not shown).
                    [~, laneOfGroup] = ismember(L.channels, lanes.traceChannel);
                    lane = reshape(laneOfGroup(g), [], 1);
                end
                keep = lane > 0 & reshape(L.show(g), [], 1);
                keep(keep) = visSet(lane(keep));
                idx = idx(keep); g = g(keep); lane = lane(keep);
                t = L.t(idx);
                R.nSpikes = R.nSpikes + numel(idx);
                style = L.style;
                if style == "waveforms"
                    if numel(idx) > obj.MaxWaveforms
                        style = "ticks";
                        R.notes(end+1) = sprintf("%s: %d spikes in view, ticks shown (zoom in for waveforms)", ...
                            L.name, numel(idx));
                    elseif ~raster && ~(haveTrace && T.fs >= 1e4)
                        if haveTrace
                            R.notes(end+1) = L.name + ": waveforms need a spike-band trace (10 kHz or more), ticks shown";
                        end
                        style = "ticks";
                    elseif raster && all(cellfun(@isempty, [L.wf, L.template]))
                        style = "ticks";
                    end
                end
                R.styles(end+1) = style;
                ci = L.colorIndex(g);
                ci = ci(:);
                centre = -(lane - 1);
                if style == "ticks"
                    % One tick per lane, pixel column and colour.
                    col = floor((t - obj.TStart) / obj.TWidth * px);
                    [~, first] = unique([lane, col, ci], 'rows', 'stable');
                    t = t(first); centre = centre(first); ci = ci(first);
                    if raster
                        y0 = centre - 0.4; y1 = centre + 0.4;
                    elseif L.kind == "detected"
                        y0 = centre - 0.45; y1 = centre - 0.15;   % below: apart from units' ticks
                    else
                        y0 = centre + 0.15; y1 = centre + 0.45;
                    end
                    for c = unique(ci).'
                        s = ci == c;
                        X{c} = [X{c}; reshape([t(s), t(s), NaN(nnz(s), 1)].', [], 1)];
                        Y{c} = [Y{c}; reshape([y0(s), y1(s), NaN(nnz(s), 1)].', [], 1)];
                    end
                elseif ~raster
                    % Recolour the trace over each spike's window.
                    [xs, ys] = traceSegments(T, t, lane, L.winMs, obj.Spacing);
                    for c = unique(ci).'
                        s = ci == c;
                        X{c} = [X{c}; reshape(xs(:, s), [], 1)];
                        Y{c} = [Y{c}; reshape(ys(:, s), [], 1)];
                    end
                else
                    % The stored waveform on the spike's own lane.
                    [xs, ys] = obj.storedWaveforms(L, idx, t, centre);
                    for c = unique(ci).'
                        s = ci == c;
                        X{c} = [X{c}; reshape(xs(:, s), [], 1)];
                        Y{c} = [Y{c}; reshape(ys(:, s), [], 1)];
                    end
                end
            end
            n = 0;
            for c = 1:nPal
                if isempty(X{c}); continue; end
                n = n + 1;
                h = obj.poolLine("SpikeLines", n);
                set(h, 'XData', X{c}, 'YData', Y{c}, 'Color', obj.Palette(c, :), 'Visible', 'on');
            end
            for c = n + 1:numel(obj.SpikeLines)
                set(obj.SpikeLines(c), 'XData', [], 'YData', [], 'Visible', 'off');
            end
        end

        function [xs, ys] = storedWaveforms(obj, L, idx, t, centre)
            % [nW+1 x n] snippets (NaN row last): detected waveforms in
            % microvolts, templates in microvolts or scaled to 0.8 lane.
            tms = L.wfTimeMs(:);
            nW = numel(tms);
            n = numel(idx);
            ys = NaN(nW + 1, n);
            g = double(L.g(idx));
            k = double(L.k(idx));
            for j = 1:n
                if ~isempty(L.wf)
                    w = L.wf{g(j)};
                    if isempty(w) || k(j) > size(w, 1); continue; end
                    v = double(w(k(j), :)).' / obj.Spacing;
                else
                    w = L.template{g(j)};
                    if isempty(w); continue; end
                    v = double(w(:));
                    if L.templateUV
                        v = v / obj.Spacing;
                    else
                        v = 0.8 * v / max(abs(v));
                    end
                end
                if numel(v) == nW
                    ys(1:nW, j) = centre(j) + v;
                end
            end
            xs = [t(:).' + tms / 1e3; NaN(1, n)];
        end

        %% shading, breaks, scale, overview
        function drawShading(obj, span, lanes) %#ok<INUSD>
            S = obj.Shading;
            y = laneExtent(obj);
            for i = 1:numel(S)
                if i > numel(obj.ShadePatches) || ~isvalid(obj.ShadePatches(i))
                    obj.ShadePatches(i, 1) = patch(obj.Axes, 'XData', NaN, 'YData', NaN, ...
                        'EdgeColor', 'none', 'HitTest', 'off', 'PickableParts', 'none');
                    obj.restack();
                end
                iv = S(i).intervals;
                if ~isempty(iv)
                    iv = iv(iv(:, 2) >= span(1) & iv(:, 1) <= span(2), :);
                end
                h = obj.ShadePatches(i);
                if isempty(iv)
                    set(h, 'XData', NaN, 'YData', NaN, 'Visible', 'off');
                    continue
                end
                n = size(iv, 1);
                set(h, 'XData', [iv(:, 1) iv(:, 2) iv(:, 2) iv(:, 1)].', ...
                    'YData', repmat([y(1); y(1); y(2); y(2)], 1, n), ...
                    'FaceColor', S(i).color, 'FaceAlpha', S(i).alpha, 'Visible', 'on');
            end
            for i = numel(S) + 1:numel(obj.ShadePatches)
                set(obj.ShadePatches(i), 'XData', NaN, 'YData', NaN, 'Visible', 'off');
            end
        end

        function drawBreaks(obj, span, lanes, vis)
            b = obj.LaneBreaks(ismember(obj.LaneBreaks, vis) & obj.LaneBreaks < numel(obj.Channels));
            b = b(lanes.kind(b) == 1);
            nC = numel(obj.Channels);
            if any(lanes.kind(vis) == 2) && nC > 0 && ismember(nC, vis)
                b = [b, nC];               % between the traces and the rasters
            end
            if isempty(b)
                set(obj.BreakLine, 'XData', NaN, 'YData', NaN, 'Visible', 'off');
                return
            end
            y = -(b - 1) - 0.5;
            XX = repmat([span(1); span(2); NaN], 1, numel(b));
            YY = [y; y; NaN(1, numel(b))];
            set(obj.BreakLine, 'XData', XX(:), 'YData', YY(:), 'Visible', 'on');
        end

        function placeScale(obj)
            % A bar one lane tall at the view's right edge, labelled with Spacing.
            ax = obj.Axes;
            xl = ax.XLim;
            yl = ax.YLim;
            txt = spacingText(obj.Spacing, unitsOf(obj));
            if isempty(obj.Source) || isempty(obj.Channels)
                set(obj.ScaleLine, 'XData', NaN, 'YData', NaN);
                obj.ScaleText.String = "";
                return
            end
            x = xl(2) - 0.012 * diff(xl);
            top = yl(2) - 0.15;
            if obj.Mode == "heatmap"
                set(obj.ScaleLine, 'XData', NaN, 'YData', NaN);
                set(obj.ScaleText, 'Position', [x, top - 0.3, 0], 'String', "colour ±" + txt);
                return
            end
            h = min(1, 0.8 * diff(yl));
            set(obj.ScaleLine, 'XData', [x x], 'YData', [top - h, top]);
            set(obj.ScaleText, 'Position', [x - 0.006 * diff(xl), top - h / 2, 0], 'String', txt);
        end

        function updateRate(obj)
            % Forget the spike density; the next draw works it out (rate).
            obj.Rate = [];
        end

        function R = rate(obj)
            % Spike density of the layers shown over the whole recording,
            % for the overview strip (struct x, y; empty without spikes).
            if ~isempty(obj.Rate)
                R = obj.Rate;
                return
            end
            R = struct('x', NaN, 'y', NaN);
            obj.Rate = R;
            t = zeros(0, 1);
            for i = 1:numel(obj.Layers)
                L = obj.Layers(i);
                if L.style ~= "off"; t = [t; L.t(L.show(L.g))]; end %#ok<AGROW>
            end
            if isempty(t); return; end
            edges = linspace(0, obj.TotalDuration, 401);
            c = histcounts(t, edges);
            R = struct('x', edges(1:end-1) + diff(edges) / 2, 'y', 0.9 * c / max([c 1]));
            obj.Rate = R;
        end

        function updateOverview(obj)
            ov = obj.OverviewAxes;
            if isempty(ov) || ~isvalid(ov); return; end
            dur = obj.TotalDuration;
            ov.XLim = [0 dur];
            R = obj.rate();
            set(obj.OvRate, 'XData', R.x, 'YData', R.y);
            S = obj.Shading;
            for i = 1:numel(S)
                if i > numel(obj.OvShade) || ~isvalid(obj.OvShade(i))
                    obj.OvShade(i, 1) = patch(ov, 'XData', NaN, 'YData', NaN, 'EdgeColor', 'none', ...
                        'HitTest', 'off', 'PickableParts', 'none');
                end
                iv = S(i).intervals;
                if isempty(iv)
                    set(obj.OvShade(i), 'XData', NaN, 'YData', NaN);
                    continue
                end
                % At least a pixel wide, so a short period still shows.
                w = max(iv(:, 2) - iv(:, 1), dur / 1500);
                n = size(iv, 1);
                set(obj.OvShade(i), 'XData', [iv(:, 1), iv(:, 1) + w, iv(:, 1) + w, iv(:, 1)].', ...
                    'YData', repmat([0; 0; 1; 1], 1, n), 'FaceColor', S(i).color, 'FaceAlpha', 0.6);
            end
            for i = numel(S) + 1:numel(obj.OvShade)
                set(obj.OvShade(i), 'XData', NaN, 'YData', NaN);
            end
            obj.updateOverviewView();
        end

        function updateOverviewView(obj)
            ov = obj.OverviewAxes;
            if isempty(ov) || ~isvalid(ov); return; end
            % At least 0.4% of the strip wide, so a short view stays visible.
            w = max(obj.TWidth, obj.TotalDuration / 250);
            a = obj.TStart + obj.TWidth / 2 - w / 2;
            set(obj.OvView, 'XData', [a, a + w, a + w, a]);
        end
    end
end


function onTimer(obj)
if isvalid(obj)
    try
        obj.render();
    catch ME
        warning('EphysTraceViewer:Render', 'Drawing failed: %s', ME.message);
    end
end
end


function setupAxes(ax)
% Axes for a viewer: no built-in interactions (the viewer takes the wheel
% and the drags), manual limits, lane names in the ticks.
try
    ax.Toolbar.Visible = 'off';
catch
end
try
    disableDefaultInteractivity(ax);
catch
end
ax.Interactions = [];
hold(ax, 'on');
set(ax, 'XLimMode', 'manual', 'YLimMode', 'manual', 'Box', 'on', 'TickDir', 'out', ...
    'TickLabelInterpreter', 'none', 'YDir', 'normal', 'Layer', 'top');
end


function w = clampWidth(obj, w)
% A view no narrower than 20 samples (1 ms without a source), no wider
% than the recording or than MaxReadSamples lets one draw read.
dur = obj.TotalDuration;
lo = 1e-3;
hi = dur;
if ~isempty(obj.Source)
    lo = 20 / obj.Source.Fs;
    hi = min(dur, obj.MaxReadSamples / (obj.Source.NumChannels * obj.Source.Fs));
end
w = min(max(w, min(lo, hi)), hi);
end


function R = rasterLanes(obj)
% The lanes the layers placed on their own lanes add: layer, group, label.
R = struct('layer', {}, 'group', {}, 'label', {});
for i = 1:numel(obj.Layers)
    L = obj.Layers(i);
    if L.style == "off" || ~(L.placement == "raster" || isempty(obj.Source)); continue; end
    for g = L.order(L.show(L.order))
        R(end+1) = struct('layer', i, 'group', g, 'label', L.labels(g)); %#ok<AGROW>
    end
end
end


function L = makeLayer(name, kind, times, labels, channels, colorIndex, order)
% A layer from per-group spike times: every spike, sorted by time, with
% its group and its place in the group.
nG = numel(times);
n = cellfun(@numel, times);
t = zeros(sum(n), 1);
g = zeros(sum(n), 1, 'uint32');
k = zeros(sum(n), 1, 'uint32');
at = 0;
for j = 1:nG
    t(at + (1:n(j))) = double(times{j}(:));
    g(at + (1:n(j))) = j;
    k(at + (1:n(j))) = 1:n(j);
    at = at + n(j);
end
[t, s] = sort(t);
L = EphysTraceViewer.emptyLayers();
L(1).name = name;
L.kind = kind;
L.style = "ticks";
L.placement = "channels";
L.labels = reshape(string(labels), 1, []);
L.channels = reshape(double(channels), 1, []);
L.colorIndex = reshape(colorIndex, 1, []);
L.order = reshape(order, 1, []);
L.show = true(1, nG);
L.t = t;
L.g = g(s);
L.k = k(s);
L.wf = {};
L.template = {};
L.wfTimeMs = [];
L.templateUV = false;
L.winMs = [-0.5 1];
end


function i = bsearch(t, x)
% The number of elements of the sorted T below X.
lo = 0;
hi = numel(t);
while lo < hi
    mid = floor((lo + hi + 1) / 2);
    if t(mid) < x
        lo = mid;
    else
        hi = mid - 1;
    end
end
i = lo;
end


function pp = plotPixels(ax)
% The plot box [x y w h] in pixels: a uiaxes' InnerPosition is in pixels; a
% plain axes' may be normalized, and its Position is that box.
pp = ax.InnerPosition;
if isprop(ax, 'Units') && ~strcmp(ax.Units, 'pixels')
    pp = getpixelposition(ax);
end
end


function [xs, ys] = traceSegments(T, t, lane, winMs, spacing)
% The drawn trace over each spike's window ([nPts+1 x n], NaN row last):
% the points of the spike's lane from T+winMs(1) to T+winMs(2).
n = numel(t);
m = 1 + (T.b > 1);                         % points per bin
nb = size(T.mn, 1);
row = round((t + winMs(1) / 1e3) * T.fs);  % the window's first sample (0-based)
first = floor((row - T.r0) / T.b) + 1;
L = max(1, ceil(diff(winMs) / 1e3 * T.fs / T.b) + 1);
B = first(:).' + (0:L - 1).';              % [L x n] bins
B = min(max(B, 1), nb);
if m == 1
    P = B;
else
    P = reshape(permute(cat(3, 2 * B - 1, 2 * B), [3 1 2]), 2 * L, n);
end
[~, col] = ismember(lane(:).', T.lanes);
centre = -(lane(:).' - 1);
nP = numel(T.x);
ys = centre + T.y(P + (col - 1) * nP) / spacing;
xs = T.x(P);
if n == 1; xs = xs(:); ys = ys(:); end
xs = [xs; NaN(1, n)];
ys = [ys; NaN(1, n)];
end


function u = unitsOf(obj)
u = "uV";
if ~isempty(obj.Source); u = obj.Source.Units; end
end


function s = spacingText(v, units)
% "200 uV", "1.5 mV", "0.2 V".
if units == "V"
    s = sprintf('%.3g V', v);
elseif v >= 1000
    s = sprintf('%.3g mV', v / 1000);
else
    s = sprintf('%.3g uV', v);
end
end
