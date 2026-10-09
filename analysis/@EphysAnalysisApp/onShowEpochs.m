function onShowEpochs(obj, what)
%onShowEpochs  Open the epoch diagram: how the plot's (or the Defaults') epochs are cut.
%   onShowEpochs(OBJ, "plot") opens the EpochDiagram window for the plot in
%   the editor (the editor's "Epoch Diagram" button, under its Epoch window). It
%   shows the plot's event reference, epoch window and trial selection (its
%   own, or the Alignment tab's where it uses the defaults), its baseline and
%   what it drops. onShowEpochs(OBJ, "defaults") opens the window for the
%   Alignment tab's Defaults (that tab's button). The window shows the
%   active dataset.
%
%   The window is not modal: it stays above the app, whose controls keep
%   working. It is redrawn on every edit, a change of plot or of the active
%   dataset, and an opened config (refreshEpochDiagram), until it is closed.
%   It closes with the app. A second press raises the window and switches it
%   to what that button shows.
arguments
    obj (1,1) EphysAnalysisApp
    what (1,1) string {mustBeMember(what, ["plot" "defaults"])} = "plot"
end
obj.EpochDiagramFor = what;
d = obj.EpochDiagramWindow;
if isempty(d) || ~isvalid(d) || ~d.isOpen()
    obj.EpochDiagramWindow = EpochDiagram(Position=besideApp(obj.Fig.Position), Owner=obj.Fig);
else
    figure(d.Fig);
end
obj.refreshEpochDiagram();
end


function pos = besideApp(app)
%besideApp  The window's place: right of the app if the screen has room, else over its right side
%   (the preview), top edges level.
w = 780;
h = 720;
scr = get(groot, 'ScreenSize');
x = app(1) + app(3) + 8;
if x + w > scr(1) + scr(3)
    x = app(1) + app(3) - w - 12;
end
x = max(scr(1), x);
y = max(scr(2) + 40, app(2) + app(4) - h);
pos = [x y w h];
end
