function pressFigureButton(obj, key)
%pressFigureButton  The key of one of the Figures tab's preview buttons: do what pressing it does.
%   pressFigureButton(obj, KEY) is onKeyPress's Ctrl+KEY (Cmd on a Mac):
%     "p"  Preview            "r"  Redraw All       "u"  Test report (Export tab)
%     "t"  Auto off, or back where it was           "k"  Export preview
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
        b = obj.TestReportButton;
    case "k"
        b = obj.FigureExportPreviewButton;
    case "e"
        b = obj.FigureCodeButton;
    case "w"
        b = obj.FigureOpenButton;
    case "t"   % Auto off, or on again where it was (FigureAutoLast)
        s = obj.FigureAutoSlider;
        if s.Value > 0
            obj.FigureAutoLast = s.Value;
            s.Value = 0;
        else
            s.Value = obj.FigureAutoLast;
        end
        obj.onFigureAutoRedrawChanged();
        return
    otherwise
        return
end
if b.Enable == "on"; b.ButtonPushedFcn(b, []); end
end
