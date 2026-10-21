function onShowEpochs(obj)
%onShowEpochs  Open the epoch diagram window: how the figure's epochs are cut.
%   onShowEpochs(OBJ) opens the EpochDiagram window for the figure in the
%   Figures tab's editor (the "Epoch Diagram" button under its Epoch
%   window): the figure's event reference, epoch window and trial selection
%   (its own, or the Alignment tab's where it uses the defaults), its
%   panels' baseline and what it drops. The window shows the active
%   dataset. (The Alignment tab draws the Defaults' diagram in the tab
%   itself: refreshAlignPreview.)
%
%   The window is not modal: it stays above the app, whose controls keep
%   working. It is redrawn on every edit, a change of figure or of the
%   active dataset, and an opened config (refreshEpochDiagram), until it is
%   closed. It closes with the app. A second press raises the window.
arguments
    obj (1,1) EphysAnalysisApp
end
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
