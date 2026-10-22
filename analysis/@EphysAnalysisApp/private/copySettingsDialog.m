function [pick, ok] = copySettingsDialog(fig, F, k, designs, remembered)
%copySettingsDialog  Pick a figure's settings, one by one, and the figures (or the design) to copy them onto, in a modal window over FIG.
%   [PICK, OK] = copySettingsDialog(FIG, F, K, DESIGNS, REMEMBERED): F the
%   figures (Config.Figures), K the one selected (From starts there),
%   DESIGNS the names of your plot designs, REMEMBERED a struct of
%   Unticked (figureSettingItems' Generic keys left unticked last time:
%   the rest start ticked) and Targets (the ids of the figures ticked last
%   time).
%   - From: every figure, by id and panel count. Copy to: "The figures
%     ticked", each design of yours ("Design: <name>") or "A new design"
%     (named in New design's name).
%   - Settings: a check box tree of From's settings (figureSettingItems):
%     the parts, their groups (a panel, then its group), each setting with
%     its value now. Checking a part or a group checks every setting
%     under it. Into a design only the settings a design holds are shown
%     (the group colors, the heat colors, each remembered look). Find
%     shows the settings whose name, group, key or value holds the text
%     (the ticks of those it hides stay, and copy); All, None tick every
%     setting shown or none, Expand and Collapse open or shut the tree.
%   - Copy onto: a check box list of the other figures (the one selected
%     is marked "shown"), with All and None; the ticks start from the last
%     use, else (From another figure) the figure selected.
%   The count says how many settings go onto how many figures. Copy
%   returns OK true and PICK: From (an index into F), Keys (the keys
%   ticked, a string row: in design mode the design's only), To
%   ("figures" | "design"), Targets (indices into F), Design (the
%   design's name), New (true for a new design), Unticked and TargetIds
%   (what to remember for the next time). Cancel (or closing the window)
%   gives OK false. The window's UserData holds its controls (From, To,
%   Find, Name, Settings, Targets, All, None, Expand, Collapse,
%   TargetsAll, TargetsNone, Count, Ok, Cancel) for the tests.
%
%   See also onCopyFigureSettings, figureSettingItems, copyFigureSettings, figureLookToDesign.
ok = false;
n = numel(F);
from = k;
unticked = reshape(string(remembered.Unticked), 1, []);
designs = reshape(string(designs), 1, []);
findText = "";   % what Find holds (as typed)
newName = "";    % ... and New design's name
targetIds = reshape(string(remembered.Targets), 1, []);
pick = struct('From', k, 'Keys', strings(1, 0), 'To', "figures", 'Targets', zeros(1, 0), 'Design', "", 'New', false, ...
    'Unticked', unticked, 'TargetIds', targetIds);
P = figureSettingParts();
I = [];
on = false(0, 1);
shown = zeros(1, 0);
leaves = matlab.ui.container.TreeNode.empty(1, 0);

pos = [300 300 880 640];
try
    q = getpixelposition(fig);
    pos(1:2) = max(1, q(1:2) + (q(3:4) - pos(3:4)) / 2);
catch
end
d = uifigure('Name', 'Copy figure settings', 'Position', pos, 'WindowStyle', 'modal');
g = uigridlayout(d, [6 1], 'RowHeight', {'fit', 30, 30, '1x', 30, 36}, 'Padding', [12 12 12 12]);
l = uilabel(g, 'Text', "Tick the settings to copy from the figure picked, and the figures to copy them onto (or a design to copy " + ...
    "its look into). What is left unticked stays as it is; a figure keeps its id, title and enabled. The previews are " + ...
    "not drawn again: a figure changed is marked out of date in the list, and the one shown follows as after any edit.", ...
    'WordWrap', 'on');
l.Layout.Row = 1;

rg = uigridlayout(g, [1 4], 'ColumnWidth', {'fit', '1x', 'fit', '1x'}, 'Padding', [0 0 0 0]);
rg.Layout.Row = 2;
uilabel(rg, 'Text', 'From:');
names = arrayfun(@(i) F(i).id + "  (" + numel(F(i).panels) + " panels)", 1:n);
fromDD = uidropdown(rg, 'Items', names, 'ItemsData', 1:n, 'Value', from, 'ValueChangedFcn', @(~, ~) fromChanged(), ...
    'Tooltip', 'The figure whose settings are copied.');
uilabel(rg, 'Text', 'Copy to:');
toItems = ["The figures ticked", "Design: " + designs, "A new design"];
toData = ["figures", "design:" + designs, "new"];
toDD = uidropdown(rg, 'Items', toItems, 'ItemsData', toData, 'Value', "figures", 'ValueChangedFcn', @(~, ~) toChanged(), ...
    'Tooltip', "The figures ticked at the right, or a design of yours (its look: the group and heat colors and the remembered looks; " + ...
    "a new one starts from the design chosen now).");

fg = uigridlayout(g, [1 4], 'ColumnWidth', {'fit', '1x', 'fit', '1x'}, 'Padding', [0 0 0 0]);
fg.Layout.Row = 3;
uilabel(fg, 'Text', 'Find:');
findF = uieditfield(fg, 'text', 'Placeholder', 'Show the settings whose name holds this', ...
    'ValueChangingFcn', @(~, e) filterTo(e.Value), 'ValueChangedFcn', @(f, ~) filterTo(f.Value), ...
    'Tooltip', "Show only the settings whose name, group, key or value holds the text (the ticks of the others stay).");
uilabel(fg, 'Text', 'New design''s name:');
nameF = uieditfield(fg, 'text', 'Enable', 'off', 'ValueChangedFcn', @(f, ~) nameTo(f.Value), ...
    'ValueChangingFcn', @(~, e) nameTo(e.Value), 'Tooltip', 'The name of the new design (one of yours of that name is replaced).');

mg = uigridlayout(g, [1 2], 'ColumnWidth', {'2x', '1x'}, 'Padding', [0 0 0 0]);
mg.Layout.Row = 4;
tree = uitree(mg, 'checkbox', 'CheckedNodesChangedFcn', @(~, ~) checked());
tg = uigridlayout(mg, [3 1], 'RowHeight', {22, '1x', 30}, 'Padding', [0 0 0 0]);
uilabel(tg, 'Text', 'Copy onto:', 'FontWeight', 'bold');
ttree = uitree(tg, 'checkbox', 'CheckedNodesChangedFcn', @(~, ~) count());
tbg = uigridlayout(tg, [1 2], 'ColumnWidth', {'1x', '1x'}, 'Padding', [0 0 0 0]);
tAllB = uibutton(tbg, 'Text', 'All', 'ButtonPushedFcn', @(~, ~) tickTargets(true), 'Tooltip', 'Tick every other figure.');
tNoneB = uibutton(tbg, 'Text', 'None', 'ButtonPushedFcn', @(~, ~) tickTargets(false), 'Tooltip', 'Clear every figure''s tick.');

cg = uigridlayout(g, [1 5], 'ColumnWidth', {90, 90, 90, 90, '1x'}, 'Padding', [0 0 0 0]);
cg.Layout.Row = 5;
allB = uibutton(cg, 'Text', 'All', 'ButtonPushedFcn', @(~, ~) tickSettings(true), 'Tooltip', 'Tick every setting shown.');
noneB = uibutton(cg, 'Text', 'None', 'ButtonPushedFcn', @(~, ~) tickSettings(false), 'Tooltip', 'Clear the tick of every setting shown.');
expB = uibutton(cg, 'Text', 'Expand', 'ButtonPushedFcn', @(~, ~) expand(tree, 'all'), 'Tooltip', 'Open every part and group.');
colB = uibutton(cg, 'Text', 'Collapse', 'ButtonPushedFcn', @(~, ~) collapse(tree, 'all'), 'Tooltip', 'Shut every part and group.');
cnt = uilabel(cg, 'Text', '');

og = uigridlayout(g, [1 3], 'ColumnWidth', {'1x', 120, 120}, 'Padding', [0 0 0 0]);
og.Layout.Row = 6;
uilabel(og, 'Text', '');
okB = uibutton(og, 'Text', 'Copy', 'ButtonPushedFcn', @(~, ~) finish(true));
cancelB = uibutton(og, 'Text', 'Cancel', 'ButtonPushedFcn', @(~, ~) finish(false));
styleButton(findall(d, 'Type', 'uibutton'));
styleButton(okB, 'confirm');
d.CloseRequestFcn = @(~, ~) finish(false);
loadFrom();
d.UserData = struct('From', fromDD, 'To', toDD, 'Find', findF, 'Name', nameF, 'Settings', tree, 'Targets', ttree, ...
    'All', allB, 'None', noneB, 'Expand', expB, 'Collapse', colB, 'TargetsAll', tAllB, 'TargetsNone', tNoneB, ...
    'Count', cnt, 'Ok', okB, 'Cancel', cancelB);
uiwait(d);
if isvalid(d); delete(d); end

    function loadFrom()
        %loadFrom  The settings of figure FROM, ticked as remembered, and the other figures to copy onto.
        I = figureSettingItems(F(from));
        on = ~ismember(I.Generic, unticked);
        delete(ttree.Children);
        tick = matlab.ui.container.TreeNode.empty(1, 0);
        for i = setdiff(1:n, from, 'stable')
            t = F(i).id + "  (" + numel(F(i).panels) + " panels)";
            if i == k; t = t + ", shown"; end
            node = uitreenode(ttree, 'Text', t, 'NodeData', i);
            if ismember(F(i).id, targetIds); tick(end+1) = node; end %#ok<AGROW>
        end
        if isempty(tick) && from ~= k   % from another figure: onto the one selected
            kids = ttree.Children;
            tick = kids([kids.NodeData] == k);
        end
        setChecked(ttree, tick);
        build();
    end

    function build()
        %build  The tree of the settings shown: the mode's, holding the Find text.
        delete(tree.Children);
        designMode = toDD.Value ~= "figures";
        text = lower(strtrim(findText));
        shown = zeros(1, 0);
        leaves = matlab.ui.container.TreeNode.empty(1, 0);
        nodes = containers.Map('KeyType', 'char', 'ValueType', 'any');
        for i = 1:height(I)
            if designMode && ~I.Design(i); continue; end
            pl = P.Label(P.Part == I.Part(i));
            label = I.Label(i) + " = " + I.Value(i);
            if text ~= "" && ~contains(lower(strjoin([pl I.Groups{i} label I.Key(i)], " ")), text); continue; end
            parent = tree;
            path = "";
            for lvl = [pl I.Groups{i}]
                path = path + "/" + lvl;
                if ~isKey(nodes, char(path))
                    nodes(char(path)) = uitreenode(parent, 'Text', lvl);
                end
                parent = nodes(char(path));
            end
            leaves(end+1) = uitreenode(parent, 'Text', label, 'NodeData', i); %#ok<AGROW>
            shown(end+1) = i; %#ok<AGROW>
        end
        setChecked(tree, leaves(on(shown)));
        if text ~= ""
            expand(tree, 'all');
        else
            for c = reshape(tree.Children, 1, [])
                expand(c);   % the parts open, a panel's groups shut
            end
        end
        count();
    end

    function checked()
        %checked  Note the ticks of the settings shown.
        if isempty(shown); count(); return; end
        c = tree.CheckedNodes;
        idx = zeros(1, 0);
        for node = reshape(c, 1, [])
            if isnumeric(node.NodeData) && isscalar(node.NodeData); idx(end+1) = node.NodeData; end %#ok<AGROW>
        end
        on(shown) = ismember(shown, idx);
        count();
    end

    function tickSettings(tf)
        on(shown) = tf;
        setChecked(tree, leaves(on(shown)));
        count();
    end

    function tickTargets(tf)
        kids = ttree.Children;
        setChecked(ttree, kids(repmat(tf, size(kids))));
        count();
    end

    function filterTo(v)
        findText = string(v);
        build();
    end

    function nameTo(v)
        newName = strtrim(string(v));
        count();
    end

    function fromChanged()
        remember();
        from = fromDD.Value;
        loadFrom();
    end

    function toChanged()
        designMode = toDD.Value ~= "figures";
        ttree.Enable = matlab.lang.OnOffSwitchState(~designMode);
        tAllB.Enable = ttree.Enable;
        tNoneB.Enable = ttree.Enable;
        nameF.Enable = matlab.lang.OnOffSwitchState(toDD.Value == "new");
        build();
    end

    function keys = tickedKeys()
        use = on;
        if toDD.Value ~= "figures"; use = use & I.Design; end
        keys = reshape(I.Key(use), 1, []);
    end

    function idx = tickedTargets()
        c = ttree.CheckedNodes;
        idx = zeros(1, 0);
        if ~isempty(c); idx = sort([c.NodeData]); end
    end

    function count()
        nk = numel(tickedKeys());
        switch toDD.Value
            case "figures"
                nt = numel(tickedTargets());
                cnt.Text = sprintf('%d setting(s) onto %d figure(s)', nk, nt);
                can = nk > 0 && nt > 0;
            case "new"
                cnt.Text = sprintf('%d setting(s) into a new design', nk);
                can = nk > 0 && newName ~= "";
            otherwise
                cnt.Text = sprintf('%d setting(s) into design %s', nk, extractAfter(toDD.Value, "design:"));
                can = nk > 0;
        end
        okB.Enable = matlab.lang.OnOffSwitchState(can);
    end

    function remember()
        %remember  The ticks to start from next time: the generic keys left unticked, the figures ticked.
        gen = I.Generic;
        unticked = union(setdiff(unticked, gen(on)), gen(~on));
        unticked = reshape(unticked, 1, []);
        if toDD.Value == "figures"
            t = tickedTargets();
            others = setdiff(1:n, from);
            targetIds = reshape(union(setdiff(targetIds, [string.empty(1, 0) F(others).id]), [string.empty(1, 0) F(t).id]), 1, []);
        end
    end

    function finish(accept)
        if accept
            remember();
            pick.From = from;
            pick.Keys = tickedKeys();
            pick.Targets = tickedTargets();
            pick.To = "figures";
            if toDD.Value ~= "figures"
                pick.To = "design";
                pick.New = toDD.Value == "new";
                pick.Design = extractAfter(toDD.Value, "design:");
                if pick.New; pick.Design = newName; end
            end
            pick.Unticked = unticked;
            pick.TargetIds = targetIds;
            ok = true;
        end
        uiresume(d);
    end
end


function setChecked(t, nodes)
%setChecked  Check NODES of the check box tree T (none: [], as CheckedNodes takes no empty node array).
if isempty(nodes)
    t.CheckedNodes = [];
else
    t.CheckedNodes = nodes;
end
end
