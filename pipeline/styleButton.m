function styleButton(b, role)
%styleButton  Size and colour app buttons by what they do.
%   styleButton(B) gives the buttons B (push or state buttons) the ordinary
%   look: text a size up from MATLAB's default on a light blue-grey face
%   that stands out from the grey panel behind it.
%
%   styleButton(B, ROLE) gives them the look of ROLE:
%     "secondary"  the ordinary look (the default)
%     "primary"    the main action of its tab or panel (Scan, Run this
%                  step, Run pipeline): blue with bold white text
%     "confirm"    accepts or saves a decision (Approve pairing, Save
%                  schedule): green with bold white text
%     "danger"     deletes or stops something (Delete files..., Cancel,
%                  Stop runs...): red with bold white text
%     "active"     a toggle that is on (Mark Artifacts): amber, bold
%   Primary, confirm and danger text is larger again. A disabled button
%   fades on its own, so the colours need no change for that.
%
%   A button in a grid row sized 'fit' grows with its text; in a row of a
%   fixed height it keeps that height, so give rows that hold buttons at
%   least 26 px (30 px for a tab's main action).
%
%   EphysPreprocessingApp and EphysAnalysisApp give every button the
%   ordinary look and list their coloured ones in buildUI (styleButtons).
arguments
    b
    role (1,1) string {mustBeMember(role, ["secondary" "primary" "confirm" "danger" "active"])} = "secondary"
end

b = b(isvalid(b));
if isempty(b); return; end
white = [1 1 1];
switch role
    case "secondary"; s = {13, "normal", [0.89 0.92 0.96], [0.10 0.10 0.10]};
    case "primary";   s = {14, "bold",   [0.15 0.45 0.80], white};
    case "confirm";   s = {14, "bold",   [0.16 0.52 0.28], white};
    case "danger";    s = {14, "bold",   [0.80 0.25 0.20], white};
    case "active";    s = {13, "bold",   [1.00 0.80 0.30], [0.10 0.10 0.10]};
end
set(b, "FontSize", s{1}, "FontWeight", s{2}, "BackgroundColor", s{3}, "FontColor", s{4});
end
