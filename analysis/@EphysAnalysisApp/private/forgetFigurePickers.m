function forgetFigurePickers(obj)
%forgetFigurePickers  Forget every figure's kept observation list (keepFigurePicker): each is made again when its figure shows.
%   Called when what the lists hold may have changed without their key
%   changing: a scan (new sources), another config (its figures may share
%   ids with the old one's: clearFigureViews), a star or a note set or
%   cleared (the ★ and ✎ marks, a Starred only list: refreshFavorites,
%   refreshNotes, which keep the selected figure's again as it is then).
%
%   See also keepFigurePicker, takeFigurePicker.
M = obj.FigurePickers;
if isa(M, 'containers.Map') && M.Count > 0; remove(M, keys(M)); end
end
