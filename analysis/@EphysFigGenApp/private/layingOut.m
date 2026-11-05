function guard = layingOut(obj)
%layingOut  Note that the app lays the preview out itself (FigureLayingOut) until GUARD is cleared or goes out of scope.
%   GUARD = layingOut(OBJ) sets FigureLayingOut and returns an onCleanup
%   that puts back what it was. While it is set the Position listeners
%   markFigurePanel keeps on the preview's axes do nothing (placeAgain),
%   so a layout that moves every axes (renderFigure's in-place and
%   layout-only paths: inPlaceFigurePreview, layoutPreview) does not
%   bring the outline or Arrange's overlay up to date once per axes; the
%   caller does it once after (markFigurePanel).
%
%   See also EphysFigGenApp.markFigurePanel, inPlaceFigurePreview, layoutPreview.
was = obj.FigureLayingOut;
obj.FigureLayingOut = true;
guard = onCleanup(@() restore(obj, was));
end


function restore(obj, was)
if isvalid(obj); obj.FigureLayingOut = was; end
end
