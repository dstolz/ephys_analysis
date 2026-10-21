classdef AppSplash < handle
%AppSplash  The small window an app shows while it starts: its name, version, step and a progress bar.
%   S = AppSplash(NAME, STEPS, WEIGHTS) opens a small window centered on
%   the screen with the app's NAME, its version (ephysVersion), the text of
%   the step under way and a progress bar. STEPS (string keys) are the
%   startup steps in order; WEIGHTS (one each, the seconds the step takes,
%   as measured) set the share of the bar each one fills, so the bar moves
%   at an even pace. The app builds its own figure hidden meanwhile, then
%   shows it and closes the splash (EphysPipelineApp, EphysAnalysisApp,
%   ChannelMapperApp).
%
%   S.step(KEY, TEXT) starts step KEY: the bar jumps to the end of the
%   steps before it (a step skipped is passed over) and TEXT shows. A KEY
%   not in STEPS shows TEXT and leaves the bar where it is.
%   S.progress(FRAC, TEXT) moves the bar FRAC (0-1) of the way through the
%   current step, and shows TEXT when given (a scan's dataset count).
%   S.close() closes the window; the startup is over (Active false) and
%   later calls do nothing. Calls on an empty AppSplash do nothing too, so
%   an app calls them whether or not it is starting (isActive).
%
%   S.alert(FIG, MESSAGE, TITLE, ...) is uialert held back while the app
%   starts (uialert refuses a hidden figure): close() shows the alerts
%   held, on the app's window shown by then. Closed or empty, S.alert is
%   uialert.
%
%   On Windows the window is a Windows Forms form (.NET), painted at each
%   step on its own: a uifigure would need drawnow, which also pushes the
%   app's hidden figure to the screen piece by piece and made the startup
%   a third slower. Elsewhere, or when .NET fails, it is a uifigure
%   (Window says which).
%
%   S = AppSplash(..., Show=false) opens no window: the steps are only
%   recorded. The apps start that way under -batch (the test runs), where
%   no one watches; their Splash= option sets it.
%
%   S.History lists the steps taken: Step, Text and Seconds (since the
%   splash opened, when the step started); the time spent in each step is
%   what WEIGHTS should hold.
%
%   See also EphysPipelineApp, EphysAnalysisApp, ephysVersion.

    properties (SetAccess = private)
        Name (1,1) string = ""
        Steps (1,:) string = string.empty(1, 0)    % the step keys, in order
        Weights (1,:) double = zeros(1, 0)         % each step's share of the bar (seconds measured)
        Window (1,1) string = ""                   % the window shown: "forms" (Windows), "figure", "" (none)
        Active (1,1) logical = true                % false once closed
        Current (1,1) string = ""                  % the step under way ("" before the first)
        Value (1,1) double = 0                     % how far the bar is (0-1)
        Text (1,1) string = ""                     % the step's text shown
        History table = table(string.empty(0, 1), string.empty(0, 1), zeros(0, 1), ...
            'VariableNames', ["Step" "Text" "Seconds"])
        Alerts cell = {}                           % the alerts held back until close (alert)
    end

    properties (Hidden, SetAccess = private)
        Form = []         % the Windows Forms form (Window "forms")
        Fig = []          % the uifigure (Window "figure")
        StepLabel = []    % the step's text: a Forms Label or a uilabel
        BarFill = []      % the bar's filled part, sized to Value: a Forms Panel or a uipanel
        BarWidth (1,1) double = 0
        BarHeight (1,1) double = 0
        Clock = []        % tic at construction
    end

    properties (Constant, Hidden)
        Size = [440 150]                     % the window, px (scaled by the screen's DPI on Windows)
        Background = [0.97 0.97 0.98]
        BarColor = [0.15 0.45 0.80]          % styleButton's "primary" blue
        TrackColor = [0.84 0.86 0.90]
    end

    methods
        function obj = AppSplash(name, steps, weights, opts)
            arguments
                name (1,1) string
                steps (1,:) string
                weights (1,:) double {mustBeNonnegative}
                opts.Show (1,1) logical = true
            end
            assert(numel(steps) == numel(weights), 'AppSplash:Weights', 'One weight per step.');
            obj.Name = name;
            obj.Steps = steps;
            obj.Weights = weights;
            obj.Clock = tic;
            if ~opts.Show; return; end
            v = versionText();
            if ispc
                try
                    obj.buildForm(v);
                    obj.Window = "forms";
                    return
                catch
                    obj.closeForm();   % no .NET here: a uifigure instead
                end
            end
            obj.buildFigure(v);
            obj.Window = "figure";
        end

        function step(obj, key, text)
            %step  Start step KEY (one of Steps) and show TEXT.
            arguments
                obj AppSplash
                key (1,1) string
                text (1,1) string = ""
            end
            if ~isActive(obj); return; end
            obj.History(end+1, :) = {key, text, toc(obj.Clock)};
            k = find(obj.Steps == key, 1);
            if isempty(k)   % not a step of the list: the text only, the bar stays
                obj.show(obj.Value, text);
                return
            end
            obj.Current = key;
            obj.show(sum(obj.Weights(1:k-1)) / max(sum(obj.Weights), eps), text);
        end

        function progress(obj, frac, text)
            %progress  Move the bar FRAC of the way through the current step; TEXT when given.
            arguments
                obj AppSplash
                frac (1,1) double
                text string = string.empty
            end
            if ~isActive(obj) || obj.Current == ""; return; end
            k = find(obj.Steps == obj.Current, 1);
            total = max(sum(obj.Weights), eps);
            v = (sum(obj.Weights(1:k-1)) + min(max(frac, 0), 1) * obj.Weights(k)) / total;
            if isempty(text); text = obj.Text; end
            obj.show(v, text, true);   % a scan's many datasets: a uifigure redraws at most 20 times a second
        end

        function tf = isActive(obj)
            %isActive  True while the app is starting (not closed, not empty).
            tf = ~isempty(obj) && isvalid(obj) && obj.Active;
        end

        function tf = isOpen(obj)
            %isOpen  True while the window shows.
            tf = ~isempty(obj) && isvalid(obj) && ((~isempty(obj.Form) && ~obj.Form.IsDisposed) ...
                || (~isempty(obj.Fig) && isvalid(obj.Fig)));
        end

        function alert(obj, fig, message, title, varargin)
            %alert  uialert(FIG, MESSAGE, TITLE, ...), held back while the app starts.
            %   uialert refuses a hidden figure, and the app's window is
            %   hidden until it is built: while the splash is active the
            %   alert waits, and close() shows it on FIG (shown by then).
            %   Otherwise, and on an empty AppSplash, it shows at once.
            if isActive(obj)
                obj.Alerts{end+1} = [{fig, message, title}, varargin];
            else
                uialert(fig, message, title, varargin{:});
            end
        end

        function close(obj)
            %close  Close the window: the startup is over. The alerts held back show.
            if isempty(obj) || ~isvalid(obj); return; end
            obj.Active = false;
            obj.closeForm();
            if ~isempty(obj.Fig) && isvalid(obj.Fig)
                delete(obj.Fig);
            end
            held = obj.Alerts;
            obj.Alerts = {};
            for k = 1:numel(held)
                a = held{k};
                if isvalid(a{1}) && a{1}.Visible == "on"   % not when the startup failed and the window went
                    uialert(a{:});
                end
            end
        end

        function delete(obj)
            obj.closeForm();
            if ~isempty(obj.Fig) && isvalid(obj.Fig)
                delete(obj.Fig);
            end
        end
    end

    methods (Access = private)
        function buildForm(obj, v)
            %buildForm  The window as a borderless Windows Forms form, centered, a thin gray edge.
            NET.addAssembly('System.Windows.Forms');
            NET.addAssembly('System.Drawing');
            F = System.Windows.Forms.Form();
            obj.Form = F;
            g = F.CreateGraphics();
            s = double(g.DpiX) / 96;   % the screen's scale: sizes below are at 96 dpi
            g.Dispose();
            px = @(x) int32(round(x * s));
            sz = obj.Size;
            F.AutoScaleMode = System.Windows.Forms.AutoScaleMode.None;
            F.FormBorderStyle = System.Windows.Forms.FormBorderStyle.None;
            F.StartPosition = System.Windows.Forms.FormStartPosition.CenterScreen;
            F.ClientSize = System.Drawing.Size(px(sz(1)), px(sz(2)));
            F.Text = char(obj.Name);
            F.ShowInTaskbar = true;
            F.TopMost = true;
            F.BackColor = color([0.72 0.74 0.80]);   % the edge
            inner = System.Windows.Forms.Panel();
            inner.Location = System.Drawing.Point(1, 1);
            inner.Size = System.Drawing.Size(px(sz(1)) - 2, px(sz(2)) - 2);
            inner.BackColor = color(obj.Background);
            F.Controls.Add(inner);
            pad = 20;
            addLabel(inner, obj.Name, 22, true, [0.10 0.10 0.10], [pad 14 sz(1) - 2 * pad 32], px);
            addLabel(inner, v, 12, false, [0.40 0.40 0.45], [pad 48 sz(1) - 2 * pad 20], px);
            obj.StepLabel = addLabel(inner, "Starting ...", 14, false, [0.15 0.15 0.15], [pad 88 sz(1) - 2 * pad 22], px);
            track = System.Windows.Forms.Panel();
            track.Location = System.Drawing.Point(px(pad), px(116));
            track.Size = System.Drawing.Size(px(sz(1) - 2 * pad), px(12));
            track.BackColor = color(obj.TrackColor);
            inner.Controls.Add(track);
            fill = System.Windows.Forms.Panel();
            fill.Location = System.Drawing.Point(0, 0);
            fill.Size = System.Drawing.Size(0, px(12));
            fill.BackColor = color(obj.BarColor);
            track.Controls.Add(fill);
            obj.BarFill = fill;
            obj.BarWidth = double(px(sz(1) - 2 * pad));
            obj.BarHeight = double(px(12));
            F.Show();
            F.Refresh();
            System.Windows.Forms.Application.DoEvents();
        end

        function buildFigure(obj, v)
            %buildFigure  The window as a small uifigure, centered on the screen.
            sz = obj.Size;
            pad = 20;
            pos = [100 100 sz];
            try
                r = groot().ScreenSize;   % [x y w h]
                pos(1:2) = round(r(1:2) + (r(3:4) - sz) / 2);
            catch
            end
            obj.Fig = uifigure("Name", obj.Name, "Position", pos, "Resize", "off", ...
                "Visible", "off", "Tag", "AppSplash", "Color", obj.Background);
            obj.Fig.CloseRequestFcn = @(~,~) [];   % it closes when the app is up
            g = uigridlayout(obj.Fig, [4 1], "Padding", [pad 16 pad 18], "RowSpacing", 6, ...
                "RowHeight", {28, 18, '1x', 12}, "ColumnWidth", {'1x'}, "BackgroundColor", obj.Background);
            uilabel(g, "Text", obj.Name, "FontSize", 20, "FontWeight", "bold", "FontColor", [0.10 0.10 0.10]);
            uilabel(g, "Text", v, "FontSize", 11, "FontColor", [0.40 0.40 0.45]);
            obj.StepLabel = uilabel(g, "Text", "Starting ...", "FontSize", 12, ...
                "FontColor", [0.15 0.15 0.15], "VerticalAlignment", "bottom");
            track = uipanel(g, "BorderType", "none", "BackgroundColor", obj.TrackColor, ...
                "AutoResizeChildren", "off");
            obj.BarWidth = sz(1) - 2 * pad;
            obj.BarHeight = 12;
            obj.BarFill = uipanel(track, "BorderType", "none", "BackgroundColor", obj.BarColor, ...
                "Position", [1 1 1 12], "Visible", "off");
            obj.Fig.Visible = "on";
            drawnow;
        end

        function show(obj, value, text, limited)
            %show  Set the bar to VALUE and the text to TEXT, and paint them when a window shows (LIMITED: a uifigure's drawnow limitrate).
            if nargin < 4; limited = false; end
            obj.Value = value;
            obj.Text = text;
            w = round(value * obj.BarWidth);
            if obj.Window == "forms" && ~isempty(obj.Form) && ~obj.Form.IsDisposed
                try
                    if text ~= ""; obj.StepLabel.Text = char(text); end
                    obj.BarFill.Width = int32(w);
                    obj.Form.Refresh();
                    System.Windows.Forms.Application.DoEvents();   % keeps it answering Windows (no "not responding")
                catch
                end
            elseif ~isempty(obj.Fig) && isvalid(obj.Fig)
                if text ~= ""; obj.StepLabel.Text = text; end
                obj.BarFill.Position = [1 1 max(w, 1) obj.BarHeight];
                obj.BarFill.Visible = w >= 1;
                if limited
                    drawnow limitrate;
                else
                    drawnow;
                end
            end
        end

        function closeForm(obj)
            if isempty(obj.Form); return; end
            try
                if ~obj.Form.IsDisposed
                    obj.Form.Close();
                    obj.Form.Dispose();
                end
            catch
            end
            obj.Form = [];
        end
    end
end


function v = versionText()
%versionText  "Version 0.1.0, commit 29f8451" (ephysVersion), "" when it cannot tell.
%   Read once a session: git takes a moment, and a splash is no place to wait.
persistent cached
if isempty(cached)
    cached = "";
    try
        info = ephysVersion();
        parts = ["Version " + info.Version, "commit " + info.Commit];
        cached = strjoin(parts([info.Version info.Commit] ~= ""), ", ");
    catch
    end
end
v = cached;
end


function c = color(rgb)
%color  A System.Drawing.Color from MATLAB RGB (0-1).
c = System.Drawing.Color.FromArgb(int32(round(255 * rgb(1))), int32(round(255 * rgb(2))), int32(round(255 * rgb(3))));
end


function L = addLabel(parent, text, sizePx, bold, rgb, box, px)
%addLabel  A Forms Label in PARENT: TEXT at SIZEPX (96 dpi px), BOX [x y w h] (96 dpi px; PX scales).
L = System.Windows.Forms.Label();
L.AutoSize = false;
L.AutoEllipsis = true;
L.Location = System.Drawing.Point(px(box(1)), px(box(2)));
L.Size = System.Drawing.Size(px(box(3)), px(box(4)));
style = System.Drawing.FontStyle.Regular;
if bold; style = System.Drawing.FontStyle.Bold; end
L.Font = System.Drawing.Font('Segoe UI', single(double(px(sizePx))), style, System.Drawing.GraphicsUnit.Pixel);
L.ForeColor = color(rgb);
L.BackColor = System.Drawing.Color.Transparent;
L.Text = char(text);
parent.Controls.Add(L);
end
