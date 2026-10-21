function pressFigureButton(obj, key)
%pressFigureButton  The key of one of the Figures tab's preview buttons: do what pressing it does.
%   pressFigureButton(obj, KEY) is onKeyPress's Ctrl+KEY (Cmd on a Mac):
%     "p"  Preview            "g"  Generate         "u"  Unit report
%     "t"  Auto, ticked or unticked                 "e"  Export code
%     "w"  Open in window
%   A button that is off (no figure selected, a run going) is left alone,
%   as is Preview while a preview computes or draws; Auto always toggles.
switch key
    case "p"
        b = obj.FigurePreviewButton;
        if ismember(obj.FigurePreviewState, ["computing" "drawing"]); return; end
    case "g"
        b = obj.FigureGenerateButton;
    case "u"
        b = obj.FigureUnitReportButton;
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
