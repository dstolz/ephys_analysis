function T = cellRemovals(fig, rc)
%cellRemovals  The ways an empty cell can go from a figure's grid (removeCell), each with whether it can and why not.
%   T = EphysAnalysisConfig.cellRemovals(FIG, [R C]) is a table with a row
%   per way removeCell can take the empty cell at row R, column C out of
%   figure FIG's grid, in the order a menu lists them:
%     How       removeCell's HOW
%     Label     what the menu says: "Stretch column 2 over it" (... "over
%               its 3 empty cells" when the stretch takes others too),
%               "Shift cells up", "Grow psth_2 up over it", "Delete row 1"
%     Group     1 stretch, 2 shift, 3 grow, 4 delete (the menu's sections)
%     Possible  whether it can
%     Why       why it cannot, as a phrase ("row 1 holds events_1"); ""
%               when it can
%   The grow ways are listed only for the sides where a panel touches the
%   cell.
%
%   Error: EphysAnalysisConfig:CellTaken (not an empty cell of the grid).
%
%   See also EphysAnalysisConfig.removeCell.

arguments
    fig (1,1) struct
    rc double
end

cells = EphysAnalysisConfig.figureCells(fig);
rc = round(reshape(double(rc), 1, []));
r = rc(1);
c = rc(end);
How = ["stretchColumn"; "stretchRow"; "shiftUp"; "shiftLeft"];
Label = [sprintf("Stretch column %d over it", c); sprintf("Stretch row %d over it", r); "Shift cells up"; "Shift cells left"];
Group = [1; 1; 2; 2];
sides = ["growAbove" "growBelow" "growLeft" "growRight"];
steps = [-1 0; 1 0; 0 -1; 0 1];
dirs = ["down" "up" "right" "left"];
for s = 1:4
    n = rc + steps(s, :);
    if numel(rc) ~= 2 || any(n < 1) || n(1) > size(cells, 1) || n(2) > size(cells, 2) || cells(n(1), n(2)) == 0; continue; end
    How(end+1, 1) = sides(s); %#ok<AGROW>
    Label(end+1, 1) = "Grow " + fig.panels(cells(n(1), n(2))).id + " " + dirs(s) + " over it"; %#ok<AGROW>
    Group(end+1, 1) = 3; %#ok<AGROW>
end
How = [How; "deleteRow"; "deleteColumn"];
Label = [Label; sprintf("Delete row %d", r); sprintf("Delete column %d", c)];
Group = [Group; 4; 4];
n = numel(How);
Possible = true(n, 1);
Why = strings(n, 1);
for i = 1:n
    try
        [~, ~, gone] = EphysAnalysisConfig.removeCell(fig, rc, How(i));
        if size(gone, 1) > 1; Label(i) = replace(Label(i), "over it", sprintf("over its %d empty cells", size(gone, 1))); end
    catch ME
        if ~strcmp(ME.identifier, 'EphysAnalysisConfig:CannotRemoveCell'); rethrow(ME); end
        Possible(i) = false;
        Why(i) = string(ME.message);
    end
end
T = table(How, Label, Group, Possible, Why);
end
