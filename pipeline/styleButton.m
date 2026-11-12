function styleButton(b, role)
%styleButton  Size and color app buttons by what they do.
%   styleButton(B) gives the buttons B (push or state buttons) the ordinary
%   look: text a size up from MATLAB's default on a light blue-gray face
%   that stands out from the gray panel behind it.
%
%   styleButton(B, ROLE) gives them the look of ROLE:
%     "secondary"  the ordinary look (the default)
%     "primary"    the main action of its tab or panel (Scan, Run this
%                  step, Run pipeline): blue with bold white text
%     "confirm"    accepts or saves a decision (Approve pairing, Save
%                  schedule): green with bold white text
%     "danger"     deletes or stops something (Delete files..., Cancel,
%                  Stop runs...): red with bold white text
%     "active"     a toggle that is on (Mark artifacts): amber, bold
%     "attention"  a main action that asks for a press (the analysis app's
%                  Preview while the figure is out of date): orange with
%                  bold dark text
%   Primary, confirm, danger and attention text is larger again. A disabled
%   button fades on its own, so the colors need no change for that.
%
%   A button's icon (an .svg file) that has a white twin in a light/ folder
%   beside it (analysis/icons/buttons) shows that twin while the text is
%   white (primary, confirm, danger) and the dark one otherwise.
%
%   A button in a grid row sized 'fit' grows with its text; in a row of a
%   fixed height it keeps that height, so give rows that hold buttons at
%   least 26 px (30 px for a tab's main action).
%
%   EphysPipelineApp and EphysFigGenApp give every button the
%   ordinary look and list their colored ones in buildUI (styleButtons).
arguments
    b
    role (1,1) string {mustBeMember(role, ["secondary" "primary" "confirm" "danger" "active" "attention"])} = "secondary"
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
    case "attention"; s = {14, "bold",   [1.00 0.62 0.15], [0.10 0.10 0.10]};
end
set(b, "FontSize", s{1}, "FontWeight", s{2}, "BackgroundColor", s{3}, "FontColor", s{4});
iconFor(b, isequal(s{4}, white));
end


function iconFor(b, light)
%iconFor  Each button's .svg icon swapped for its twin: light/<name>.svg on a colored face (LIGHT), the dark one beside light/ otherwise.
%   An icon with no twin, or not a file, stays as it is.
for i = 1:numel(b)
    ic = b(i).Icon;
    if ~(ischar(ic) || isstring(ic)) || strlength(ic) == 0; continue; end
    [folder, name, ext] = fileparts(string(ic));
    if ext ~= ".svg"; continue; end
    [up, leaf] = fileparts(folder);
    if light && leaf ~= "light"
        p = fullfile(folder, "light", name + ext);
    elseif ~light && leaf == "light"
        p = fullfile(up, name + ext);
    else
        continue
    end
    if isfile(p); b(i).Icon = p; end
end
end
