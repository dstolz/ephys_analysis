function showLooksCount(obj, k)
%showLooksCount  The editor's Design and looks line and its Forget button for figure K's remembered looks, when the editor shows figure K.
%   The line counts Config.Figures(K).aesthetics; Forget is on while there
%   are any. rememberFigureAesthetics (the aesthetics editor) and
%   changeFigures (the command line) call it after a change of the looks
%   alone, which needs nothing else of the editor filled again.
if k ~= obj.SelectedFigure || k < 1 || k > numel(obj.Config.Figures); return; end
E = obj.FigureEditor;
if ~isfield(E, 'looksText') || ~isvalid(E.looksText); return; end
n = numel(obj.Config.Figures(k).aesthetics);
E.looksText.Text = sprintf("%d remembered look(s); right-click the preview to edit.", n);
E.looksForget.Enable = matlab.lang.OnOffSwitchState(n > 0);
end
