classdef AnalysisCopyDialog < handle
    % AnalysisCopyDialog  Copy the files EphysAnalysisApp needs to another folder.
    %   A window that copies, for the chosen datasets, just the processed
    %   files the analysis app reads (DatasetOutputs.analysisFiles) into
    %   <folder>/<dataset key>, the layout the Transfer section writes, so
    %   EphysAnalysisApp("<folder>") on another computer analyses them
    %   without the recordings. The copy runs in the background
    %   (OutputTransfer: robocopy, Windows only) and the window follows it.
    %
    %     dlg = AnalysisCopyDialog(project.Datasets(1:3), Destination="E:\for_laptop");
    %     dlg.start();           % the Copy button
    %     dlg.wait();            % until the copy is over
    %
    %   What is copied is set in the window: the signals' extract files
    %   (the smallest is always there, for the digital events), the detected
    %   spikes, the sorted units (the files the readers use, or the whole
    %   sorting folder), the sorted binary the unit waveforms are cut from
    %   (large; templates are drawn without it), and the probe .json (put
    %   beside the manifest, where the copy finds it). The manifest and
    %   <Name>_behavior.mat are always copied. The datasets table lists
    %   each dataset's files and size, and what is missing; untick a row to
    %   leave a dataset out. Settings are remembered (AppPrefs group
    %   AnalysisCopyDialog).
    %
    %   Properties: Fig, Datasets, Transfer (the OutputTransfer once
    %   started, [] before), Running. Methods: refresh, start, stop, wait,
    %   options, delete. Opened by EphysPipelineApp (File -> Copy files for
    %   the analysis app...; onCopyForAnalysis).
    %
    %   See also DatasetOutputs.analysisFiles, OutputTransfer, EphysAnalysisApp.

    properties (Constant)
        PrefGroup = "AnalysisCopyDialog"
    end

    properties (Constant, Access = private)
        % The settings the window opens with, until the user has chosen others.
        Defaults = struct('Signals', ["LFP" "MUA" "AUX"], 'Spikes', true, 'Sorting', "essential", ...
            'SortedData', false, 'Probe', true, 'IfExists', "overwrite", 'Hash', false)
    end

    properties (SetAccess = private)
        Fig                      % the uifigure
        Datasets = []            % the EphysDataset objects offered
        Transfer = []            % the OutputTransfer of the copy, [] before it starts
        Files cell = {}          % per dataset: the analysisFiles table
        Notes cell = {}          % per dataset: what is missing (strings)
    end

    properties (Dependent)
        Running                  % a copy is in flight
    end

    properties (Access = private)
        Outs cell = {}           % per dataset: its DatasetOutputs
        Keys string = string.empty(1, 0)   % per dataset: its folder below the destination
        Tmr = []                 % the timer that follows the copy
        Tick = false             % tick() is running
        Ctl = struct()           % the controls
    end

    methods
        function obj = AnalysisCopyDialog(datasets, opts)
            %AnalysisCopyDialog  The window for DATASETS (EphysDataset objects).
            %   dlg = AnalysisCopyDialog(DATASETS, Destination=, Parent=, Visible=)
            %   Destination is the folder shown first (default: the last one
            %   used), Parent a figure to open the window over.
            arguments
                datasets (1,:)
                opts.Destination (1,1) string = ""
                opts.Parent = []
                opts.Visible (1,1) logical = true
            end
            obj.Datasets = datasets;
            n = numel(datasets);
            obj.Outs = cell(1, n);
            obj.Files = cell(1, n);
            obj.Notes = cell(1, n);
            obj.Keys = strings(1, n);
            for k = 1:n
                obj.Keys(k) = EphysPipeline.transferKey(datasets(k));
            end
            obj.build(opts.Parent, opts.Visible);
            obj.loadPrefs(opts.Destination);
            obj.refresh();
        end

        function tf = get.Running(obj)
            tf = ~isempty(obj.Transfer) && ~obj.Transfer.Done;
        end

        function o = options(obj)
            %options  The settings in the window: Signals, Spikes, Sorting, SortedData, Probe, IfExists, Verify.
            c = obj.Ctl;
            sig = ["LFP" "MUA" "SPIKE" "AUX"];
            on = arrayfun(@(b) logical(b.Value), c.Signals);
            o = struct('Signals', sig(on), ...
                'Spikes', logical(c.Spikes.Value), ...
                'Sorting', string(c.Sorting.Value), ...
                'SortedData', logical(c.SortedData.Value), ...
                'Probe', logical(c.Probe.Value), ...
                'IfExists', string(c.IfExists.Value), ...
                'Verify', ternary(logical(c.Hash.Value), "hash", "size"));
        end

        function refresh(obj, opts)
            %refresh  List the files for the current settings (Rescan=true looks at the disk again).
            arguments
                obj (1,1) AnalysisCopyDialog
                opts.Rescan (1,1) logical = false
            end
            if obj.Running; return; end
            o = obj.options();
            args = {'Signals', o.Signals, 'Spikes', o.Spikes, 'Sorting', o.Sorting, ...
                'SortedData', o.SortedData, 'Probe', o.Probe};
            prior = obj.ticked();
            obj.busy(true);
            restore = onCleanup(@() obj.busy(false));
            n = numel(obj.Datasets);
            copyCol = true(n, 1);
            nFiles = zeros(n, 1);
            bytes = zeros(n, 1);
            notes = strings(n, 1);
            for k = 1:n
                try
                    if isempty(obj.Outs{k}) || opts.Rescan
                        obj.Outs{k} = obj.Datasets(k).outputs();
                    end
                    [T, nt] = obj.Outs{k}.analysisFiles(args{:});
                catch ME
                    T = table(strings(0, 1), strings(0, 1), strings(0, 1), zeros(0, 1), ...
                        'VariableNames', {'Kind', 'Path', 'Base', 'Bytes'});
                    nt = "cannot list the files: " + string(ME.message);
                end
                obj.Files{k} = T;
                obj.Notes{k} = nt;
                nFiles(k) = height(T);
                bytes(k) = sum(T.Bytes);
                notes(k) = strjoin(nt, "; ");
                if ~isempty(prior) && numel(prior) == n; copyCol(k) = prior(k); end
                if height(T) == 0; copyCol(k) = false; end
            end
            size_ = arrayfun(@OutputTransfer.bytesText, bytes);
            obj.Ctl.Table.Data = table(copyCol, obj.Keys.', nFiles, size_, strings(n, 1), notes, ...
                'VariableNames', {'Copy', 'Dataset', 'Files', 'Size', 'Status', 'Notes'});
            obj.summarize();
        end

        function start(obj)
            %start  Copy the ticked datasets' files to the destination (the Copy button).
            if obj.Running; return; end
            T = obj.Ctl.Table.Data;
            sel = find(T.Copy(:)).';
            if isempty(sel)
                obj.alert("Tick at least one dataset.");
                return
            end
            dest = strtrim(string(obj.Ctl.Dest.Value));
            if ~OutputTransfer.isFullPath(dest)
                obj.alert("Choose the destination folder: a full path, a drive letter or \\server\share.");
                return
            end
            o = obj.options();
            try
                X = OutputTransfer(dest, IfExists=o.IfExists, Verify=o.Verify, ...
                    LogFcn=@(msg) obj.say(msg));
                for k = sel
                    AnalysisCopyDialog.addFiles(X, obj.Keys(k), obj.Datasets(k), obj.Files{k});
                end
                X.close();
            catch ME
                obj.alert(string(ME.message));
                return
            end
            obj.savePrefs();
            obj.Transfer = X;
            T.Status(:) = "";
            T.Status(sel) = "queued";
            obj.Ctl.Table.Data = T;
            obj.setRunning(true);
            obj.say(sprintf("Copying the analysis files of %d dataset(s) to %s", numel(sel), dest));
            obj.Tmr = timer(ExecutionMode="fixedSpacing", Period=0.5, BusyMode="drop", ...
                TimerFcn=@(~, ~) obj.tick());
            start(obj.Tmr);
            obj.tick();
        end

        function stop(obj)
            %stop  Stop the copy; what is copied stays.
            if ~obj.Running; return; end
            obj.Transfer.cancel();
            obj.say("Stopping: what is copied stays.");
            obj.tick();
        end

        function wait(obj, timeout)
            %wait  Block until the copy is over (a test or script waiting on the window).
            if nargin < 2; timeout = 300; end
            t0 = tic;
            while obj.Running
                obj.tick();
                if toc(t0) > timeout
                    error('AnalysisCopyDialog:Timeout', 'The copy is not over after %g s.', timeout);
                end
                pause(0.2);
            end
        end

        function delete(obj)
            obj.stopTimer();
            if ~isempty(obj.Fig) && isvalid(obj.Fig)
                delete(obj.Fig);
            end
        end
    end

    methods (Static)
        function s = settings()
            %settings  The settings last used in the window, for a copy made without it.
            %   S = AnalysisCopyDialog.settings() has the fields of options()
            %   (Signals, Spikes, Sorting, SortedData, Probe, IfExists,
            %   Verify) and Destination ("" when none was ever chosen), from
            %   the AppPrefs group the window saves to when it copies or
            %   closes. A setting that was not saved has the window's default.
            D = AnalysisCopyDialog.Defaults;
            s = struct('Signals', D.Signals, 'Spikes', D.Spikes, 'Sorting', D.Sorting, ...
                'SortedData', D.SortedData, 'Probe', D.Probe, 'IfExists', D.IfExists, ...
                'Verify', ternary(D.Hash, "hash", "size"), 'Destination', "");
            g = char(AnalysisCopyDialog.PrefGroup);
            try
                if ~AppPrefs.ispref(g, 'Settings'); return; end
                p = AppPrefs.getpref(g, 'Settings');
                sig = ["LFP" "MUA" "SPIKE" "AUX"];
                if isfield(p, 'Signals'); s.Signals = sig(ismember(sig, string(p.Signals))); end
                if isfield(p, 'Spikes'); s.Spikes = logical(p.Spikes); end
                if isfield(p, 'SortedData'); s.SortedData = logical(p.SortedData); end
                if isfield(p, 'Probe'); s.Probe = logical(p.Probe); end
                if isfield(p, 'Hash'); s.Verify = ternary(logical(p.Hash), "hash", "size"); end
                if isfield(p, 'Sorting') && ismember(string(p.Sorting), ["essential" "all" "none"])
                    s.Sorting = string(p.Sorting);
                end
                if isfield(p, 'IfExists') && ismember(string(p.IfExists), ["overwrite" "skip" "version"])
                    s.IfExists = string(p.IfExists);
                end
                if isfield(p, 'Destination'); s.Destination = strtrim(string(p.Destination)); end
            catch
                % preferences are a convenience: what could not be read stays as set above
            end
        end

        function addFiles(X, key, dataset, F)
            %addFiles  Queue a dataset's analysis files on the OutputTransfer X.
            %   AnalysisCopyDialog.addFiles(X, KEY, DATASET, F) adds the
            %   files of F (the table DatasetOutputs.analysisFiles returns
            %   for DATASET) to X under KEY, one batch per Base, so a file
            %   keeps its path below its base folder.
            if isempty(F); return; end
            [bases, ~, g] = unique(F.Base, 'stable');
            for j = 1:numel(bases)
                X.add(key, F.Path(g == j).', Base=bases(j), Dataset=string(dataset.Name), ...
                    Label="files for the analysis app");
            end
        end
    end

    methods (Access = private)
        function build(obj, parent, visible)
            %build  The window.
            W = 860; H = 680;
            pos = [100 100 W H];
            if ~isempty(parent) && isvalid(parent)
                pp = parent.Position;
                pos(1:2) = pp(1:2) + max(0, (pp(3:4) - [W H]) / 2);
            end
            f = uifigure("Name", "Copy files for the analysis app", "Position", pos, ...
                "Visible", matlab.lang.OnOffSwitchState(visible), "Tag", "AnalysisCopyDialog", ...
                "CloseRequestFcn", @(~, ~) obj.onClose());
            obj.Fig = f;
            g = uigridlayout(f, [6 1], "RowHeight", {44, 30, 175, '1x', 62, 34}, ...
                "Padding", [12 12 12 12], "RowSpacing", 8);

            uilabel(g, "WordWrap", "on", "Text", ...
                "Copies just the processed files EphysAnalysisApp reads, for the ticked datasets, into " + ...
                "<folder>\<subject>\<session>. Open that folder with EphysAnalysisApp on another computer: " + ...
                "no recordings or other pipeline outputs are copied.");

            % --- destination
            r = uigridlayout(g, [1 3], "ColumnWidth", {'fit', '1x', 110}, "RowHeight", {30}, ...
                "Padding", [0 0 0 0]);
            uilabel(r, "Text", "Copy to", "FontWeight", "bold");
            obj.Ctl.Dest = uieditfield(r, "text", "Tooltip", ...
                "The folder the datasets' folders are made in (a full path, or \\server\share).");
            obj.Ctl.Browse = uibutton(r, "Text", "Browse...", "ButtonPushedFcn", @(~, ~) obj.onBrowse());

            % --- what to copy
            p = uipanel(g, "Title", "What to copy");
            og = uigridlayout(p, [5 6], "RowHeight", repmat({26}, 1, 5), ...
                "ColumnWidth", {'fit', 80, 80, 80, 80, '1x'}, "Padding", [10 6 10 6], "ColumnSpacing", 8);
            lbl = uilabel(og, "Text", "Signal files", "Tooltip", ...
                "The extract files holding these signals (a file with several is copied once). The smallest extract file is always copied: the digital events are in it.");
            lbl.Layout.Row = 1; lbl.Layout.Column = 1;
            sig = ["LFP" "MUA" "SPIKE" "AUX"];
            D = AnalysisCopyDialog.Defaults;
            obj.Ctl.Signals = gobjects(1, 4);
            for k = 1:4
                c = uicheckbox(og, "Text", sig(k), "Value", ismember(sig(k), D.Signals), ...
                    "ValueChangedFcn", @(~, ~) obj.refresh());
                c.Layout.Row = 1; c.Layout.Column = k + 1;
                obj.Ctl.Signals(k) = c;
            end
            obj.Ctl.Spikes = obj.optionBox(og, [2 2], [1 3], "Detected spikes", D.Spikes, ...
                "<Name>_spikes.mat: the plots with Source 'detected' (heatmaps, probe maps).");
            obj.Ctl.Probe = obj.optionBox(og, [2 2], [4 6], "Probe file (.json)", D.Probe, ...
                "The probe map, copied beside the manifest. Probe maps, depth order and shanks need it.");
            lbl = uilabel(og, "Text", "Sorted units");
            lbl.Layout.Row = 3; lbl.Layout.Column = 1;
            obj.Ctl.Sorting = uidropdown(og, "Items", ["Essential files" "Whole folder" "None"], ...
                "ItemsData", ["essential" "all" "none"], "Value", D.Sorting, ...
                "Tooltip", "Essential: spike times and clusters, templates, channel files, params.py, settings.json and the cluster tables - not the large feature files. Whole folder: everything in it (without the hidden .phy cache).", ...
                "ValueChangedFcn", @(~, ~) obj.refresh());
            obj.Ctl.Sorting.Layout.Row = 3; obj.Ctl.Sorting.Layout.Column = [2 3];
            obj.Ctl.SortedData = obj.optionBox(og, [3 3], [4 6], "Sorted binary (large)", D.SortedData, ...
                "The .bin / temp_wh.dat the sort read (params.py dat_path): the unit waveforms are cut from the spikes in it. Without it they are drawn from the templates.");
            lbl = uilabel(og, "Text", "If the folder has files");
            lbl.Layout.Row = 4; lbl.Layout.Column = [1 2];
            obj.Ctl.IfExists = uidropdown(og, "Items", ["Replace changed files" "Keep existing files" "Make a new _v2 folder"], ...
                "ItemsData", ["overwrite" "skip" "version"], "Value", D.IfExists, ...
                "Tooltip", "What to do when <folder>\<subject>\<session> already holds files: replace those that changed, copy only the missing ones, or copy into <session>_v2 (the analysis reads it as the same dataset).");
            obj.Ctl.IfExists.Layout.Row = 4; obj.Ctl.IfExists.Layout.Column = [3 5];
            obj.Ctl.Hash = uicheckbox(og, "Text", "Check the copies by checksum (slower)", "Value", D.Hash);
            obj.Ctl.Hash.Layout.Row = 5; obj.Ctl.Hash.Layout.Column = [1 5];

            % --- the datasets
            obj.Ctl.Table = uitable(g, "ColumnName", {'Copy', 'Dataset', 'Files', 'Size', 'Status', 'Notes'}, ...
                "ColumnEditable", [true false false false false false], ...
                "ColumnWidth", {50, 190, 50, 70, 100, 'auto'}, "RowName", {}, ...
                "CellEditCallback", @(~, ~) obj.summarize());

            % --- summary and progress
            sg = uigridlayout(g, [3 1], "RowHeight", {22, 10, 22}, "Padding", [0 0 0 0], "RowSpacing", 2);
            obj.Ctl.Summary = uilabel(sg, "Text", "");
            obj.Ctl.BarBack = uipanel(sg, "BackgroundColor", [0.85 0.87 0.9], "BorderType", "none");
            obj.Ctl.Bar = uipanel(obj.Ctl.BarBack, "BackgroundColor", [0.15 0.45 0.80], "BorderType", "none", ...
                "Position", [0 0 1 10]);
            obj.Ctl.Status = uilabel(sg, "Text", "");

            % --- buttons
            b = uigridlayout(g, [1 5], "ColumnWidth", {160, 140, 110, '1x', 110}, "Padding", [0 0 0 0]);
            obj.Ctl.Copy = uibutton(b, "Text", "Copy", "ButtonPushedFcn", @(~, ~) obj.start());
            obj.Ctl.Stop = uibutton(b, "Text", "Stop", "Enable", "off", "ButtonPushedFcn", @(~, ~) obj.stop());
            obj.Ctl.Rescan = uibutton(b, "Text", "Refresh", "Tooltip", "Look at the disk again.", ...
                "ButtonPushedFcn", @(~, ~) obj.refresh(Rescan=true));
            uilabel(b, "Text", "");
            obj.Ctl.Close = uibutton(b, "Text", "Close", "ButtonPushedFcn", @(~, ~) obj.onClose());
            for name = string(fieldnames(obj.Ctl)).'
                if name ~= "Signals"; obj.Ctl.(name).Tag = "acd_" + name; end
            end
            for k = 1:4
                obj.Ctl.Signals(k).Tag = "acd_" + sig(k);
            end
            styleButton([obj.Ctl.Browse obj.Ctl.Rescan obj.Ctl.Close]);
            styleButton(obj.Ctl.Copy, "primary");
            styleButton(obj.Ctl.Stop, "danger");
        end

        function c = optionBox(~, parent, row, col, text, value, tip)
            %optionBox  A checkbox in PARENT's grid cell ROW x COL.
            c = uicheckbox(parent, "Text", text, "Value", value, "Tooltip", tip);
            c.Layout.Row = row(1); c.Layout.Column = col;
        end

        function t = ticked(obj)
            %ticked  The Copy column as it is (logical per dataset), [] before the table is filled.
            t = [];
            T = obj.Ctl.Table.Data;
            if istable(T) && height(T) == numel(obj.Datasets); t = logical(T.Copy(:)); end
        end

        function summarize(obj)
            T = obj.Ctl.Table.Data;
            if ~istable(T) || height(T) == 0
                obj.Ctl.Summary.Text = "No datasets.";
                obj.Ctl.Copy.Enable = "off";
                return
            end
            sel = find(T.Copy(:)).';
            nf = 0; nb = 0;
            for k = sel
                nf = nf + height(obj.Files{k});
                nb = nb + sum(obj.Files{k}.Bytes);
            end
            obj.Ctl.Summary.Text = sprintf("%d of %d dataset(s) ticked: %d file(s), %s.", ...
                numel(sel), height(T), nf, OutputTransfer.bytesText(nb));
            obj.Ctl.Copy.Enable = matlab.lang.OnOffSwitchState(~isempty(sel) && ~obj.Running);
        end

        function tick(obj)
            %tick  Advance the copy and show where it is (the timer, and wait).
            X = obj.Transfer;
            if isempty(X) || obj.Tick; return; end
            obj.Tick = true;
            restore = onCleanup(@() obj.endTick());
            try
                X.poll();
            catch ME
                obj.say("Copy error: " + string(ME.message));
            end
            if ~isvalid(obj) || isempty(obj.Fig) || ~isvalid(obj.Fig); return; end
            info = X.progress();
            w = obj.Ctl.BarBack.InnerPosition(3);
            obj.Ctl.Bar.Position = [0 0 max(1, round(w * info.Fraction)) 10];
            obj.Ctl.Status.Text = OutputTransfer.progressText(info);
            T = obj.Ctl.Table.Data;
            for k = find(T.Status(:).' ~= "")
                [st, msg] = X.statusOf(obj.Keys(k));
                if st ~= ""; T.Status(k) = st; end
                if st == "error" || st == "cancelled"; T.Notes(k) = msg; end
            end
            obj.Ctl.Table.Data = T;
            if X.Done
                obj.stopTimer();
                obj.setRunning(false);
                failed = nnz(T.Status == "error");
                if X.Canceled
                    obj.Ctl.Status.Text = "Stopped. " + obj.Ctl.Status.Text;
                elseif failed > 0
                    obj.Ctl.Status.Text = sprintf("%d dataset(s) failed - see the Notes column.", failed);
                else
                    obj.Ctl.Status.Text = "Done: " + OutputTransfer.progressText(info);
                end
                obj.say(obj.Ctl.Status.Text);
            end
        end

        function endTick(obj)
            if isvalid(obj); obj.Tick = false; end
        end

        function setRunning(obj, tf)
            on = @(x) ternary(x, 'on', 'off');
            obj.Ctl.Copy.Enable = on(~tf);
            obj.Ctl.Stop.Enable = on(tf);
            obj.Ctl.Rescan.Enable = on(~tf);
            obj.Ctl.Dest.Enable = on(~tf);
            obj.Ctl.Browse.Enable = on(~tf);
            for c = [obj.Ctl.Signals obj.Ctl.Spikes obj.Ctl.Sorting obj.Ctl.SortedData obj.Ctl.Probe ...
                    obj.Ctl.IfExists obj.Ctl.Hash obj.Ctl.Table]
                c.Enable = on(~tf);
            end
            if ~tf; obj.summarize(); end
        end

        function stopTimer(obj)
            if ~isempty(obj.Tmr) && isvalid(obj.Tmr)
                stop(obj.Tmr);
                delete(obj.Tmr);
            end
            obj.Tmr = [];
        end

        function busy(obj, tf)
            if ~isempty(obj.Fig) && isvalid(obj.Fig)
                obj.Fig.Pointer = ternary(tf, "watch", "arrow");
                drawnow limitrate
            end
        end

        function say(~, msg)
            %say  A line of the copy for the MATLAB log.
            if nargin < 2; return; end
            fprintf('[analysis copy] %s\n', msg);
        end

        function alert(obj, msg)
            if ~isempty(obj.Fig) && isvalid(obj.Fig) && obj.Fig.Visible == "on"
                uialert(obj.Fig, msg, "Copy files for the analysis app");
            else
                warning('AnalysisCopyDialog:Refused', '%s', msg);
            end
        end

        function onBrowse(obj)
            start0 = char(obj.Ctl.Dest.Value);
            if isempty(start0) || ~isfolder(start0); start0 = pwd; end
            d = uigetdir(start0, "Choose the folder to copy the analysis files to");
            figure(obj.Fig);
            if isequal(d, 0); return; end
            obj.Ctl.Dest.Value = d;
        end

        function onClose(obj)
            if obj.Running
                answer = uiconfirm(obj.Fig, "A copy is still running. Stop it and close? " + ...
                    "What is copied stays.", "Copy files for the analysis app", ...
                    "Options", ["Stop and close" "Keep copying"], "DefaultOption", 2, "CancelOption", 2);
                if answer ~= "Stop and close"; return; end
                obj.Transfer.cancel();
            end
            obj.savePrefs();
            delete(obj);
        end

        function loadPrefs(obj, destination)
            g = char(AnalysisCopyDialog.PrefGroup);
            c = obj.Ctl;
            try
                if AppPrefs.ispref(g, 'Settings')
                    s = AppPrefs.getpref(g, 'Settings');
                    sig = ["LFP" "MUA" "SPIKE" "AUX"];
                    for k = 1:4
                        if isfield(s, 'Signals'); c.Signals(k).Value = ismember(sig(k), string(s.Signals)); end
                    end
                    setIf(c.Spikes, s, 'Spikes');
                    setIf(c.SortedData, s, 'SortedData');
                    setIf(c.Probe, s, 'Probe');
                    setIf(c.Hash, s, 'Hash');
                    setIfItem(c.Sorting, s, 'Sorting');
                    setIfItem(c.IfExists, s, 'IfExists');
                    if isfield(s, 'Destination'); c.Dest.Value = char(s.Destination); end
                end
            catch
                % preferences are a convenience
            end
            if destination ~= ""; c.Dest.Value = char(destination); end
        end

        function savePrefs(obj)
            try
                o = obj.options();
                s = struct('Signals', o.Signals, 'Spikes', o.Spikes, 'Sorting', o.Sorting, ...
                    'SortedData', o.SortedData, 'Probe', o.Probe, 'IfExists', o.IfExists, ...
                    'Hash', o.Verify == "hash", 'Destination', string(obj.Ctl.Dest.Value));
                AppPrefs.setpref(char(AnalysisCopyDialog.PrefGroup), 'Settings', s);
            catch
                % preferences are a convenience
            end
        end
    end
end


function setIf(control, s, field)
if isfield(s, field); control.Value = logical(s.(field)); end
end


function setIfItem(dd, s, field)
if isfield(s, field) && ismember(string(s.(field)), string(dd.ItemsData)); dd.Value = char(s.(field)); end
end


function v = ternary(c, a, b)
if c; v = a; else; v = b; end
end
