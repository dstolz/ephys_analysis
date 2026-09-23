classdef ManifestViewerApp < handle
%ManifestViewerApp  Read-only viewer for a dataset's <Name>_manifest.json.
%   ManifestViewerApp(SRC) opens a window showing one dataset manifest
%   (schema in documentation/file-formats.md, "Dataset manifest"). SRC is an
%   EphysDataset, a manifest .json file, or a recording folder that holds a
%   *_manifest.json (the newest one when there are several). With no
%   argument a file dialog asks for the file.
%
%   ManifestViewerApp(SRC, DefaultProbeFile=F) names the probe a dataset
%   without one of its own is used with (the pipeline config's
%   Probe.DefaultProbeFile, as EphysPipeline.probeFor): the Summary names
%   it and the probe plot draws it.
%
%   Tabs:
%     Summary           every field by section, with a live check of each
%                       path it names (still on disk? and was it when the
%                       file was written?), probe vs recording channel
%                       counts, excluded and reference-excluded channels and
%                       artifact periods out of range, the trial pairing
%                       status, and when the behavior session started
%                       relative to the recording
%     Timeline & probe  the recording span with its manual artifact periods
%                       (and the behavior start), and the probe geometry
%                       with the excluded and reference-excluded channels
%                       marked
%     Tree              the decoded JSON as an expandable tree
%     JSON              the file's text
%
%   Reload re-reads the file. Rewrite (only when opened from an
%   EphysDataset) asks, then calls ds.writeManifest() and reloads;
%   V.rewrite() does the same without asking. The viewer never edits the
%   manifest itself.
%
%   V = ManifestViewerApp(SRC) returns the viewer; V.load(SRC) shows another
%   manifest in the same window. ManifestViewerApp.summaryRows(M) returns the
%   Summary table of a decoded manifest (Section, Field, Value, Check,
%   Level; Level is "", "ok", "warn" or "missing"), and takes
%   DefaultProbeFile= too.
%
%   See also EphysDataset.writeManifest, EphysDataset.applyManifest,
%   EphysPreprocessingApp.onViewManifest.

    properties (SetAccess = private)
        File string = ""                 % manifest shown ("" before one is loaded)
        Manifest = []                    % decoded JSON ([] when it did not parse)
        Dataset = EphysDataset.empty     % source dataset, when opened from one
        DefaultProbeFile string = ""     % probe used by a dataset without its own ("" = none)
        Rows table = table()             % the Summary table (summaryRows)
    end

    properties (Hidden)
        Fig
        PathField
        OpenButton
        ReloadButton
        FolderButton
        RewriteButton
        Tabs
        SummaryTable
        TimeAxes
        ProbeAxes
        Tree
        JsonArea
        StatusLabel
    end

    methods
        function obj = ManifestViewerApp(src, opts)
            arguments
                src = []
                opts.DefaultProbeFile (1,1) string = ""
            end
            obj.DefaultProbeFile = opts.DefaultProbeFile;
            obj.build();
            if isempty(src)
                obj.onOpen();
            else
                obj.load(src);
            end
            if nargout == 0
                clear obj
            end
        end

        function load(obj, src)
            %load  Show the manifest of an EphysDataset, a .json file or a folder.
            note = "";
            ds = EphysDataset.empty;
            if isa(src, 'EphysDataset')
                ds = src(1);
                file = string(ds.manifestFile());
                if ~isfile(file)
                    error('ManifestViewerApp:NotFound', ...
                        'Dataset %s has no manifest yet (%s). ds.writeManifest() writes one.', ds.Name, file);
                end
            else
                [file, note] = ManifestViewerApp.resolveFile(string(src));
            end
            obj.Dataset = ds;
            obj.File = file;
            obj.show(note);
        end

        function reload(obj)
            %reload  Re-read the manifest from disk.
            if obj.File ~= ""
                obj.show("");
            end
        end

        function tf = rewrite(obj)
            %rewrite  Write the manifest again from obj.Dataset (writeManifest) and reload.
            %   TF is false when there is no dataset or nothing was written:
            %   writeManifest keeps a manifest it cannot read (not JSON, an
            %   unknown schema) and writes none without the dataset's folder.
            %   The status line then says why.
            tf = false;
            if isempty(obj.Dataset); return; end
            lastwarn("");
            tf = obj.Dataset.writeManifest();
            why = string(lastwarn());
            obj.reload();
            if ~tf
                if why == ""; why = "its folder is not there: " + obj.Dataset.Folder; end
                obj.StatusLabel.Text = "Not rewritten: " + why;
                obj.StatusLabel.FontColor = [0.8 0 0];
            end
        end

        function delete(obj)
            if ~isempty(obj.Fig) && isvalid(obj.Fig)
                delete(obj.Fig);
            end
        end
    end

    methods (Static)
        function T = summaryRows(m, opts)
            %summaryRows  The Summary table of a decoded manifest struct.
            arguments
                m
                opts.DefaultProbeFile (1,1) string = ""
            end
            T = manifestSummary(m, opts.DefaultProbeFile);
        end

        function [file, note] = resolveFile(src)
            %resolveFile  The manifest file for a .json path or a folder.
            note = "";
            if isfolder(src)
                d = dir(fullfile(src, '*_manifest.json'));
                if isempty(d)
                    error('ManifestViewerApp:NotFound', 'No *_manifest.json in %s.', src);
                end
                [~, i] = max([d.datenum]);
                file = string(fullfile(d(i).folder, d(i).name));
                if numel(d) > 1
                    note = sprintf('%d manifests in the folder; showing the newest.', numel(d));
                end
            elseif isfile(src)
                file = src;
            else
                error('ManifestViewerApp:NotFound', 'No such file or folder: %s', src);
            end
        end
    end

    methods (Access = private)
        function build(obj)
            obj.Fig = uifigure('Name', 'Manifest viewer', 'Position', [120 120 980 680], ...
                'CloseRequestFcn', @(~,~) delete(obj));
            g = uigridlayout(obj.Fig, [3 1]);
            g.RowHeight = {32, '1x', 'fit'};
            g.Padding = [10 10 10 10];

            top = uigridlayout(g, [1 6]);
            top.ColumnWidth = {'fit', '1x', 'fit', 'fit', 'fit', 'fit'};
            top.Padding = [0 0 0 0];
            uilabel(top, 'Text', 'Manifest:');
            obj.PathField = uieditfield(top, 'text', 'Editable', 'off');
            obj.OpenButton = uibutton(top, 'Text', 'Open...', ...
                'Tooltip', 'Show another manifest (.json).', ...
                'ButtonPushedFcn', @(~,~) obj.onOpen());
            obj.ReloadButton = uibutton(top, 'Text', 'Reload', 'Enable', 'off', ...
                'Tooltip', 'Read the file again.', ...
                'ButtonPushedFcn', @(~,~) obj.reload());
            obj.FolderButton = uibutton(top, 'Text', 'Open folder', 'Enable', 'off', ...
                'Tooltip', 'Open the folder that holds the manifest.', ...
                'ButtonPushedFcn', @(~,~) obj.onOpenFolder());
            obj.RewriteButton = uibutton(top, 'Text', 'Rewrite', 'Enable', 'off', ...
                'Tooltip', 'Write the manifest again from the dataset''s current state (ds.writeManifest), then reload.', ...
                'ButtonPushedFcn', @(~,~) obj.onRewrite());
            styleButton([obj.OpenButton, obj.FolderButton, obj.RewriteButton]);
            styleButton(obj.ReloadButton, 'primary');

            obj.Tabs = uitabgroup(g);

            t = uitab(obj.Tabs, 'Title', 'Summary');
            tg = uigridlayout(t, [1 1]);
            obj.SummaryTable = uitable(tg, 'ColumnName', {'Section', 'Field', 'Value', 'Check'}, ...
                'ColumnWidth', {110, 150, '2x', '1x'}, 'RowName', {}, ...
                'ColumnSortable', false);

            t = uitab(obj.Tabs, 'Title', 'Timeline & probe');
            tg = uigridlayout(t, [2 1]);
            tg.RowHeight = {170, '1x'};
            obj.TimeAxes = uiaxes(tg);
            obj.ProbeAxes = uiaxes(tg);

            t = uitab(obj.Tabs, 'Title', 'Tree');
            tg = uigridlayout(t, [1 1]);
            obj.Tree = uitree(tg);

            t = uitab(obj.Tabs, 'Title', 'JSON');
            tg = uigridlayout(t, [1 1]);
            obj.JsonArea = uitextarea(tg, 'Editable', 'off', 'FontName', 'Courier New');

            obj.StatusLabel = uilabel(g, 'Text', 'Open a manifest to view it.', 'WordWrap', 'on');
        end

        function show(obj, note)
            %show  Read obj.File and fill every tab.
            txt = "";
            m = [];
            err = "";
            try
                txt = string(fileread(obj.File));
            catch ME
                err = "Cannot read the file: " + ME.message;
            end
            if err == ""
                try
                    m = jsondecode(txt);
                catch ME
                    err = "Cannot parse the JSON: " + ME.message;
                end
            end
            if err == "" && ~(isstruct(m) && isscalar(m))
                err = "The file does not hold a JSON object.";
                m = [];
            end
            obj.Manifest = m;

            [~, nm, ext] = fileparts(obj.File);
            obj.Fig.Name = "Manifest - " + nm + ext;
            obj.PathField.Value = obj.File;
            obj.JsonArea.Value = splitlines(txt);
            obj.ReloadButton.Enable = 'on';
            obj.FolderButton.Enable = 'on';
            obj.RewriteButton.Enable = matlab.lang.OnOffSwitchState(~isempty(obj.Dataset));

            if isempty(m)
                obj.Rows = table();
                obj.SummaryTable.Data = table();
                removeStyle(obj.SummaryTable);
                delete(obj.Tree.Children);
                cla(obj.TimeAxes, 'reset');
                cla(obj.ProbeAxes, 'reset');
                obj.StatusLabel.Text = strjoin([err, note], ' ');
                obj.StatusLabel.FontColor = [0.8 0 0];
                obj.Tabs.SelectedTab = findobj(obj.Tabs.Children, 'Title', 'JSON');
                return
            end

            obj.Rows = manifestSummary(m, obj.DefaultProbeFile);
            obj.renderSummary();
            obj.renderTimeline(m);
            obj.renderProbe(m);
            obj.renderTree(m);

            nMiss = nnz(obj.Rows.Level == "missing");
            nWarn = nnz(obj.Rows.Level == "warn");
            parts = sprintf('%s, updated %s.', txtOf(getf(m, 'schema', "")), txtOf(getf(m, 'updated', "")));
            if nMiss > 0; parts = [parts sprintf(' %d path(s) not found.', nMiss)]; end
            if nWarn > 0; parts = [parts sprintf(' %d warning(s).', nWarn)]; end
            if note ~= ""; parts = [parts ' ' char(note)]; end
            obj.StatusLabel.Text = parts;
            if nMiss + nWarn > 0
                obj.StatusLabel.FontColor = [0.65 0.4 0];
            else
                obj.StatusLabel.FontColor = [0 0 0];
            end
        end

        function renderSummary(obj)
            T = obj.Rows;
            D = T(:, {'Section', 'Field', 'Value', 'Check'});
            % Name each section once, on its first row.
            repeat = [false; T.Section(2:end) == T.Section(1:end-1)];
            D.Section(repeat) = "";
            obj.SummaryTable.Data = D;
            removeStyle(obj.SummaryTable);
            first = find(~repeat);
            if ~isempty(first)
                addStyle(obj.SummaryTable, uistyle('FontWeight', 'bold'), 'cell', [first ones(size(first))]);
            end
            r = find(T.Level == "missing");
            if ~isempty(r)
                addStyle(obj.SummaryTable, uistyle('BackgroundColor', [1 0.85 0.85], 'FontColor', [0 0 0]), 'row', r);
            end
            r = find(T.Level == "warn");
            if ~isempty(r)
                addStyle(obj.SummaryTable, uistyle('BackgroundColor', [1 0.95 0.75], 'FontColor', [0 0 0]), 'row', r);
            end
            r = find(T.Level == "ok");
            if ~isempty(r)
                addStyle(obj.SummaryTable, uistyle('FontColor', [0 0.55 0]), 'cell', [r 4 * ones(size(r))]);
            end
        end

        function renderTimeline(obj, m)
            ax = obj.TimeAxes;
            cla(ax, 'reset');
            dur = numOf(getf(m, 'metadata.duration_s', NaN));
            ma = artifactMatrix(getf(m, 'manual_artifacts', []));
            off = behaviorOffset(m);
            xmax = max([dur; ma(:)], [], 'omitnan');
            if isempty(xmax) || isnan(xmax) || xmax <= 0
                text(ax, 0.5, 0.5, 'No recording duration in the manifest', ...
                    'HorizontalAlignment', 'center', 'Units', 'normalized');
                ax.XTick = []; ax.YTick = [];
                return
            end
            hold(ax, 'on');
            if ~isnan(dur) && dur > 0
                patch(ax, [0 dur dur 0], [0 0 1 1], [0.82 0.82 0.82], 'EdgeColor', 'none');
            end
            for k = 1:height(ma)
                patch(ax, ma(k, [1 2 2 1]), [0 0 1 1], [0.85 0.15 0.15], ...
                    'FaceAlpha', 0.7, 'EdgeColor', 'none');
            end
            if ~isempty(ma)
                % Markers above the bar, so periods too short to see still show.
                plot(ax, mean(ma, 2), 1.08 * ones(height(ma), 1), 'v', ...
                    'Color', [0.85 0.15 0.15], 'MarkerFaceColor', [0.85 0.15 0.15]);
            end
            % The behavior start is drawn only when it falls in the recording;
            % otherwise the title gives it, so the axis stays on the recording.
            if ~isnan(off) && off >= 0 && off <= xmax
                xline(ax, off, '--', 'behavior start', 'Color', [0.1 0.35 0.75], ...
                    'LabelVerticalAlignment', 'bottom');
            end
            hold(ax, 'off');
            lo = min([0; ma(:)], [], 'omitnan');
            pad = 0.01 * (xmax - lo);
            xlim(ax, [lo - pad, xmax + pad]);
            ylim(ax, [0 1.2]);
            ax.YTick = [];
            xlabel(ax, 'Time (s)');
            tot = sum(ma(:, 2) - ma(:, 1));
            ttl = sprintf('Manual artifacts: %d period(s), %.3g s', height(ma), tot);
            if ~isnan(dur) && dur > 0
                ttl = sprintf('%s (%.2g%% of %s)', ttl, 100 * tot / dur, fmtDuration(dur));
            end
            if ~isnan(off) && off < 0
                ttl = sprintf('%s. Behavior started %.3g s before the recording', ttl, -off);
            elseif ~isnan(off) && off > xmax
                ttl = sprintf('%s. Behavior started %.3g s after the recording ended', ttl, off - xmax);
            end
            title(ax, ttl, 'FontWeight', 'normal');
        end

        function renderProbe(obj, m)
            % The dataset's own probe, else the default it is used with
            % (EphysPipeline.probeFor).
            ax = obj.ProbeAxes;
            cla(ax, 'reset');
            pf = txtOf(getf(m, 'probe.file', ""));
            isDefault = pf == "" && obj.DefaultProbeFile ~= "";
            if isDefault; pf = obj.DefaultProbeFile; end
            excl = EphysDataset.parseChannelList(txtOf(getf(m, 'exclude_channels', "")));
            refEx = EphysDataset.parseChannelList(txtOf(getf(m, 'reference_exclude.channels', "")));
            msg = "";
            p = [];
            if pf == ""
                msg = "No probe assigned";
            elseif ~isfile(pf)
                msg = "Probe file not found: " + pf;
            else
                p = readJsonFile(pf, ErrorOnFail=false);
                if ~isstruct(p) || ~isfield(p, 'xc') || ~isfield(p, 'yc')
                    msg = "Not a probe map (no xc / yc): " + pf;
                end
            end
            if msg ~= ""
                text(ax, 0.5, 0.5, msg, 'HorizontalAlignment', 'center', ...
                    'Units', 'normalized', 'Interpreter', 'none');
                ax.XTick = []; ax.YTick = [];
                if ~isempty(excl)
                    title(ax, sprintf('Excluded channels: %s', txtOf(getf(m, 'exclude_channels', ""))), ...
                        'FontWeight', 'normal', 'Interpreter', 'none');
                end
                return
            end

            xc = double(p.xc(:));
            yc = double(p.yc(:));
            n = numel(xc);
            ch = (1:n).';
            if isfield(p, 'chanMap') && numel(p.chanMap) == n
                ch = double(p.chanMap(:)) + 1;      % recording channel = chanMap + 1
            end
            isEx = ismember(ch, excl);
            isRef = ismember(ch, refEx);
            hold(ax, 'on');
            scatter(ax, xc(~isEx), yc(~isEx), 40, [0.2 0.4 0.8], 's', 'filled', 'DisplayName', 'in use');
            if any(isEx)
                scatter(ax, xc(isEx), yc(isEx), 70, [0.85 0.15 0.15], 'x', 'LineWidth', 2, ...
                    'DisplayName', 'excluded');
            end
            if any(isRef)
                scatter(ax, xc(isRef), yc(isRef), 110, [0.9 0.55 0.1], 'o', 'LineWidth', 1.5, ...
                    'DisplayName', 'left out of the reference');
            end
            if any(isEx) || any(isRef)
                legend(ax, 'Location', 'bestoutside');
            end
            if n <= 128
                text(ax, xc + 8, yc, string(ch), 'FontSize', 7, 'Color', [0.35 0.35 0.35]);
            end
            hold(ax, 'off');
            ax.DataAspectRatio = [1 1 1];
            padx = max(40, 0.05 * range(xc));
            pady = max(20, 0.03 * range(yc));
            xlim(ax, [min(xc) - padx, max(xc) + padx]);
            ylim(ax, [min(yc) - pady, max(yc) + pady]);
            xlabel(ax, 'x (\mum)');
            ylabel(ax, 'y (\mum)');
            [~, nm, ext] = fileparts(pf);
            ttl = sprintf('%s: %d contacts, %d excluded', nm + ext, n, nnz(isEx));
            if any(isRef)
                ttl = sprintf('%s, %d left out of the reference', ttl, nnz(isRef));
            end
            off = setdiff([excl(:); refEx(:)], ch);
            if ~isempty(off)
                ttl = sprintf('%s (%d listed channel(s) not on the probe)', ttl, numel(off));
            end
            if isDefault
                ttl = ttl + " (the config's default probe)";
            end
            title(ax, ttl, 'FontWeight', 'normal', 'Interpreter', 'none');
        end

        function renderTree(obj, m)
            delete(obj.Tree.Children);
            addTreeChildren(obj.Tree, m);
        end

        function onOpen(obj)
            start = pwd;
            if obj.File ~= ""; start = fileparts(obj.File); end
            [f, p] = uigetfile({'*_manifest.json', 'Dataset manifests'; '*.json', 'JSON files'}, ...
                'Open a dataset manifest', char(start));
            figure(obj.Fig);
            if isequal(f, 0); return; end
            try
                obj.load(fullfile(p, f));
            catch ME
                uialert(obj.Fig, ME.message, 'Cannot open');
            end
        end

        function onOpenFolder(obj)
            folder = fileparts(obj.File);
            if ispc
                winopen(folder);
            elseif ismac
                system(sprintf('open "%s"', folder));
            else
                system(sprintf('xdg-open "%s" &', folder));
            end
        end

        function onRewrite(obj)
            % The file is replaced by the dataset's in-memory state, which a
            % dataset built without applyManifest (not by a scan) lacks.
            if isempty(obj.Dataset); return; end
            uiconfirm(obj.Fig, ["Write the manifest again from " + obj.Dataset.Name + "'s current state?", ...
                "Its probe, exclusions, artifact periods, sorting and behavior entries replace the ones in the file."], ...
                'Rewrite manifest', 'Options', {'Rewrite', 'Cancel'}, ...
                'DefaultOption', 2, 'CancelOption', 2, ...
                'CloseFcn', @(~, e) obj.onRewriteAnswer(e));
        end

        function onRewriteAnswer(obj, e)
            if e.SelectedOption == "Rewrite" && ~obj.rewrite()
                uialert(obj.Fig, obj.StatusLabel.Text, 'Manifest not rewritten', 'Icon', 'warning');
            end
        end
    end
