function [near, far] = splitRect(rect, where)
%splitRect  A rect cut in two flush halves: the half next to the side WHERE names, and the half on that side.
%   [NEAR, FAR] = splitRect(RECT, WHERE) cuts RECT ([x y width height],
%   0-1 of the page from its bottom-left corner) in two halves that
%   share an edge exactly. WHERE is the side a new panel goes, seen from
%   the panel RECT belongs to:
%     "below"  NEAR the top half, FAR the bottom half
%     "above"  NEAR the bottom half, FAR the top half
%     "left"   NEAR the right half, FAR the left half
%     "right"  NEAR the left half, FAR the right half
%   The panel keeps NEAR and the new one takes FAR (placePanel,
%   placeBlock).
%
%   See also EphysAnalysisConfig.placePanel, EphysAnalysisConfig.placeBlock.

arguments
    rect (1,4) double
    where (1,1) string {mustBeMember(where, ["below" "above" "left" "right"])}
end
x = rect(1); y = rect(2); w = rect(3); h = rect(4);
bottomHalf = [x, y, w, h / 2];
topHalf = [x, y + h / 2, w, h / 2];
leftHalf = [x, y, w / 2, h];
rightHalf = [x + w / 2, y, w / 2, h];
switch where
    case "below", near = topHalf;     far = bottomHalf;
    case "above", near = bottomHalf;     far = topHalf;
    case "left",  near = rightHalf; far = leftHalf;
    case "right", near = leftHalf;  far = rightHalf;
end
end
