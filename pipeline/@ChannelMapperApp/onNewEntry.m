function ed = onNewEntry(obj, kind, base)
%onNewEntry  Open the entry editor: a new headstage, package or probe design.
%   ED = APP.onNewEntry(KIND) opens an empty editor ("" asks which kind);
%   APP.onNewEntry(KIND, BASE) starts from the bank entry BASE (Edit or
%   copy: saving under another name adds a new entry). The editor state
%   is obj.Editor (ED is a copy of it).
%
%   Headstage / package: the header (name, manufacturer, channels, model,
%   source, notes; a headstage's channel label and hardware range), then
%   per face its id and connector, a "Paste rows" box (one vendor row per
%   line, top row first, parsed by ChannelMap.parseRow; guide posts may be
%   left out), the parsed grid (editable cells) and a preview.
%   Probe design: the sites table (Site, X, Y, Shank), generators
%   (ChannelMap.sitesFromTemplate), imports (probeinterface, a Kilosort4
%   probe .json, a CSV of site,x,y,shank) and a preview.
%   The checks (HardwareBank.problems) run on every change; Save to bank
%   is refused while there are problems (onEditorSave).
arguments
    obj
    kind (1,1) string = ""
    base = []
end
ed = struct([]);
if kind == ""
    answer = uiconfirm(obj.Fig, 'What do you want to add to the bank?', 'New entry', ...
        'Options', {'Headstage', 'Package', 'Probe design', 'Cancel'}, 'DefaultOption', 1, 'CancelOption', 4);
    switch answer
        case 'Headstage'; kind = "headstage";
        case 'Package'; kind = "package";
        case 'Probe design'; kind = "probe";
        otherwise; return
    end
end
if ~any(kind == ["headstage" "package" "probe"])
    error('ChannelMapperApp:BadKind', 'The editor makes headstages, packages and probe designs.');
end
if ~isempty(obj.Editor) && isfield(obj.Editor, 'Fig') && isvalid(obj.Editor.Fig)
    delete(obj.Editor.Fig);
end

isNew = isempty(base);
if isNew
    base = HardwareBank.emptyEntry();
    base.Kind = kind;
    if kind == "headstage"
        base.ChannelLabel = "in%d";
        base.View = "looking into the electrode connector, chip side of the PCB up";
    elseif kind == "package"
        base.View = "looking into the pins, printed side up";
    end
end
names = struct('headstage', 'headstage', 'package', 'package', 'probe', 'probe design');
if isNew
    titleText = "New " + names.(kind);
else
    titleText = "Edit or copy " + names.(kind) + " " + base.Id;
end

E = struct();
E.Kind = kind;
E.Base = base;
E.IsNew = isNew;
E.Fig = uifigure('Name', char(titleText), 'Position', [120 90 1120 740], ...
    'CloseRequestFcn', @(~, ~) closeEditor(obj));
g = uigridlayout(E.Fig, [3 1]);
g.RowHeight = {'fit', '1x', 30};
g.Padding = [8 8 8 8];

% --------------------------------------------------------------- header
h = uigridlayout(g, [4 6]);
h.ColumnWidth = {'fit', '1x', 'fit', '1x', 'fit', 90};
h.RowHeight = {'fit', 'fit', 'fit', 'fit'};
h.Padding = [0 0 0 0];
uilabel(h, 'Text', 'Name:');
E.Name = uieditfield(h, 'text', 'Value', char(base.Name), ...
    'Placeholder', 'as the vendor names it (H32, RHD2132-32ch, A1x32-6mm-50-177)', ...
    'ValueChangedFcn', @(~, ~) obj.editorRefresh());
uilabel(h, 'Text', 'Manufacturer:');
mans = unique([obj.Bank.manufacturers("headstage"), obj.Bank.manufacturers("package"), ...
    obj.Bank.manufacturers("probe"), string(base.Manufacturer)]);
mans = mans(mans ~= "");
if isempty(mans); mans = "neuronexus"; end
E.Manufacturer = uidropdown(h, 'Items', cellstr(mans), 'Editable', 'on', ...
    'ValueChangedFcn', @(~, ~) obj.editorRefresh());
if base.Manufacturer ~= ""
    E.Manufacturer.Value = char(base.Manufacturer);
else
    mk = obj.Bank.manufacturers(kind);
    if ~isempty(mk)
        E.Manufacturer.Value = char(mk(1));
    end
end
uilabel(h, 'Text', 'Channels:');
ch = base.Channels;
if isnan(ch); ch = 32; end
E.Channels = uieditfield(h, 'numeric', 'Value', ch, 'Limits', [1 Inf], 'RoundFractionalValues', 'on', ...
    'ValueChangedFcn', @(~, ~) obj.editorRefresh());
l = uilabel(h, 'Text', 'Model:');
l.Layout.Row = 2; l.Layout.Column = 1;
E.Model = uieditfield(h, 'text', 'Value', char(base.Model), 'Placeholder', 'longer description, part numbers');
E.Model.Layout.Row = 2; E.Model.Layout.Column = [2 6];
l = uilabel(h, 'Text', 'Source:');
l.Layout.Row = 3; l.Layout.Column = 1;
E.Source = uieditfield(h, 'text', 'Value', char(base.Source), 'Placeholder', 'URL of the vendor map / pinout');
E.Source.Layout.Row = 3; E.Source.Layout.Column = [2 6];
l = uilabel(h, 'Text', 'Notes:');
l.Layout.Row = 4; l.Layout.Column = 1;
E.Notes = uieditfield(h, 'text', 'Value', char(base.Notes));
E.Notes.Layout.Row = 4; E.Notes.Layout.Column = [2 6];

% --------------------------------------------------------------- body
body = uigridlayout(g, [1 2]);
body.ColumnWidth = {'1x', '1x'};
body.Padding = [0 0 0 0];
left = uigridlayout(body, [6 1]);
left.Padding = [0 0 0 0];
right = uigridlayout(body, [2 1]);
right.RowHeight = {'fit', '1x'};
right.Padding = [0 0 0 0];
E.Check = uilabel(right, 'Text', '', 'WordWrap', 'on');
E.Preview = uiaxes(right);
try
    disableDefaultInteractivity(E.Preview);
    E.Preview.Toolbar.Visible = 'off';
catch
end

if kind == "probe"
    left.RowHeight = {'fit', 'fit', 'fit', 'fit', '1x', 'fit'};
    gr = uigridlayout(left, [2 8]);
    gr.ColumnWidth = {'fit', 130, 'fit', 60, 'fit', 60, 'fit', 60};
    gr.Padding = [0 0 0 0];
    uilabel(gr, 'Text', 'Generate:');
    E.GenDrop = uidropdown(gr, 'Items', {'Linear', 'Multi-column', 'Tetrode', 'Template'}, ...
        'ValueChangedFcn', @(~, ~) editorGenEnable(obj));
    uilabel(gr, 'Text', 'Sites:');
    E.GenN = uieditfield(gr, 'numeric', 'Value', ch, 'Limits', [1 Inf], 'RoundFractionalValues', 'on', ...
        'Tooltip', 'Linear: sites per shank. Multi-column: sites per column. Tetrode: tetrodes per shank.');
    uilabel(gr, 'Text', 'Pitch:');
    E.GenPitch = uieditfield(gr, 'numeric', 'Value', 50, 'Limits', [0 Inf], 'Tooltip', 'um between sites up a column');
    uilabel(gr, 'Text', 'Shanks:');
    E.GenShanks = uieditfield(gr, 'numeric', 'Value', 1, 'Limits', [1 Inf], 'RoundFractionalValues', 'on');
    uilabel(gr, 'Text', 'Template:');
    t = ChannelMap.templates();
    E.GenTemplate = uidropdown(gr, 'Items', cellstr(strsOf(t, 'Name')), 'Editable', 'on', ...
        'Tooltip', 'A site-order template, or a full NeuroNexus design name (its pitch and shank spacing are read from it).');
    uilabel(gr, 'Text', 'Columns:');
    E.GenColumns = uieditfield(gr, 'numeric', 'Value', 2, 'Limits', [1 Inf], 'RoundFractionalValues', 'on');
    uilabel(gr, 'Text', 'Spacing:');
    E.GenSpacing = uieditfield(gr, 'numeric', 'Value', 200, 'Limits', [0 Inf], ...
        'Tooltip', 'um between shanks (and between columns for multi-column)');
    b = uibutton(gr, 'Text', 'Generate', 'ButtonPushedFcn', @(~, ~) obj.editorGenerate());
    b.Layout.Column = [7 8];
    ir = uigridlayout(left, [1 4]);
    ir.ColumnWidth = {'fit', 'fit', 'fit', 'fit'};
    ir.Padding = [0 0 0 0];
    uilabel(ir, 'Text', 'Import:');
    uibutton(ir, 'Text', 'probeinterface...', 'Tooltip', 'A probe from the probeinterface library (needs the sorting Python env).', ...
        'ButtonPushedFcn', @(~, ~) obj.editorImport("probeinterface"));
    uibutton(ir, 'Text', 'Kilosort4 .json...', 'Tooltip', 'Sites numbered by their order in the file.', ...
        'ButtonPushedFcn', @(~, ~) obj.editorImport("ks4"));
    uibutton(ir, 'Text', 'CSV...', 'Tooltip', 'Columns site, x, y and (optional) shank.', ...
        'ButtonPushedFcn', @(~, ~) obj.editorImport("csv"));
    pr = uigridlayout(left, [1 2]);
    pr.ColumnWidth = {'fit', '1x'};
    pr.Padding = [0 0 0 0];
    uilabel(pr, 'Text', 'Default package:');
    K = obj.Bank.list("package");
    E.DefaultPackage = uidropdown(pr, 'Items', cellstr(["(none)", strsOf(K, 'Id')]), ...
        'ItemsData', cellstr(["", strsOf(K, 'Id')]));
    if any(strsOf(K, 'Id') == base.DefaultPackage)
        E.DefaultPackage.Value = char(base.DefaultPackage);
    end
    uilabel(left, 'Text', 'Sites (1-based vendor numbers; um; y grows away from the tip). Edit cells directly:');
    E.Sites = uitable(left, 'ColumnName', {'Site', 'X', 'Y', 'Shank'}, 'ColumnEditable', true, 'RowName', {}, ...
        'CellEditCallback', @(~, ~) obj.editorRefresh());
    S = table(base.Sites(:), base.X(:), base.Y(:), base.Shank(:), 'VariableNames', {'Site', 'X', 'Y', 'Shank'});
    E.Sites.Data = S;
    E.Template = base.Template;
    E.PitchUm = base.PitchUm;
    E.GeometrySource = base.GeometrySource;
    E.ImportNote = "";
else
    left.RowHeight = {'fit', 'fit', 'fit', 96, '1x', 'fit'};
    fr = uigridlayout(left, [1 6]);
    fr.ColumnWidth = {'fit', 110, 'fit', 'fit', 'fit', '1x'};
    fr.Padding = [0 0 0 0];
    uilabel(fr, 'Text', 'Face:');
    E.FaceDrop = uidropdown(fr, 'Items', {'main'}, 'ItemsData', {1}, ...
        'Tooltip', 'Connectors of this device (two for H64LP or RHD2164: top and bottom).', ...
        'ValueChangedFcn', @(~, ~) editorShowFace(obj));
    uibutton(fr, 'Text', 'Add face', 'ButtonPushedFcn', @(~, ~) editorAddFace(obj));
    uibutton(fr, 'Text', 'Remove face', 'ButtonPushedFcn', @(~, ~) editorRemoveFace(obj));
    uilabel(fr, 'Text', '');
    uilabel(fr, 'Text', '');
    cr = uigridlayout(left, [1 4]);
    cr.ColumnWidth = {'fit', 110, 'fit', '1x'};
    cr.Padding = [0 0 0 0];
    uilabel(cr, 'Text', 'Face id:');
    E.FaceId = uieditfield(cr, 'text', 'Value', 'main', 'ValueChangedFcn', @(~, ~) editorFaceHeaderChanged(obj));
    uilabel(cr, 'Text', 'Connector:');
    C = obj.Bank.list("connector");
    E.Connector = uidropdown(cr, 'Items', cellstr(strsOf(C, 'Name')), ...
        'ValueChangedFcn', @(~, ~) editorFaceHeaderChanged(obj));
    if kind == "headstage"
        gender = "female";
        what = 'hardware channels (0-based, in12 = 12)';
    else
        gender = "male";
        what = 'probe site numbers';
    end
    E.Gender = gender;
    uilabel(left, 'Text', sprintf(['Paste rows: one vendor row per line, top row first, looking into the face as the ' ...
        'vendor draws it. Cells are %s, G / GND, R / REF / R1..R4, x or NC, o or GUIDE; guide posts may be left out.'], what), ...
        'WordWrap', 'on');
    E.RowsArea = uitextarea(left, 'ValueChangedFcn', @(~, ~) obj.editorRefresh(), 'FontName', 'Consolas');
    E.Grid = uitable(left, 'RowName', 'numbered', 'ColumnEditable', true, ...
        'CellEditCallback', @(~, evt) editorGridEdited(obj, evt));
    if kind == "headstage"
        hr = uigridlayout(left, [1 4]);
        hr.ColumnWidth = {'fit', 80, 'fit', '1x'};
        hr.Padding = [0 0 0 0];
        uilabel(hr, 'Text', 'Channel label:');
        E.ChannelLabel = uieditfield(hr, 'text', 'Value', char(base.ChannelLabel), ...
            'Tooltip', 'How the headstage names an input: in%d on Intan.', 'ValueChangedFcn', @(~, ~) obj.editorRefresh());
        uilabel(hr, 'Text', 'Hardware channels:');
        hc = "";
        if numel(base.HardwareChannels) == 2
            hc = sprintf("%g-%g", base.HardwareChannels(1), base.HardwareChannels(2));
        end
        E.HardwareRange = uieditfield(hr, 'text', 'Value', char(hc), 'Placeholder', 'e.g. 0-31 (8-23 on the 16-channel RHD2132)', ...
            'ValueChangedFcn', @(~, ~) obj.editorRefresh());
    else
        uilabel(left, 'Text', '');
    end
    faces = base.Faces;
    if isempty(faces)
        % the smallest connector with room for the channels and a GND and REF
        con = "";
        if ~isempty(C)
            pins = [C.Channels];
            fits = find(pins >= ch + 2);
            if isempty(fits)
                [~, j] = max(pins);
            else
                [~, j] = min(pins(fits));
                j = fits(j);
            end
            con = C(j).Name;
        end
        faces = ChannelMap.makeFace("main", con, gender, strings(0, 0));
    end
    E.Faces = faces(:);
    E.FaceText = arrayfun(@(f) strjoin(f.Text, newline), E.Faces);
    E.FaceK = 1;
end

% --------------------------------------------------------------- footer
fb = uigridlayout(g, [1 3]);
fb.ColumnWidth = {'1x', 'fit', 'fit'};
fb.Padding = [0 0 0 0];
E.Status = uilabel(fb, 'Text', '');
E.SaveButton = uibutton(fb, 'Text', 'Save to bank', 'ButtonPushedFcn', @(~, ~) obj.onEditorSave());
uibutton(fb, 'Text', 'Cancel', 'ButtonPushedFcn', @(~, ~) closeEditor(obj));
styleButton(findall(E.Fig, 'Type', 'uibutton'));
styleButton(E.SaveButton, 'confirm');

obj.Editor = E;
if kind == "probe"
    editorGenEnable(obj);
else
    editorShowFace(obj);
end
obj.editorRefresh();
ed = obj.Editor;
end


% ======================================================================
function closeEditor(obj)
if ~isempty(obj.Editor) && isfield(obj.Editor, 'Fig') && isvalid(obj.Editor.Fig)
    delete(obj.Editor.Fig);
end
obj.Editor = struct([]);
end


function editorGenEnable(obj)
%editorGenEnable  Enable the generator fields the chosen generator uses.
E = obj.Editor;
t = string(E.GenDrop.Value);
E.GenN.Enable = onoff(t ~= "Template");
E.GenShanks.Enable = onoff(t ~= "Template");
E.GenColumns.Enable = onoff(t == "Multi-column");
E.GenTemplate.Enable = onoff(t == "Template");
end


function editorShowFace(obj)
%editorShowFace  Show face FaceDrop's rows in the paste box and grid.
E = obj.Editor;
E.FaceK = E.FaceDrop.Value;
if isempty(E.FaceK) || E.FaceK > numel(E.Faces)
    E.FaceK = 1;
end
f = E.Faces(E.FaceK);
E.FaceId.Value = char(f.Id);
if any(string(E.Connector.Items) == f.Connector)
    E.Connector.Value = char(f.Connector);
end
E.RowsArea.Value = cellstr(splitlines(E.FaceText(E.FaceK)));
obj.Editor = E;
refreshFaceDrop(obj);
obj.editorRefresh();
end


function refreshFaceDrop(obj)
E = obj.Editor;
ids = strsOf(E.Faces, 'Id');
ids(ids == "") = "(unnamed)";
E.FaceDrop.Items = cellstr(ids);
E.FaceDrop.ItemsData = num2cell(1:numel(ids));
E.FaceDrop.Value = E.FaceK;
end


function editorAddFace(obj)
E = obj.Editor;
ids = strsOf(E.Faces, 'Id');
new = "bottom";
if any(ids == new); new = "face" + (numel(ids) + 1); end
if isscalar(ids) && ids == "main"
    E.Faces(1).Id = "top";
end
E.Faces(end + 1, 1) = ChannelMap.makeFace(new, string(E.Connector.Value), E.Gender, strings(0, 0));
E.FaceText(end + 1, 1) = "";
E.FaceK = numel(E.Faces);
E.FaceDrop.Items = cellstr(strsOf(E.Faces, 'Id'));
E.FaceDrop.ItemsData = num2cell(1:numel(E.Faces));
E.FaceDrop.Value = E.FaceK;
obj.Editor = E;
editorShowFace(obj);
end


function editorRemoveFace(obj)
E = obj.Editor;
if numel(E.Faces) <= 1
    E.Status.Text = 'A device needs at least one face.';
    return
end
E.Faces(E.FaceK) = [];
E.FaceText(E.FaceK) = [];
E.FaceK = 1;
E.FaceDrop.Items = cellstr(strsOf(E.Faces, 'Id'));
E.FaceDrop.ItemsData = num2cell(1:numel(E.Faces));
E.FaceDrop.Value = 1;
obj.Editor = E;
editorShowFace(obj);
end


function editorFaceHeaderChanged(obj)
E = obj.Editor;
E.Faces(E.FaceK).Id = string(strtrim(E.FaceId.Value));
E.Faces(E.FaceK).Connector = string(E.Connector.Value);
obj.Editor = E;
refreshFaceDrop(obj);
obj.editorRefresh();
end


function editorGridEdited(obj, evt)
%editorGridEdited  A grid cell was typed into: canonicalise it and rewrite the rows.
E = obj.Editor;
t = ChannelMap.canonicalToken(string(evt.NewData));
cells = E.Faces(E.FaceK).Cells;
r = evt.Indices(1); c = evt.Indices(2);
if ismissing(t) || r > size(cells, 1) || c > size(cells, 2)
    E.Status.Text = char("Not a cell value: " + string(evt.NewData));
    obj.Editor = E;
    obj.editorRefresh();
    return
end
cells(r, c) = t;
rows = strings(size(cells, 1), 1);
for k = 1:size(cells, 1)
    rows(k) = strjoin(cells(k, :), " ");
end
E.RowsArea.Value = cellstr(rows);
obj.Editor = E;
obj.editorRefresh();
end
