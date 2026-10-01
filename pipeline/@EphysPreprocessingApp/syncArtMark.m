function syncArtMark(obj)
%syncArtMark  Make the Mark manual periods view show the active dataset.
%   The view (Artifacts tab, ArtMarkViewer) shows the recording of the
%   active dataset, through the common reference the Artifacts tab sets
%   (EphysTraceSource.recording). It is loaded when the view is on screen
%   and the dataset it holds (ArtMarkDataset) is not the active one: when
%   the Artifacts tab opens on it, when its tab is picked, and when the
%   active dataset changes while it is open (selectDataset). A dataset
%   changed while the view is hidden drops what it held, to be loaded when
%   it is shown. The datasets are compared as handles, so a rescan, which
%   rebuilds them, loads it again.
%
%   Marking (ArtMarkMode) stops whenever the view is not on screen or does
%   not show the active dataset, as a period marked then would go to
%   another dataset than the one the tab names. The Mark artifacts button
%   is enabled while a dataset is active. Already showing the active
%   dataset, this only brings the shading and the status line up to date
%   (the preview, the manual periods or the Reference may have changed).
%
%   See also onArtViewTabChanged, onArtMarkInput, applyArtMarkSettings,
%   refreshArtMarkShading, EphysTraceSource.recording.

v = obj.ArtMarkViewer;
if isempty(v) || ~isvalid(v) || isempty(obj.ArtViewTabs) || ~isvalid(obj.ArtViewTabs); return; end
d = obj.currentDataset();
obj.ArtMarkButton.Enable = matlab.lang.OnOffSwitchState(~isempty(d));
shown = obj.ArtMarkDataset;
current = ~isempty(d) && ~isempty(shown) && isvalid(shown) && shown == d;
showing = obj.Tabs.SelectedTab == obj.TabArtifacts && obj.ArtViewTabs.SelectedTab == obj.ArtTabMark;

if obj.ArtMarkMode && ~(current && showing)
    obj.ArtMarkButton.Value = false;
    obj.onArtMarkInput("toggle", false);
end
if current
    if showing
        obj.refreshArtMarkShading();
        obj.onArtMarkViewChanged();
    end
    return
end

% Another dataset than the one held: drop it, and load the active one if shown.
obj.ArtMarkDataset = EphysDataset.empty;
v.setSource([]);
obj.ArtMarkStatusLabel.Text = "";
if ~showing; return; end
if isempty(d)
    obj.ArtMarkStatusLabel.Text = "Scan a project first.";
    v.render();
    return
end

dlg = uiprogressdlg(obj.Fig, "Title", "Mark manual periods", "Indeterminate", "on", ...
    "Message", "Opening the recording of " + d.Name + "...");
closer = onCleanup(@() delete(dlg));
try
    if d.NumFiles == 0; d.discoverFiles(); end
    if d.NumFiles > 0 && (isnan(d.Fs) || isempty(d.PerFile)); d.refreshMetadata(); end
    if ~(d.NumFiles > 0 && isfinite(d.Fs) && isfinite(d.NumSamples))
        error('EphysPreprocessingApp:ArtMark:NoRecording', 'its recording files cannot be read');
    end
    src = EphysTraceSource.recording(d);
catch ME
    obj.ArtMarkStatusLabel.Text = "Cannot show the recording of " + d.Name + ": " + string(ME.message);
    obj.ArtMarkButton.Enable = "off";
    v.render();
    return
end

v.setSource(src);
v.DefaultWidth = min(2, v.TotalDuration);
obj.ArtMarkDataset = d;
obj.applyArtMarkSettings("all");
v.setView(0, v.DefaultWidth);
v.render();                       % now, not after RenderDelay
obj.onArtMarkViewChanged();
end
