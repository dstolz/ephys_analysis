classdef ChannelMapperApp < handle
    %ChannelMapperApp  Map probe sites to headstage channels and recording rows.
    %   ChannelMapperApp() opens the channel mapper on its own;
    %   ChannelMapperApp(APP) opens it from an EphysPreprocessingApp (the
    %   Probe tab's Map channels button), which supplies the probe folder the
    %   export goes to, the project's datasets and the Python for
    %   probeinterface, and lists the exported probe.
    %
    %   The window composes a chain from the hardware bank (HardwareBank,
    %   pipeline/hardware): a probe design, its package (NeuroNexus H32,
    %   H64LP ...), the headstage(s) it plugs into (Intan RHD2132, RHD2164 ...)
    %   and how the Omnetics connectors mate (reference or rotated). It shows
    %   each site's path to its hardware channel and recording row as a table
    %   you can copy (TSV for Excel, CSV, MATLAB) and as pictures of the probe
    %   and the mated connector faces (click a site, a pin or a table row),
    %   saves the chain as a mapping, adds hardware to the bank, and writes
    %   the Kilosort4 probe .json (chanMap = the 0-based recording row of
    %   each site) with a <probe>.chanmap.json sidecar recording the chain.
    %
    %   Options
    %     BankFolder  the hardware bank ("" = the last one used, else
    %                 pipeline/hardware)
    %     Dataset     an EphysDataset: recording rows from its ChannelNumbers
    %     Mapping     a saved mapping's id or a mapping / sidecar file to open
    %
    %   The dialog-free methods (selectProbe, selectPackage, selectHeadstage,
    %   setOrientation, setOffset, setRows, select, exportKS4, saveMapping,
    %   loadMapping, copyText) do what the controls do; the buttons wrap them
    %   with the file dialogs and confirmations.
    %
    %   See also ChannelMap, HardwareBank, EphysPreprocessingApp.onOpenChannelMapper.

    properties
        App = []                          % parent EphysPreprocessingApp, [] when standalone
        Bank HardwareBank = HardwareBank.empty
        Fig matlab.ui.Figure = matlab.ui.Figure.empty

        % --- the chain being edited ---
        ProbeId (1,1) string = ""         % "" = no probe design (no geometry)
        PackageId (1,1) string = ""
        HeadstageId (1,1) string = ""
        HeadstageCount (1,1) double = 1
        Offsets (1,:) double = 0          % channel offset of each headstage instance
        Mates struct = struct('From', {}, 'To', {}, 'Orientation', {})
        RowsMode (1,1) string = "in-order"   % "in-order" | "dataset" | "custom"
        ChannelNumbers (1,:) double = double.empty(1, 0)
        DatasetName (1,1) string = ""
        MappingName (1,1) string = ""     % the saved mapping last opened or saved

        % --- what the window shows ---
        Result struct = struct([])        % ChannelMap.resolve of the chain
        ResultOrder (:,1) double = zeros(0, 1)   % Result.Table row of each ResultTable row
        Selection struct = struct('site', NaN, 'face', "", 'cell', [NaN NaN])
        FaceDraw struct = struct([])      % one per drawn face (drawFaces)
        ProbeSites struct = struct('X', [], 'Y', [], 'Site', [])
        Applying (1,1) logical = false    % true while controls are filled (ignore their callbacks)
        Syncing (1,1) logical = false     % true while applySelection moves the selection
        Editor struct = struct([])        % the open New / Edit entry dialog (onNewEntry)

        % --- UI ---
        BankFolderField matlab.ui.control.EditField
        ProbeManDrop matlab.ui.control.DropDown
        ProbeChDrop matlab.ui.control.DropDown
        ProbeDrop matlab.ui.control.DropDown
        PackageDrop matlab.ui.control.DropDown
        InfoLabel matlab.ui.control.Label
        HsManDrop matlab.ui.control.DropDown
        HsChDrop matlab.ui.control.DropDown
        HsDrop matlab.ui.control.DropDown
        HsCountSpinner matlab.ui.control.Spinner
        MatesTable matlab.ui.control.Table
        RowsModeDrop matlab.ui.control.DropDown
        ChooseDatasetButton matlab.ui.control.Button
        CustomRowsField matlab.ui.control.EditField
        LabelModeDrop matlab.ui.control.DropDown
        SortDrop matlab.ui.control.DropDown
        ResultTable matlab.ui.control.Table
        ExportButton matlab.ui.control.Button
        SaveMappingButton matlab.ui.control.Button
        TitleLabel matlab.ui.control.Label
        MateTitleLabel matlab.ui.control.Label
        ProbeAxes matlab.ui.control.UIAxes
        MateAxes matlab.ui.control.UIAxes
        SelMarker = []                    % the ring on the selected site (ProbeAxes)
        PathLabel matlab.ui.control.Label
        ProblemsLabel matlab.ui.control.Label
        StatusLabel matlab.ui.control.Label
    end

    properties (Constant)
        PrefGroup = 'ChannelMapperApp'
        SidecarSuffix = ".chanmap.json"
        WikiURL = "https://github.com/dstolz/ephys_analysis/wiki/API-ChannelMapperApp"
        DocFile = "documentation/ChannelMapperApp.md"
        % Cell colours: signal, GND, REF, PR, NC, GUIDE, selected
        Colors = struct('signal', [0.85 0.91 1], 'GND', [0.55 0.55 0.55], 'REF', [0.70 0.90 0.70], ...
            'PR', [0.85 0.75 0.95], 'NC', [1 1 1], 'GUIDE', [0.93 0.93 0.93], 'selected', [1 0.8 0.3])
    end

    methods
        function obj = ChannelMapperApp(app, opts)
            arguments
                app = []
                opts.BankFolder (1,1) string = ""
                opts.Dataset = EphysDataset.empty
                opts.Mapping (1,1) string = ""
            end
            if ~(isempty(app) || isa(app, 'EphysPreprocessingApp'))
                error('ChannelMapperApp:BadParent', 'The parent must be an EphysPreprocessingApp (or []).');
            end
            obj.App = app;
            folder = opts.BankFolder;
            if folder == "" && ispref(obj.PrefGroup, 'BankFolder')
                f = string(getpref(obj.PrefGroup, 'BankFolder'));
                if isscalar(f) && isfolder(f)
                    folder = f;
                end
            end
            if folder == ""
                folder = HardwareBank.defaultFolder();
            end
            obj.Bank = HardwareBank(folder);
            obj.build();
            obj.loadPreferences();
            obj.refreshBank();
            restored = false;
            if opts.Mapping ~= ""
                try
                    obj.loadMapping(opts.Mapping);
                    restored = true;
                catch ME
                    obj.setStatus("Could not open " + opts.Mapping + ": " + ME.message, true);
                end
            end
            if ~restored
                obj.restoreLastChain();
            end
            if ~isempty(opts.Dataset) && isa(opts.Dataset, 'EphysDataset') && ~isempty(opts.Dataset.ChannelNumbers)
                obj.setRows("dataset", opts.Dataset.ChannelNumbers, opts.Dataset.Name);
            end
            if nargout == 0
                clear obj
            end
        end

        function delete(obj)
            %delete  Close the window (and its entry editor) with the object.
            if ~isempty(obj.Editor) && isfield(obj.Editor, 'Fig') && isvalid(obj.Editor.Fig)
                delete(obj.Editor.Fig);
            end
            if ~isempty(obj.Fig) && isvalid(obj.Fig)
                delete(obj.Fig);
            end
        end

        % --- the chain: dialog-free API ---
        function selectProbe(obj, id)
            %selectProbe  Choose the probe design ("" = none); its package and a matching headstage follow.
            obj.ProbeId = string(id);
            obj.onChainChanged("probe");
        end

        function selectPackage(obj, id)
            %selectPackage  Choose the package.
            obj.PackageId = string(id);
            obj.onChainChanged("package");
        end

        function selectHeadstage(obj, id, count)
            %selectHeadstage  Choose the headstage and how many of it (default: keep the count).
            arguments
                obj
                id (1,1) string
                count double = []
            end
            obj.HeadstageId = id;
            if ~isempty(count)
                obj.HeadstageCount = count;
            end
            obj.onChainChanged("headstage");
        end

        function setOrientation(obj, k, orientation)
            %setOrientation  Orientation of package face K's mate; a two-connector pair re-pairs.
            obj.applyMateEdit(k, "Orientation", string(orientation));
        end

        function setOffset(obj, i, offset)
            %setOffset  Channel offset of headstage instance I.
            obj.Offsets(i) = offset;
            obj.resolve();
        end

        % --- signatures of methods defined in separate files ---
        build(obj)
        loadPreferences(obj)
        savePreferences(obj)
        restoreLastChain(obj)
        refreshBank(obj)
        fillCascade(obj)
        onCascadeChanged(obj, which)
        onChainChanged(obj, what)
        defaultMatesNow(obj)
        refreshMatesTable(obj)
        onMateEdited(obj, evt)
        applyMateEdit(obj, k, column, value)
        chain = currentChain(obj)
        R = resolve(obj)
        refreshAll(obj)
        updateTitle(obj)
        refreshResultTable(obj)
        drawProbe(obj)
        drawFaces(obj)
        onFaceClick(obj, key, evt)
        onProbeClick(obj, evt)
        onResultRowSelected(obj, evt)
        select(obj, kind, key)
        applySelection(obj)
        txt = copyText(obj, format)
        onCopy(obj, format)
        onCopyPath(obj)
        [probeFile, sidecar] = exportKS4(obj, file, opts)
        onExportKS4(obj)
        onExportCSV(obj)
        file = saveMapping(obj, name, opts)
        onSaveMapping(obj, asNew)
        loadMapping(obj, what)
        onLoadMapping(obj)
        onNewMapping(obj)
        setRows(obj, mode, channelNumbers, datasetName)
        onRowsModeChanged(obj)
        onUseDataset(obj)
        onBrowseBank(obj)
        onReloadBank(obj)
        ed = onNewEntry(obj, kind, base)
        onEditEntry(obj, kind)
        editorRefresh(obj)
        raw = editorEntry(obj)
        file = onEditorSave(obj)
        editorGenerate(obj)
        editorImport(obj, source, file)
        result = runProbeTool(obj, varargin)
        setStatus(obj, msg, isError)
        onClose(obj)
    end

    methods (Static)
        h = drawFace(ax, face, opts)
        v = parseChannelList(txt)
        [value, ok] = promptText(fig, titleText, prompt, default)
        [k, ok] = pickFromList(fig, titleText, items, prompt)
    end
end
