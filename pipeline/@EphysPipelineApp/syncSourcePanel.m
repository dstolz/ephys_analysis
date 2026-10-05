function syncSourcePanel(obj)
%syncSourcePanel  Show the settings of the active dataset's recording system.
%   The Source settings panel (Project tab, under the table) shows the
%   reader options of the active dataset's system: Open Ephys
%   (Acquisition.OpenEphys: recordings, record node, stream) or TDT
%   (Acquisition.TDT: stream, gain, and what the active block reads). They
%   are the config's, so they apply to every dataset of that system in the
%   project. For a system without settings, or without an active dataset,
%   the panel says so. The TDT stream list is the active block's streams;
%   the controls' values are set by applyAcquisitionSection and kept here.
%   Called when the active dataset changes and when the table is rebuilt
%   (a scan, Refresh metadata).
%
%   See also EphysPreprocessingApp.onAcquisitionChanged, TDTReader,
%   OpenEphysReader.
if isempty(obj.SourcePanel) || ~isvalid(obj.SourcePanel); return; end
d = obj.currentDataset();
if ~isempty(d) && isempty(d.Reader)
    try
        d.discoverFiles();   % a changed ReaderOptions drops the reader until it is needed
    catch
    end
end
kind = "";
if ~isempty(d) && ~isempty(d.Reader); kind = string(d.Reader.Kind); end

obj.SourceOEGrid.Visible = "off";
obj.SourceTDTGrid.Visible = "off";
obj.SourceNoteLabel.Visible = "on";
rows = {'fit', 0, 0};
switch kind
    case "openephys"
        obj.SourcePanel.Title = "Source settings: Open Ephys";
        obj.SourceOEGrid.Visible = "on";
        obj.SourceNoteLabel.Visible = "off";
        rows = {0, 'fit', 0};
    case "tdt"
        obj.SourcePanel.Title = "Source settings: TDT (Synapse)";
        obj.SourceTDTGrid.Visible = "on";
        obj.SourceNoteLabel.Visible = "off";
        rows = {0, 0, 'fit'};
        syncTDT(obj, d.Reader);
    case ""
        obj.SourcePanel.Title = "Source settings";
        if isempty(obj.Project) || obj.Project.NumDatasets == 0
            obj.SourceNoteLabel.Text = "Scan a project first.";
        elseif isempty(d)
            obj.SourceNoteLabel.Text = "No active dataset: click a row to see its recording system's settings.";
        else
            obj.SourceNoteLabel.Text = d.Name + ": no reader recognises this folder.";
        end
    otherwise
        name = systemName(kind);
        obj.SourcePanel.Title = "Source settings: " + name;
        obj.SourceNoteLabel.Text = name + " recordings have no source settings.";
end
obj.SourceGrid.RowHeight = rows;
end


function syncTDT(obj, r)
%syncTDT  The active block's streams in the Stream list; what it reads.
names = strings(1, 0);
tips = strings(1, 0);
for s = reshape(r.Streams, 1, [])
    names(end+1) = string(s.name); %#ok<AGROW>
    tips(end+1) = sprintf("%s: %d channels, %.10g Hz, %s (%s)", s.name, numel(s.chans), s.fs, ...
        formatName(s.fmt), upper(s.storage)); %#ok<AGROW>
end
cur = string(obj.TDTStreamDropDown.Value);
items = ["automatic" names];
if ~any(strcmpi(items, cur)); items(end+1) = cur; end   % the config's stream, not in this block
obj.TDTStreamDropDown.Items = cellstr(items);
obj.TDTStreamDropDown.Value = char(cur);

tip = "Streams of " + r.Name + ":";
if isempty(tips); tip = tip + " none read yet"; else; tip = strjoin([tip tips], newline); end
s = r.Stream;
if isempty(r.Streams)
    txt = "headers not read (Refresh metadata)";
elseif isempty(s)
    txt = "no stream read with these settings";
elseif isnan(r.Gain)
    txt = sprintf("%s is stored as %s: set the gain", s.name, formatName(s.fmt));
elseif ~s.integer && r.Gain == 1e6
    txt = sprintf("reads %s: %d ch at %.10g Hz, %s in volts (x 1e6 = µV)", s.name, numel(s.chans), s.fs, ...
        formatName(s.fmt));
else
    txt = sprintf("reads %s: %d ch at %.10g Hz, %s x %s µV", s.name, numel(s.chans), s.fs, ...
        formatName(s.fmt), obj.numberText(r.Gain));
end
obj.TDTStatusLabel.Text = txt;
obj.TDTStatusLabel.Tooltip = tip;
end


function f = formatName(fmt)
%formatName  A stream's MATLAB class as TDT names its format.
switch string(fmt)
    case "single", f = "float32";
    case "double", f = "float64";
    otherwise,     f = string(fmt);
end
end


function name = systemName(kind)
%systemName  A reader kind as it is shown.
switch kind
    case "intan",  name = "Intan";
    case "binary", name = "Binary (recording.json)";
    otherwise,     name = kind;
end
end