end

%% --- Summary ------------------------------------------------------------
function T = manifestSummary(m, defaultProbe)
R = strings(0, 5);

S = "General";
schema = txtOf(getf(m, 'schema', ""));
if ismember(schema, EphysDataset.ManifestSchemasAccepted)
    R = addRow(R, S, "Schema", schema, "ok", "read by EphysDataset");
else
    R = addRow(R, S, "Schema", schema, "warn", "not a schema EphysDataset reads");
end
R = addRow(R, S, "Name", txtOf(getf(m, 'name', "")));
[lv, ck] = pathCheck(txtOf(getf(m, 'folder', "")), "folder");
R = addRow(R, S, "Folder", txtOf(getf(m, 'folder', "")), lv, ck);
if isfield(m, 'recording_format'); R = addRow(R, S, "Recording format", txtOf(m.recording_format)); end
if isfield(m, 'reader');           R = addRow(R, S, "Reader", txtOf(m.reader)); end
upd = txtOf(getf(m, 'updated', ""));
R = addRow(R, S, "Updated", upd, "", ageText(upd));

nch = numOf(getf(m, 'metadata.num_channels', NaN));
dur = numOf(getf(m, 'metadata.duration_s', NaN));
if isfield(m, 'metadata') && isstruct(m.metadata)
    S = "Recording";
    md = m.metadata;
    R = addRow(R, S, "Sampling rate", fmtNum(numOf(getf(md, 'fs', NaN)), " Hz"));
    R = addRow(R, S, "Channels", fmtNum(nch, ""));
    R = addRow(R, S, "Duration", fmtDuration(dur));
    R = addRow(R, S, "Acquired", txtOf(getf(md, 'acq_date', "")));
    files = string(getf(md, 'files', strings(0, 1)));
    shown = strjoin(files(1:min(3, end)), ", ");
    if numel(files) > 3; shown = shown + sprintf(", ... (+%d)", numel(files) - 3); end
    R = addRow(R, S, "Files", shown, "", sprintf('%d file(s)', numel(files)));
