function pressFigureButton(obj, key)
%pressFigureButton  The key of one of the Figures tab's preview buttons: do what pressing it does.
%   pressFigureButton(obj, KEY) is onKeyPress's Ctrl+KEY (Cmd on a Mac):
%     "p"  Preview            "r"  Redraw All       "u"  Test report
%     "t"  Auto, ticked or unticked                 "k"  Export preview
%     "e"  Export code        "w"  Open in window
%   A button that is off (no figure selected, a run going) is left alone,
%   as is Preview while a preview computes or draws; Auto always toggles.
switch key
    case "p"
        b = obj.FigurePreviewButton;
        if ismember(obj.FigurePreviewState, ["computing" "drawing"]); return; end
    case "r"
        b = obj.FigureRedrawAllButton;
    case "u"
        b = obj.FigureTestReportButton;
    case "k"
        b = obj.FigureExportPreviewButton;
    case "e"
        b = obj.FigureCodeButton;
    case "w"
        b = obj.FigureOpenButton;
    case "t"
        obj.FigureAutoCheckBox.Value = ~obj.FigureAutoCheckBox.Value;
        obj.onFigureAutoPreviewToggled();
        return
    otherwise
        return
end
if b.Enable == "on"; b.ButtonPushedFcn(b, []); end
end
