function build(obj)
%build  The window: toolbar, the chain on the left, the pictures on the right, a status bar.
%   Left, top to bottom: 1 Probe (manufacturer and channel filters, probe
%   design, package, what they are), 2 Headstage (filters, headstage, how
%   many), the mates table (which headstage connector each package
%   connector plugs into, the orientation, the channel offset), 3 Recording
%   rows (headstage channels in order, a dataset's channels, or a list),
%   the label and sort choices, the result table and the copy buttons.
%   Right: the probe's sites and the mated connector faces, the selected
%   site's path and the chain's problems. Only grid layouts, so the window
%   resizes on its own.

obj.Fig = uifigure('Name', 'Channel mapper', 'Position', [60 60 1440 880], ...
    'Tag', 'ChannelMapperApp', 'CloseRequestFcn', @(~, ~) obj.onClose());
buildMenus(obj);

outer = uigridlayout(obj.Fig, [3 1]);
outer.RowHeight = {'fit', '1x', 24};
outer.Padding = [8 8 8 8];
outer.RowSpacing = 6;

% ---------------------------------------------------------------- toolbar
tb = uigridlayout(outer, [1 9]);
tb.ColumnWidth = {'fit', 380, 'fit', 'fit', 'fit', '1x', 'fit', 'fit', 'fit'};
tb.Padding = [0 0 0 0];
uilabel(tb, 'Text', 'Bank:');
obj.BankFolderField = uieditfield(tb, 'text', 'Editable', 'off', ...
    'Tooltip', 'The hardware bank: the folder of connector, headstage, package, probe and mapping .json files.');
uibutton(tb, 'Text', 'Browse...', 'Tooltip', 'Use another hardware bank folder.', ...
    'ButtonPushedFcn', @(~, ~) obj.onBrowseBank());
uibutton(tb, 'Text', 'Reload', 'Tooltip', 'Read the bank folder again (after editing its files by hand).', ...
    'ButtonPushedFcn', @(~, ~) obj.onReloadBank());
uibutton(tb, 'Text', 'New entry...', 'Tooltip', 'Add a headstage, a package or a probe design to the bank.', ...
    'ButtonPushedFcn', @(~, ~) obj.onNewEntry(""));
uilabel(tb, 'Text', '');
uibutton(tb, 'Text', 'Load mapping...', 'Tooltip', 'Open a saved mapping from the bank, or a mapping or .chanmap.json file.', ...
    'ButtonPushedFcn', @(~, ~) obj.onLoadMapping());
obj.SaveMappingButton = uibutton(tb, 'Text', 'Save mapping...', ...
    'Tooltip', 'Save this chain to the bank''s mappings folder.', ...
    'ButtonPushedFcn', @(~, ~) obj.onSaveMapping(false));
obj.ExportButton = uibutton(tb, 'Text', 'Export Kilosort4 probe .json...', ...
    'Tooltip', 'Write the probe map (chanMap = each site''s 0-based recording row) and its .chanmap.json sidecar.', ...
    'ButtonPushedFcn', @(~, ~) obj.onExportKS4());

% ---------------------------------------------------------------- main
main = uigridlayout(outer, [1 2]);
main.ColumnWidth = {500, '1x'};
main.Padding = [0 0 0 0];

left = uigridlayout(main, [7 1]);
left.RowHeight = {'fit', 'fit', 118, 'fit', 'fit', '1x', 30};
left.Padding = [0 0 0 0];
left.RowSpacing = 6;

% 1 Probe
p1 = uipanel(left, 'Title', '1  Probe', 'FontWeight', 'bold');
g1 = uigridlayout(p1, [4 4]);
g1.ColumnWidth = {'fit', '1x', 'fit', 80};
g1.RowHeight = {'fit', 'fit', 'fit', 'fit'};
g1.Padding = [6 6 6 6];
uilabel(g1, 'Text', 'Manufacturer:');
obj.ProbeManDrop = uidropdown(g1, 'Items', {'All'}, ...
    'Tooltip', 'Show the probe designs of one manufacturer.', ...
    'ValueChangedFcn', @(~, ~) obj.onCascadeChanged("probeFilter"));
uilabel(g1, 'Text', 'Channels:');
obj.ProbeChDrop = uidropdown(g1, 'Items', {'All'}, ...
    'Tooltip', 'Show the probe designs and packages with this many channels.', ...
    'ValueChangedFcn', @(~, ~) obj.onCascadeChanged("probeFilter"));
l = uilabel(g1, 'Text', 'Probe design:');
l.Layout.Row = 2; l.Layout.Column = 1;
obj.ProbeDrop = uidropdown(g1, 'Items', {'(none)'}, 'ItemsData', {''}, ...
    'Tooltip', 'The probe''s site geometry. (none) maps the wiring only; the export needs a design.', ...
    'ValueChangedFcn', @(~, ~) obj.onCascadeChanged("probe"));
obj.ProbeDrop.Layout.Row = 2; obj.ProbeDrop.Layout.Column = [2 4];
l = uilabel(g1, 'Text', 'Package:');
l.Layout.Row = 3; l.Layout.Column = 1;
obj.PackageDrop = uidropdown(g1, 'Items', {'(none)'}, 'ItemsData', {''}, ...
    'Tooltip', 'The connector package on the probe (NeuroNexus H32, H64LP ...): which site each pin carries.', ...
    'ValueChangedFcn', @(~, ~) obj.onCascadeChanged("package"));
obj.PackageDrop.Layout.Row = 3; obj.PackageDrop.Layout.Column = [2 4];
obj.InfoLabel = uilabel(g1, 'Text', '', 'WordWrap', 'on');
obj.InfoLabel.Layout.Row = 4; obj.InfoLabel.Layout.Column = [1 4];

% 2 Headstage
p2 = uipanel(left, 'Title', '2  Headstage', 'FontWeight', 'bold');
g2 = uigridlayout(p2, [2 4]);
g2.ColumnWidth = {'fit', '1x', 'fit', 80};
g2.RowHeight = {'fit', 'fit'};
g2.Padding = [6 6 6 6];
uilabel(g2, 'Text', 'Manufacturer:');
obj.HsManDrop = uidropdown(g2, 'Items', {'All'}, ...
    'ValueChangedFcn', @(~, ~) obj.onCascadeChanged("hsFilter"));
uilabel(g2, 'Text', 'Channels:');
obj.HsChDrop = uidropdown(g2, 'Items', {'All'}, ...
    'ValueChangedFcn', @(~, ~) obj.onCascadeChanged("hsFilter"));
uilabel(g2, 'Text', 'Headstage:');
obj.HsDrop = uidropdown(g2, 'Items', {'(none)'}, 'ItemsData', {''}, ...
    'Tooltip', 'The headstage the package plugs into (Intan RHD2132, RHD2164 ...).', ...
    'ValueChangedFcn', @(~, ~) obj.onCascadeChanged("headstage"));
uilabel(g2, 'Text', 'How many:');
obj.HsCountSpinner = uispinner(g2, 'Limits', [1 4], 'Value', 1, 'Step', 1, 'RoundFractionalValues', 'on', ...
    'Tooltip', 'Two of a headstage for a two-connector package (e.g. H64LP on two RHD2132).', ...
    'ValueChangedFcn', @(~, ~) obj.onCascadeChanged("count"));

% Mates
obj.MatesTable = uitable(left, 'RowName', {}, ...
    'ColumnName', {'Probe connector', 'Headstage', 'HS connector', 'Orientation', 'Ch offset'}, ...
    'ColumnEditable', [false true true true true], ...
    'ColumnWidth', {100, '1x', 90, 85, 65}, ...
    'Tooltip', 'Which headstage connector each package connector plugs into, and how. Reference: both printed sides up (the vendors'' drawings); rotated: one turned 180 degrees.', ...
    'CellEditCallback', @(~, evt) obj.onMateEdited(evt));

% 3 Recording rows
p3 = uipanel(left, 'Title', '3  Recording rows', 'FontWeight', 'bold');
g3 = uigridlayout(p3, [2 3]);
g3.ColumnWidth = {'fit', '1x', 'fit'};
g3.RowHeight = {'fit', 'fit'};
g3.Padding = [6 6 6 6];
uilabel(g3, 'Text', 'Rows:');
obj.RowsModeDrop = uidropdown(g3, ...
    'Items', {'Headstage channels in order', 'From a dataset', 'Custom channel list'}, ...
    'ItemsData', {'in-order', 'dataset', 'custom'}, ...
    'Tooltip', 'How hardware channels become recording (.bin) rows: all the headstages'' channels in ascending order, the order a dataset recorded them, or a list you type.', ...
    'ValueChangedFcn', @(~, ~) obj.onRowsModeChanged());
obj.ChooseDatasetButton = uibutton(g3, 'Text', 'Choose dataset...', ...
    'ButtonPushedFcn', @(~, ~) obj.onUseDataset());
uilabel(g3, 'Text', 'Channels:');
obj.CustomRowsField = uieditfield(g3, 'text', ...
    'Placeholder', 'e.g. 0-31, 32-63 (0-based hardware numbers, in recording order)', ...
    'Tooltip', 'The recorded hardware channels (0-based, as in0..in31 on an Intan headstage) in the order the recording stores them. Ranges: 0-15, 8:23.', ...
    'ValueChangedFcn', @(~, ~) obj.onRowsModeChanged());
obj.CustomRowsField.Layout.Column = [2 3];

% Label / sort
lr = uigridlayout(left, [1 4]);
lr.ColumnWidth = {'fit', '1x', 'fit', 100};
lr.Padding = [0 0 0 0];
uilabel(lr, 'Text', 'Label sites by:');
obj.LabelModeDrop = uidropdown(lr, ...
    'Items', {'Site number', 'Recording row (1-based)', 'Hardware channel', 'No labels'}, ...
    'ItemsData', {'site', 'row1', 'hardware', 'none'}, 'Value', 'site', ...
    'Tooltip', 'What the probe picture writes next to each site. Recording row (1-based) is what the Probe tab and Exclude channels use.', ...
    'ValueChangedFcn', @(~, ~) obj.drawProbe());
uilabel(lr, 'Text', 'Sort:');
obj.SortDrop = uidropdown(lr, 'Items', {'Site', 'Recording row', 'Depth'}, ...
    'ItemsData', {'site', 'channel', 'depth'}, 'Value', 'site', ...
    'Tooltip', 'Order of the table and of the copied text. Depth: shank by shank, from the tip up.', ...
    'ValueChangedFcn', @(~, ~) obj.refreshAll());

% Result table
obj.ResultTable = uitable(left, 'RowName', {}, 'SelectionType', 'row', 'Multiselect', 'off', ...
    'ColumnSortable', false, ...
    'Tooltip', 'Each site''s path: package pin, headstage pin and input, hardware channel, recording row (0-based for chanMap, 1-based as the Probe tab shows). Grey rows do not reach a recorded channel.', ...
    'CellSelectionCallback', @(~, evt) obj.onResultRowSelected(evt));

% Copy buttons
ar = uigridlayout(left, [1 4]);
ar.ColumnWidth = {'1x', '1x', '1x', '1x'};
ar.Padding = [0 0 0 0];
uibutton(ar, 'Text', 'Copy table', 'Tooltip', 'Copy the table, tab-separated (pastes into Excel).', ...
    'ButtonPushedFcn', @(~, ~) obj.onCopy("tsv"));
uibutton(ar, 'Text', 'Copy CSV', 'ButtonPushedFcn', @(~, ~) obj.onCopy("csv"));
uibutton(ar, 'Text', 'Copy MATLAB', 'Tooltip', 'Copy site and chanMap (0-based rows) as MATLAB vectors.', ...
    'ButtonPushedFcn', @(~, ~) obj.onCopy("matlab"));
uibutton(ar, 'Text', 'Copy path', 'Tooltip', 'Copy the selected site''s path.', ...
    'ButtonPushedFcn', @(~, ~) obj.onCopyPath());

% ---------------------------------------------------------------- right
right = uigridlayout(main, [4 2]);
right.RowHeight = {'fit', '1x', 'fit', 'fit'};
right.ColumnWidth = {'1x', '1.4x'};
right.Padding = [0 0 0 0];
obj.TitleLabel = uilabel(right, 'Text', 'Probe sites (click one)', 'FontWeight', 'bold');
obj.MateTitleLabel = uilabel(right, 'Text', 'Package and headstage connectors, looking into each face (click a pin)', 'FontWeight', 'bold');
obj.ProbeAxes = uiaxes(right);
obj.ProbeAxes.Layout.Row = 2; obj.ProbeAxes.Layout.Column = 1;
obj.MateAxes = uiaxes(right);
obj.MateAxes.Layout.Row = 2; obj.MateAxes.Layout.Column = 2;
for ax = [obj.ProbeAxes obj.MateAxes]
    try
        disableDefaultInteractivity(ax);
        ax.Toolbar.Visible = 'off';
    catch
    end
end
obj.MateAxes.YDir = 'reverse';
axis(obj.MateAxes, 'off');
obj.PathLabel = uilabel(right, 'Text', 'Click a site, a pin or a table row to see its path.', ...
    'WordWrap', 'on', 'FontName', 'Consolas', 'FontSize', 13);
obj.PathLabel.Layout.Row = 3; obj.PathLabel.Layout.Column = [1 2];
obj.ProblemsLabel = uilabel(right, 'Text', '', 'WordWrap', 'on');
obj.ProblemsLabel.Layout.Row = 4; obj.ProblemsLabel.Layout.Column = [1 2];

% ---------------------------------------------------------------- status
obj.StatusLabel = uilabel(outer, 'Text', 'Ready.');

styleButton(findall(obj.Fig, 'Type', 'uibutton'));
styleButton(obj.ExportButton, 'primary');
styleButton(obj.SaveMappingButton, 'confirm');
end


function buildMenus(obj)
%buildMenus  File / Bank / Help.
fm = uimenu(obj.Fig, 'Text', 'File');
uimenu(fm, 'Text', 'New mapping', 'MenuSelectedFcn', @(~, ~) obj.onNewMapping());
uimenu(fm, 'Text', 'Open mapping...', 'MenuSelectedFcn', @(~, ~) obj.onLoadMapping());
uimenu(fm, 'Text', 'Save mapping', 'Separator', 'on', 'MenuSelectedFcn', @(~, ~) obj.onSaveMapping(false));
uimenu(fm, 'Text', 'Save mapping as...', 'MenuSelectedFcn', @(~, ~) obj.onSaveMapping(true));
uimenu(fm, 'Text', 'Export Kilosort4 probe .json...', 'Separator', 'on', 'MenuSelectedFcn', @(~, ~) obj.onExportKS4());
uimenu(fm, 'Text', 'Export CSV...', 'MenuSelectedFcn', @(~, ~) obj.onExportCSV());
uimenu(fm, 'Text', 'Close', 'Separator', 'on', 'MenuSelectedFcn', @(~, ~) obj.onClose());

bm = uimenu(obj.Fig, 'Text', 'Bank');
uimenu(bm, 'Text', 'New headstage...', 'MenuSelectedFcn', @(~, ~) obj.onNewEntry("headstage"));
uimenu(bm, 'Text', 'New package...', 'MenuSelectedFcn', @(~, ~) obj.onNewEntry("package"));
uimenu(bm, 'Text', 'New probe design...', 'MenuSelectedFcn', @(~, ~) obj.onNewEntry("probe"));
uimenu(bm, 'Text', 'Edit or copy the selected probe design...', 'Separator', 'on', ...
    'MenuSelectedFcn', @(~, ~) obj.onEditEntry("probe"));
uimenu(bm, 'Text', 'Edit or copy the selected package...', 'MenuSelectedFcn', @(~, ~) obj.onEditEntry("package"));
uimenu(bm, 'Text', 'Edit or copy the selected headstage...', 'MenuSelectedFcn', @(~, ~) obj.onEditEntry("headstage"));
uimenu(bm, 'Text', 'Open bank folder', 'Separator', 'on', 'MenuSelectedFcn', @(~, ~) openFolder(obj));
uimenu(bm, 'Text', 'Reload bank', 'MenuSelectedFcn', @(~, ~) obj.onReloadBank());

hm = uimenu(obj.Fig, 'Text', 'Help');
uimenu(hm, 'Text', 'Documentation', 'MenuSelectedFcn', @(~, ~) openDocs(obj));
uimenu(hm, 'Text', 'About', 'Separator', 'on', 'MenuSelectedFcn', @(~, ~) showAbout(obj.Fig, "ChannelMapperApp"));
end


function openFolder(obj)
%openFolder  The bank folder in the file browser.
try
    if ispc
        winopen(char(obj.Bank.Folder));
    else
        web(char("file://" + obj.Bank.Folder));
    end
catch ME
    obj.setStatus("Could not open the folder: " + ME.message, true);
end
end


function openDocs(obj)
%openDocs  documentation/ChannelMapperApp.md from the repository, else the wiki page.
f = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))), obj.DocFile);
try
    if isfile(f)
        open(char(f));
    else
        web(char(obj.WikiURL), '-browser');
    end
catch
    web(char(obj.WikiURL), '-browser');
end
end