end

if isfield(m, 'probe') && isstruct(m.probe)
    S = "Probe";
    pr = m.probe;
    pf = txtOf(getf(pr, 'file', ""));
    if pf == "" && defaultProbe == ""
        R = addRow(R, S, "File", "", "", "none assigned");
    elseif pf == ""
        % The default is used, never assigned (EphysPipeline.probeFor).
        R = addRow(R, S, "File", "", "", "none: the default probe is used");
        [lv, ck] = pathCheck(defaultProbe, "file");
        R = addRow(R, S, "Default probe", defaultProbe, lv, ck);
    else
        [lv, ck] = pathCheck(pf, "file", getf(pr, 'exists', []));
        R = addRow(R, S, "File", pf, lv, ck);
        pn = numOf(getf(pr, 'num_channels', NaN));
        lv = ""; ck = "";
        if ~isnan(pn) && ~isnan(nch) && pn > nch
            lv = "warn"; ck = sprintf('more than the recording''s %g', nch);
        elseif ~isnan(pn) && ~isnan(nch) && pn < nch
            ck = sprintf('recording has %g', nch);
        end
        R = addRow(R, S, "Channels", fmtNum(pn, ""), lv, ck);
        R = addRow(R, S, "Shanks", fmtNum(numOf(getf(pr, 'num_shanks', NaN)), ""));
        R = addRow(R, S, "Depth", fmtNum(numOf(getf(pr, 'depth_um', NaN)), " µm"));
        R = addRow(R, S, "Notes", txtOf(getf(pr, 'notes', "")));
    end
end

S = "Channels";
if isfield(m, 'exclude_channels')
    ex = txtOf(m.exclude_channels);
    [lv, ck] = channelCheck(ex, nch, "excluded");
    R = addRow(R, S, "Excluded", ex, lv, ck);
end
if isfield(m, 'reference_exclude') && isstruct(m.reference_exclude)
    re = m.reference_exclude;
    rc = txtOf(getf(re, 'channels', ""));
    [lv, ck] = channelCheck(rc, nch, "left out of the common reference");
    src = txtOf(getf(re, 'source', ""));
    switch src
        case "suggested"; ck = ck + ", suggested by the noise floor";
        case "manual";    ck = ck + ", set by hand";
        case "";          ck = "never set: the first referenced read suggests it";
        otherwise
            lv = "warn"; ck = "unknown source """ + src + """: applyManifest ignores it";
    end
    R = addRow(R, S, "Reference exclude", rc, lv, ck);
end

if isfield(m, 'manual_artifacts')
    S = "Manual artifacts";
    ma = artifactMatrix(m.manual_artifacts);
    tot = sum(ma(:, 2) - ma(:, 1));
    R = addRow(R, S, "Periods", sprintf('%d', height(ma)));
    val = sprintf('%.4g s', tot);
    if ~isnan(dur) && dur > 0; val = sprintf('%s (%.2g%% of the recording)', val, 100 * tot / dur); end
    R = addRow(R, S, "Total", val);
    bad = ma(:, 2) <= ma(:, 1) | ma(:, 1) < 0;
    if ~isnan(dur); bad = bad | ma(:, 2) > dur; end
    if any(bad)
        R = addRow(R, S, "Out of range", mat2str(find(bad).'), "warn", ...
            "periods that end before they start or fall outside the recording");
    end
end

if isfield(m, 'bin') && isstruct(m.bin)
    S = "Binary (.bin)";
    bf = txtOf(getf(m.bin, 'file', ""));
    was = isequal(getf(m.bin, 'exists', false), true);
    lv = ""; ck = "";
    if bf == ""
        % nothing to check
    elseif isfile(bf)
        lv = "ok"; ck = "found";
        if ~was; ck = "found (absent when written)"; end
    elseif was
        lv = "warn"; ck = "not found (present when written)";
    else
        ck = "not written yet";
    end
    R = addRow(R, S, "File", bf, lv, ck);
end

if isfield(m, 'kilosort') && isstruct(m.kilosort)
    S = "Kilosort run";
    ks = m.kilosort;
    R = addRow(R, S, "Has results", yesNo(getf(ks, 'has_results', false)));
    [lv, ck] = pathCheck(txtOf(getf(ks, 'results_dir', "")), "folder");
    R = addRow(R, S, "Results folder", txtOf(getf(ks, 'results_dir', "")), lv, ck);
    R = addRow(R, S, "Units", fmtNum(numOf(getf(ks, 'num_units', NaN)), ""));
    R = addRow(R, S, "State", txtOf(getf(ks, 'state', "")));
end

if isfield(m, 'sorting') && isstruct(m.sorting)
    S = "Sorting";
    so = m.sorting;
    [lv, ck] = pathCheck(txtOf(getf(so, 'results_dir', "")), "sorting", getf(so, 'exists', []));
    R = addRow(R, S, "Results folder", txtOf(getf(so, 'results_dir', "")), lv, ck);
    R = addRow(R, S, "Source", txtOf(getf(so, 'source', "")));
    R = addRow(R, S, "Curated in phy", yesNo(getf(so, 'curated', false)));
    R = addRow(R, S, "Units", fmtNum(numOf(getf(so, 'num_units', NaN)), ""));
    R = addRow(R, S, "Updated", txtOf(getf(so, 'updated', "")));
end

if isfield(m, 'behavior') && isstruct(m.behavior)
    S = "Behavior";
    b = m.behavior;
    bf = txtOf(getf(b, 'file', ""));
    [lv, ck] = pathCheck(bf, "file", getf(b, 'exists', []));
    if bf == ""; ck = "no session associated"; end
    R = addRow(R, S, "Session file", bf, lv, ck);
    R = addRow(R, S, "Subject", txtOf(getf(b, 'subject', "")));
    off = behaviorOffset(m);
    ck = "";
    if ~isnan(off); ck = sprintf('%+.1f min from the recording start', off / 60); end
    R = addRow(R, S, "Start", txtOf(getf(b, 'start_time', "")), "", ck);
    R = addRow(R, S, "Trials", fmtNum(numOf(getf(b, 'n_trials', NaN)), ""));
    pa = getf(b, 'pairing', []);
    if isstruct(pa) && isscalar(pa)
        st = txtOf(getf(pa, 'status', ""));
        if isempty(EphysDataset.normalizeTrialPairing(pa))
            lv = "warn"; ck = "not a usable pairing record: the dataset ignores it";
        elseif st == "approved"
            lv = "ok"; ck = ternary(isequal(getf(pa, 'auto_approved', false), true), ...
                "approved automatically", "approved after review");
        else
            lv = "warn"; ck = "needs review on the Trials tab";
        end
        R = addRow(R, S, "Pairing", st, lv, ck);
        R = addRow(R, S, "Cut trials", "[start end] " + fmtValue(reshape(getf(pa, 'cut_trials', []), 1, [])));
        R = addRow(R, S, "Cut intervals", "[start end] " + fmtValue(reshape(getf(pa, 'cut_intervals', []), 1, [])));
        R = addRow(R, S, "Trial line", txtOf(getf(pa, 'trial_line', "")));
        R = addRow(R, S, "Pairing summary", txtOf(getf(pa, 'summary', "")));
        R = addRow(R, S, "Pairing updated", txtOf(getf(pa, 'updated', "")));
    elseif bf ~= ""
        R = addRow(R, S, "Pairing", "none", "", "trials not paired yet");
    end
end

known = ["schema" "name" "folder" "recording_format" "reader" "updated" "metadata" "probe" ...
    "exclude_channels" "reference_exclude" "manual_artifacts" "bin" "kilosort" "sorting" "behavior"];
other = setdiff(string(fieldnames(m)).', known, 'stable');
for f = other
    if isstruct(m.(f)) && isscalar(m.(f))
        R = addFlat(R, "Other", f, m.(f));
    else
        R = addRow(R, "Other", f, fmtValue(m.(f)));
    end
end

T = array2table(R, 'VariableNames', {'Section', 'Field', 'Value', 'Check', 'Level'});
end

function R = addRow(R, section, field, value, level, check)
if nargin < 5; level = ""; end
if nargin < 6; check = ""; end
R(end + 1, :) = [string(section), string(field), string(value), string(check), string(level)];
end

function R = addFlat(R, section, prefix, s)
% One row per leaf of a struct, dotted names for nested fields.
for f = string(fieldnames(s)).'
    v = s.(f);
    name = prefix + "." + f;
    if isstruct(v) && isscalar(v)
        R = addFlat(R, section, name, v);
    else
        R = addRow(R, section, name, fmtValue(v));
    end
end
end

function [level, check] = pathCheck(p, kind, was)
% Live check of a path the manifest names. "" paths are not checked. WAS is
% the manifest's recorded "exists" ([] when it has none); when it differs
% from what is on disk now, the check says so.
if nargin < 3; was = []; end
level = ""; check = "";
if p == ""; return; end
switch kind
    case "folder";  ok = isfolder(p);
    case "sorting"; ok = isfile(fullfile(p, 'params.py'));
    otherwise;      ok = isfile(p);
end
if ok
    level = "ok"; check = "found";
    if kind == "sorting"; check = "params.py found"; end
else
    level = "missing"; check = "not found";
    if kind == "sorting"; check = "no params.py here"; end
end
if (islogical(was) || isnumeric(was)) && isscalar(was) && logical(was) ~= ok
    check = check + ternary(logical(was), " (there when written)", " (not there when written)");
end
end

function [level, check] = channelCheck(list, nch, what)
% A compact channel list: how many it names, and a warning for channels
% past the recording's channel count.
chs = EphysDataset.parseChannelList(list);
level = "";
check = sprintf('%d %s', numel(chs), what);
if ~isnan(nch) && any(chs > nch)
    level = "warn";
    check = sprintf('%s; %d beyond the recording''s %g channels', check, nnz(chs > nch), nch);
end
end

function off = behaviorOffset(m)
% Seconds from the recording's acq_date to the behavior start_time (NaN if either is missing).
off = NaN;
t0 = parseStamp(txtOf(getf(m, 'metadata.acq_date', "")));
t1 = parseStamp(txtOf(getf(m, 'behavior.start_time', "")));
if ~isnat(t0) && ~isnat(t1)
    off = seconds(t1 - t0);
end
end

function t = parseStamp(s)
t = NaT;
if s == ""; return; end
try
    t = datetime(s, 'InputFormat', 'yyyy-MM-dd HH:mm:ss');
catch
end
end

function s = ageText(stamp)
s = "";
t = parseStamp(stamp);
if isnat(t); return; end
d = datetime('now') - t;
if d < 0
    s = "in the future";
elseif d < hours(1)
    s = sprintf('%d min ago', floor(minutes(d)));
elseif d < days(2)
    s = sprintf('%.1f h ago', hours(d));
else
    s = sprintf('%d days ago', floor(days(d)));
end
end

function ma = artifactMatrix(v)
% manual_artifacts as [k x 2] (jsondecode collapses one period to a 1x2 / 2x1).
ma = zeros(0, 2);
if isempty(v) || ~isnumeric(v); return; end
v = double(v);
if numel(v) == 2
    ma = v(:).';
elseif size(v, 2) == 2
    ma = v;
end
end

%% --- Tree ---------------------------------------------------------------
function addTreeChildren(parent, v)
cap = 500;
if isstruct(v) && isscalar(v)
    for f = string(fieldnames(v)).'
        addTreeNode(parent, f, v.(f));
    end
elseif isstruct(v)
    for k = 1:min(numel(v), cap)
        addTreeNode(parent, sprintf('(%d)', k), v(k));
    end
elseif iscell(v)
    for k = 1:min(numel(v), cap)
        addTreeNode(parent, sprintf('[%d]', k), v{k});
    end
elseif isstring(v)
    for k = 1:min(numel(v), cap)
        addTreeNode(parent, sprintf('[%d]', k), v(k));
    end
else   % numeric / logical matrix: one node per row
    for k = 1:min(size(v, 1), cap)
        addTreeNode(parent, sprintf('[%d]', k), v(k, :));
    end
end
end

function addTreeNode(parent, label, v)
label = string(label);
if isLeaf(v)
    uitreenode(parent, 'Text', label + ": " + fmtValue(v));
else
    node = uitreenode(parent, 'Text', label + "  " + shapeText(v));
    addTreeChildren(node, v);
end
end

function tf = isLeaf(v)
if isstruct(v) || iscell(v)
    tf = isempty(v);
elseif isstring(v)
    tf = numel(v) <= 1;
elseif isnumeric(v) || islogical(v)
    tf = size(v, 1) <= 1 || size(v, 2) <= 1;
else
    tf = true;
end
end

function s = shapeText(v)
if isstruct(v) && isscalar(v)
    s = sprintf('{%d fields}', numel(fieldnames(v)));
else
    s = sprintf('[%s]', strjoin(string(size(v)), 'x'));
end
end

%% --- Formatting ---------------------------------------------------------
function v = getf(s, path, default)
% Field at a dotted path, or default when any level is missing.
v = default;
for p = split(string(path), ".").'
    if ~isstruct(s) || ~isscalar(s) || ~isfield(s, p); return; end
    s = s.(p);
end
v = s;
end

function s = txtOf(v)
% A manifest string field as a string ("" for null / non-text).
if ischar(v) || (isstring(v) && isscalar(v))
    s = string(v);
elseif iscellstr(v) || isstring(v)
    s = strjoin(string(v), ", ");
else
    s = "";
end
end

function x = numOf(v)
% A manifest number as a double (NaN for null / non-numeric).
x = NaN;
if (isnumeric(v) || islogical(v)) && isscalar(v)
    x = double(v);
end
end

function s = fmtNum(x, unit)
if isnan(x)
    s = "";
else
    s = string(num2str(x, 10)) + unit;
end
end

function s = fmtDuration(sec)
if isnan(sec)
    s = "";
    return
end
d = seconds(sec);
d.Format = 'hh:mm:ss';
s = sprintf('%.4g s (%s)', sec, char(d));
end

function s = yesNo(v)
x = numOf(v);
s = "";
if ~isnan(x); s = ternary(x ~= 0, "yes", "no"); end
end

function s = fmtValue(v)
if ischar(v) || (isstring(v) && isscalar(v))
    s = string(v);
elseif isempty(v)
    s = "null";
elseif isstring(v)
    s = "[" + strjoin(v, ", ") + "]";
elseif islogical(v) && isscalar(v)
    s = ternary(v, "true", "false");
elseif isnumeric(v) && isscalar(v)
    s = string(num2str(double(v), 10));
elseif (isnumeric(v) || islogical(v)) && numel(v) <= 24
    s = string(mat2str(double(v), 6));
elseif isnumeric(v) || islogical(v)
    s = sprintf('[%s %s]', strjoin(string(size(v)), 'x'), class(v));
elseif iscell(v)
    parts = string(cellfun(@(x) char(fmtValue(x)), v(1:min(end, 12)), 'UniformOutput', false));
    s = "[" + strjoin(parts, ", ") + ternary(numel(v) > 12, ", ...", "") + "]";
elseif isstruct(v)
    s = sprintf('{%d fields}', numel(fieldnames(v)));
else
    s = "<" + class(v) + ">";
end
end

function out = ternary(cond, a, b)
if cond
    out = a;
else
    out = b;
end
end
