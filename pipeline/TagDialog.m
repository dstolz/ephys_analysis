classdef TagDialog < handle
    % TagDialog  Edit the tags of one target, or add / remove tags on several at once.
    %   A small modal window over a set of targets (datasets, later units
    %   or signals). With one target it edits that target's tag set; with
    %   two or more it adds tags to all of them or removes tags from all of
    %   them. Every rule (what a tag is, the limit of TagSet.MaxTags per
    %   target, how sets are combined) is TagSet's; the window only holds
    %   the pending edit, and nothing reaches the targets until OK.
    %
    %     dlg = TagDialog({d.Tags}, TagSet.vocabulary({P.Datasets.Tags}), ...
    %         Labels=d.Name, Parent=app.Fig, OnDone=@(r) apply(r));
    %
    %   SETS is a cell array of the targets' current tag sets: one entry
    %   opens single mode, two or more bulk mode. VOCABULARY is the tags
    %   offered in the Available list (the tags in use elsewhere); the
    %   targets' own tags are offered too. Options:
    %     Labels   string array naming the targets, one per set, for the
    %              title and the messages (default "dataset 1", ...)
    %     OnDone   called once as OnDone(R) when the window closes
    %     Parent   the uifigure to center on ([] = none)
    %     Visible  false builds the window hidden (tests)
    %     Policy   the bulk policy to start with: "all" (default) cancels
    %              the whole edit when a target would go over the limit,
    %              "skip" leaves those targets out after one confirmation
    %              (pass back the Policy last chosen to remember it)
    %     Noun     what a target is, for the texts (default "dataset")
    %
    %   The window is modal but does not block (no uiwait): the caller
    %   applies the result in OnDone. R is [] when the window is canceled,
    %   closed, or OK changes no target; otherwise a struct:
    %     mode     "set" (single mode), "add" or "remove" (bulk mode)
    %     policy   the bulk policy in force ("all" | "skip"), also in single mode
    %     tags     single mode: the new set; bulk: the tags added or removed
    %     sets     1 x M cell, the new set of each target (in SETS order)
    %     applied  1 x M logical: false for a target left out by "skip"
    %     why      1 x M string: "" where applied, else why it was left
    %              out ("14 tags, 2 over the limit of 12")
    %   so the caller always stores R.sets{k} where R.applied(k).
    %
    %   OK in bulk Add mode when a target would exceed the limit: policy
    %   "all" keeps the window open and names each such target ("Cannot
    %   add 2 tags: rec3 would have 14 tags, 2 over the limit of 12");
    %   policy "skip" first lists the targets it will leave out and
    %   relabels OK to "Apply to N", and a second OK applies. Any change
    %   (a tag, the mode, the policy) withdraws that confirmation.
    %
    %   Properties (read-only): Fig, Ctl (the controls), Pending, Mode,
    %   Policy, ErrorText, OKText. Methods, the same paths as the
    %   controls: pick, addTyped, removeCurrent, clearAll, setMode,
    %   setPolicy, ok, cancel. Opened by EphysPipelineApp (onEditTags).
    %
    %   See also TagSet, EphysDataset.

    properties (SetAccess = private)
        Fig                          % the uifigure
        Ctl = struct()               % the controls
        Pending = {}                 % single: the new set; bulk Add: the tags to add; bulk Remove: the tags to remove
        Mode (1,1) string = "set"    % "set" (single mode), "add" or "remove" (bulk mode)
        Policy (1,1) string = "all"  % bulk Add over the limit: "all" cancels the edit, "skip" leaves the target out
    end

    properties
        OnDone = []                  % called once as OnDone(result) when the window closes
    end

    properties (Dependent)
        ErrorText                    % the inline message ("" when none), lines joined by newline
        OKText                       % the OK button's text ("OK", or "Apply to N" awaiting a skip confirmation)
    end

    properties (Access = private)
        Sets = {}                    % 1 x M cell, the targets' sets as given
        Labels (1,:) string          % 1 x M names of the targets
        Vocabulary = {}              % tags offered besides the targets' own
        Noun (1,1) string = "dataset"
        Armed (1,1) logical = false  % a skip list is shown and the next OK applies
        Done (1,1) logical = false   % OnDone has been called
    end

    properties (Constant, Access = private)
        ErrorColor = [0.75 0.1 0.1]
        NoticeColor = [0.7 0.35 0]
    end

    methods
        function obj = TagDialog(sets, vocabulary, opts)
            %TagDialog  The window over the tag sets SETS (a cell, one per target).
            %   dlg = TagDialog(SETS, VOCABULARY, Labels=, OnDone=, Parent=, Visible=, Policy=, Noun=)
            arguments
                sets cell
                vocabulary = {}
                opts.Labels string = strings(1, 0)
                opts.OnDone = []
                opts.Parent = []
                opts.Visible (1,1) logical = true
                opts.Policy (1,1) string = "all"
                opts.Noun (1,1) string = "dataset"
            end
            if isempty(sets)
                error('TagDialog:NoTargets', 'TagDialog needs at least one tag set.');
            end
            m = numel(sets);
            obj.Sets = cell(1, m);
            for k = 1:m
                obj.Sets{k} = TagSet.parse(sets{k});
            end
            obj.Vocabulary = TagSet.parse(vocabulary);
            obj.Noun = opts.Noun;
            labels = reshape(opts.Labels, 1, []);
            if numel(labels) ~= m
                labels = opts.Noun + " " + (1:m);
            end
            obj.Labels = labels;
            obj.OnDone = opts.OnDone;
            if m == 1
                obj.Mode = "set";
                obj.Pending = obj.Sets{1};
            else
                obj.Mode = "add";
            end
            TagDialog.checkPolicy(opts.Policy);
            obj.Policy = opts.Policy;
            obj.build(opts.Parent, opts.Visible);
            obj.refresh();
        end

        function delete(obj)
            if ~isempty(obj.Fig) && isvalid(obj.Fig); delete(obj.Fig); end
        end

        function t = get.ErrorText(obj)
            t = join(reshape(string(obj.Ctl.Error.Text), 1, []), newline);
        end

        function t = get.OKText(obj)
            t = string(obj.Ctl.OK.Text);
        end

        function pick(obj, tags)
            %pick  Move TAGS (Available entries) into the pending list.
            obj.addTags(tags);
        end

        function addTyped(obj, text)
            %addTyped  Add the tags typed as TEXT, separated by commas.
            %   An entry that is no valid tag is named in the inline message
            %   and nothing is added. Clears the New tag field on success.
            [tags, ~, why] = TagSet.fromText(text, TagSet.EntryDelimiter);
            if ~isempty(why)
                obj.disarm();
                obj.showMessage(why);
                return
            end
            if isempty(tags); return; end
            if obj.addTags(tags)
                obj.Ctl.NewTag.Value = '';
            end
        end

        function removeCurrent(obj, tags)
            %removeCurrent  Take TAGS out of the pending list.
            tags = TagSet.canon(tags);
            if isempty(tags); return; end
            obj.disarm();
            obj.Pending = TagSet.remove(obj.Pending, tags);
            obj.showMessage([]);
            obj.refresh();
        end

        function clearAll(obj)
            %clearAll  Single: remove every tag. Bulk Add: add nothing. Bulk Remove: remove every tag.
            obj.disarm();
            if obj.Mode == "remove"
                obj.Pending = TagSet.vocabulary(obj.Sets);
            else
                obj.Pending = TagSet.clear();
            end
            obj.showMessage([]);
            obj.refresh();
        end

        function setMode(obj, mode)
            %setMode  Bulk mode only: "add" or "remove"; the pending list starts empty.
            mode = string(mode);
            if obj.Mode == "set" || ~isscalar(mode) || ~ismember(mode, ["add" "remove"])
                error('TagDialog:BadMode', 'Mode "%s" is not available: bulk mode takes "add" or "remove".', ...
                    strjoin(mode, ' '));
            end
            obj.Ctl.Mode.Value = char(mode);
            if mode == obj.Mode; return; end
            obj.disarm();
            obj.Mode = mode;
            obj.Pending = TagSet.clear();
            obj.showMessage([]);
            obj.refresh();
        end

        function setPolicy(obj, policy)
            %setPolicy  "all" (cancel the whole edit) or "skip" (leave out what would go over the limit).
            policy = string(policy);
            TagDialog.checkPolicy(policy);
            obj.Ctl.Policy.Value = char(policy);
            if policy == obj.Policy; return; end
            obj.disarm();
            obj.Policy = policy;
            obj.showMessage([]);
        end

        function ok(obj)
            %ok  Apply: check the pending edit, then OnDone(result) and close (see the class help).
            if obj.Done; return; end
            if obj.Mode == "set"
                [fits, why] = TagSet.checkCount(obj.Pending);
                if ~fits
                    obj.showMessage(sprintf("Cannot save: %s would have %s", obj.Labels(1), why));
                    return
                end
                r = struct('mode', "set", 'policy', obj.Policy, 'tags', {obj.Pending}, ...
                    'sets', {{obj.Pending}}, 'applied', true, 'why', "");
                if isequal(r.sets, obj.Sets); r = []; end
                obj.finish(r);
                return
            end
            [newSets, fits, why] = TagSet.bulkApply(obj.Sets, obj.Mode, obj.Pending, obj.Policy);
            if ~all(fits)
                bad = find(~fits);
                if obj.Policy == "all" || ~any(fits)
                    obj.disarm();
                    obj.showMessage("Cannot add " + tagWord(numel(obj.Pending)) + ": " ...
                        + obj.Labels(bad) + " would have " + why(bad));
                    return
                end
                if ~obj.Armed
                    m = numel(obj.Sets);
                    obj.showMessage(sprintf("Will skip %d of %d %s: %s", numel(bad), m, plural(obj.Noun, m), ...
                        strjoin(obj.Labels(bad) + " (" + why(bad) + ")", ", ")), obj.NoticeColor);
                    obj.Armed = true;
                    obj.Ctl.OK.Text = sprintf("Apply to %d", nnz(fits));
                    return
                end
            end
            r = struct('mode', obj.Mode, 'policy', obj.Policy, 'tags', {obj.Pending}, ...
                'sets', {newSets}, 'applied', fits, 'why', why);
            if isequal(newSets, obj.Sets); r = []; end
            obj.finish(r);
        end

        function cancel(obj)
            %cancel  Close without a change: OnDone([]).
            obj.finish([]);
        end
    end

    methods (Access = private)
        function build(obj, parent, visible)
            fig = uifigure("Name", "Tags", "Visible", "off", "Position", [100 100 560 460], ...
                "WindowStyle", "modal");
            if ~isempty(parent) && isvalid(parent)
                p = parent.Position;
                fig.Position(1:2) = p(1:2) + max(0, (p(3:4) - fig.Position(3:4)) / 2);
            end
            fig.CloseRequestFcn = @(~, ~) obj.cancel();
            obj.Fig = fig;
            bulk = obj.Mode ~= "set";
            m = numel(obj.Sets);

            g = uigridlayout(fig, [7 1]);
            g.RowHeight = {'fit', 'fit', 'fit', '1x', 30, 'fit', 30};
            c = struct();
            if bulk
                txt = sprintf("Tags of %d ticked %s", m, plural(obj.Noun, m));
            else
                txt = "Tags of " + obj.Labels(1);
            end
            c.Title = uilabel(g, "Text", txt, "FontWeight", "bold", "FontSize", 14);
            c.Title.Layout.Row = 1;

            % Bulk: what to do, and what to do with a target that would go over the limit.
            mg = uigridlayout(g, [1 4]);
            mg.Layout.Row = 2;
            mg.Padding = [0 0 0 0];
            mg.ColumnWidth = {'fit', 'fit', 'fit', '1x'};
            mg.RowHeight = {'fit'};
            uilabel(mg, "Text", "Mode:");
            c.Mode = uidropdown(mg, "Items", {'Add to all', 'Remove from all'}, "ItemsData", {'add', 'remove'}, ...
                "Tooltip", "Add the listed tags to every target, or remove them from every target.", ...
                "ValueChangedFcn", @(src, ~) obj.setMode(src.Value));
            c.PolicyLabel = uilabel(mg, "Text", "If a " + obj.Noun + " would exceed the limit:");
            c.Policy = uidropdown(mg, "Items", cellstr(["Cancel the whole edit", "Skip that " + obj.Noun]), ...
                "ItemsData", {'all', 'skip'}, "Value", char(obj.Policy), ...
                "Tooltip", sprintf("A %s holds at most %d tags. Skip lists the %ss it leaves out before it applies.", ...
                obj.Noun, TagSet.MaxTags, obj.Noun), ...
                "ValueChangedFcn", @(src, ~) obj.setPolicy(src.Value));
            c.Summary = uilabel(g, "Text", "", "WordWrap", "on", "FontColor", [0.3 0.3 0.3]);
            c.Summary.Layout.Row = 3;
            if bulk
                c.Mode.Value = char(obj.Mode);
            else
                g.RowHeight(2:3) = {0, 0};
                set([mg c.Summary], "Visible", "off");
            end

            % The two lists: what can be added, and the pending set.
            lg = uigridlayout(g, [3 2]);
            lg.Layout.Row = 4;
            lg.Padding = [0 0 0 0];
            lg.RowHeight = {'fit', '1x', 30};
            lg.ColumnWidth = {'1x', '1x'};
            c.AvailableLabel = uilabel(lg, "Text", "Available:");
            c.AvailableLabel.Layout.Row = 1; c.AvailableLabel.Layout.Column = 1;
            c.CurrentLabel = uilabel(lg, "Text", "Current:");
            c.CurrentLabel.Layout.Row = 1; c.CurrentLabel.Layout.Column = 2;
            c.Available = uilistbox(lg, "Items", {}, "Multiselect", "on", ...
                "Tooltip", "Tags in use. Double-click, or select and press the button below, to take them.", ...
                "DoubleClickedFcn", @(src, ~) obj.pick(src.Value));
            c.Available.Layout.Row = 2; c.Available.Layout.Column = 1;
            c.Current = uilistbox(lg, "Items", {}, "Multiselect", "on", ...
                "Tooltip", "Double-click, or select and press the button below, to take tags out.", ...
                "DoubleClickedFcn", @(src, ~) obj.removeCurrent(src.Value));
            c.Current.Layout.Row = 2; c.Current.Layout.Column = 2;
            c.AddSelected = uibutton(lg, "Text", "Add selected", ...
                "ButtonPushedFcn", @(~, ~) obj.pick(obj.Ctl.Available.Value));
            c.AddSelected.Layout.Row = 3; c.AddSelected.Layout.Column = 1;
            c.RemoveSelected = uibutton(lg, "Text", "Remove selected", ...
                "ButtonPushedFcn", @(~, ~) obj.removeCurrent(obj.Ctl.Current.Value));
            c.RemoveSelected.Layout.Row = 3; c.RemoveSelected.Layout.Column = 2;

            % A new tag, typed (Enter adds too).
            ng = uigridlayout(g, [1 3]);
            ng.Layout.Row = 5;
            ng.Padding = [0 0 0 0];
            ng.ColumnWidth = {'fit', '1x', 'fit'};
            ng.RowHeight = {30};
            uilabel(ng, "Text", "New tag:");
            c.NewTag = uieditfield(ng, "text", "Placeholder", "e.g. pilot, draft", ...
                "Tooltip", sprintf("Tags separated by commas: %d to %d characters, letters, digits, - _ . (lowercased).", ...
                TagSet.MinLength, TagSet.MaxLength), ...
                "ValueChangedFcn", @(src, ~) obj.addTyped(src.Value));
            c.AddTyped = uibutton(ng, "Text", "Add", "ButtonPushedFcn", @(~, ~) obj.addTyped(obj.Ctl.NewTag.Value));

            c.Error = uilabel(g, "Text", "", "WordWrap", "on", "FontColor", obj.ErrorColor);
            c.Error.Layout.Row = 6;

            bg = uigridlayout(g, [1 4]);
            bg.Layout.Row = 7;
            bg.Padding = [0 0 0 0];
            bg.ColumnWidth = {'fit', '1x', 'fit', 'fit'};
            bg.RowHeight = {30};
            c.ClearAll = uibutton(bg, "Text", "Clear all", "ButtonPushedFcn", @(~, ~) obj.clearAll());
            c.ClearAll.Layout.Column = 1;
            c.Cancel = uibutton(bg, "Text", "Cancel", "ButtonPushedFcn", @(~, ~) obj.cancel());
            c.Cancel.Layout.Column = 3;
            c.OK = uibutton(bg, "Text", "OK", "ButtonPushedFcn", @(~, ~) obj.ok());
            c.OK.Layout.Column = 4;
            styleButton([c.AddSelected c.RemoveSelected c.AddTyped c.Cancel]);
            styleButton(c.ClearAll, "danger");
            styleButton(c.OK, "confirm");
            obj.Ctl = c;
            fig.Visible = matlab.lang.OnOffSwitchState(visible);
            if visible
                try focus(c.NewTag); catch; end
            end
        end

        function added = addTags(obj, tags)
            %addTags  Put TAGS into the pending list, or say why not (the list is then unchanged).
            added = false;
            [tags, ~, why] = TagSet.parse(tags);
            if ~isempty(why)
                obj.disarm();
                obj.showMessage(why);
                return
            end
            if isempty(tags); return; end
            obj.disarm();
            switch obj.Mode
                case "remove"
                    held = TagSet.vocabulary(obj.Sets);
                    missing = TagSet.remove(tags, held);
                    if ~isempty(missing)
                        m = numel(obj.Sets);
                        obj.showMessage(sprintf("None of the %d %s has %s.", m, plural(obj.Noun, m), ...
                            TagSet.toText(missing, TagSet.DisplayDelimiter)));
                        return
                    end
                    obj.Pending = TagSet.union(obj.Pending, tags);   % a removal list has no limit
                case "add"
                    next = TagSet.union(obj.Pending, tags);
                    if ~TagSet.checkCount(next)
                        obj.showMessage(sprintf("Cannot add %s: a %s holds at most %d.", ...
                            tagWord(numel(next)), obj.Noun, TagSet.MaxTags));
                        return
                    end
                    obj.Pending = TagSet.add(obj.Pending, tags);
                otherwise
                    next = TagSet.union(obj.Pending, tags);
                    [fits, why] = TagSet.checkCount(next);
                    if ~fits
                        n = numel(TagSet.remove(tags, obj.Pending));
                        obj.showMessage(sprintf("Cannot add %s: %s would have %s", ...
                            tagWord(n), obj.Labels(1), why));
                        return
                    end
                    obj.Pending = TagSet.add(obj.Pending, tags);
            end
            added = true;
            obj.showMessage([]);
            obj.refresh();
        end

        function refresh(obj)
            %refresh  The lists, their labels and the bulk summary from the pending edit.
            c = obj.Ctl;
            m = numel(obj.Sets);
            held = TagSet.vocabulary(obj.Sets);
            [common, some, counts] = TagSet.summarize(obj.Sets);
            n = @(t) counts(strcmp(held, t));
            withCount = @(ts) string(cellfun(@(t) sprintf('%s (%d of %d)', t, n(t), m), ts, 'UniformOutput', false));
            switch obj.Mode
                case "remove"
                    avail = TagSet.remove(held, obj.Pending);
                    setList(c.Available, avail, withCount(avail));
                    setList(c.Current, obj.Pending, withCount(obj.Pending));
                    c.CurrentLabel.Text = "To remove from all:";
                    c.AddSelected.Text = "Mark selected";
                    c.RemoveSelected.Text = "Unmark selected";
                otherwise
                    avail = TagSet.remove(TagSet.union(obj.Vocabulary, held), obj.Pending);
                    setList(c.Available, avail, string(avail));
                    setList(c.Current, obj.Pending, string(obj.Pending));
                    c.AddSelected.Text = "Add selected";
                    c.RemoveSelected.Text = "Remove selected";
                    if obj.Mode == "add"
                        c.CurrentLabel.Text = "To add to all:";
                    else
                        c.CurrentLabel.Text = "Current:";
                    end
            end
            if obj.Mode == "set"; return; end
            % The policy only matters when adding: a removal cannot exceed the limit.
            on = matlab.lang.OnOffSwitchState(obj.Mode == "add");
            set([c.PolicyLabel c.Policy], "Visible", on);
            if isempty(common); onAll = "(none)"; else; onAll = TagSet.toText(common); end
            if isempty(some); onSome = "(none)"; else; onSome = strjoin(withCount(some), ", "); end
            c.Summary.Text = ["On all: " + onAll; "On some: " + onSome];
        end

        function showMessage(obj, lines, color)
            %showMessage  The inline message (LINES [] clears it), red unless COLOR says otherwise.
            if nargin < 3; color = obj.ErrorColor; end
            if isempty(lines); lines = ""; end
            obj.Ctl.Error.Text = reshape(string(lines), [], 1);
            obj.Ctl.Error.FontColor = color;
        end

        function disarm(obj)
            %disarm  Withdraw a shown skip confirmation: any change needs a fresh OK.
            if obj.Armed
                obj.Armed = false;
                obj.showMessage([]);
            end
            obj.Ctl.OK.Text = "OK";
        end

        function finish(obj, r)
            %finish  Call OnDone(R) once, then close the window.
            if obj.Done; return; end
            obj.Done = true;
            fig = obj.Fig;
            closer = onCleanup(@() closeFig(fig));
            if ~isempty(obj.OnDone)
                obj.OnDone(r);
            end
            clear closer
        end
    end

    methods (Static, Access = private)
        function checkPolicy(policy)
            if ~isscalar(policy) || ~ismember(policy, ["all" "skip"])
                error('TagDialog:BadPolicy', 'Unknown policy "%s": use "all" or "skip".', strjoin(string(policy), ' '));
            end
        end
    end
end


function setList(lb, tags, items)
%setList  Show ITEMS in listbox LB, each standing for the tag of TAGS; keep what stays selected.
keep = intersect(cellstr(lb.Value), tags);
if isempty(tags)
    set(lb, "Items", {}, "ItemsData", {}, "Value", {});
else
    set(lb, "Items", cellstr(items), "ItemsData", tags, "Value", reshape(keep, 1, []));
end
end


function s = tagWord(n)
if n == 1; s = "1 tag"; else; s = n + " tags"; end
end


function s = plural(noun, n)
if n == 1; s = noun; else; s = noun + "s"; end
end


function closeFig(fig)
if ~isempty(fig) && isvalid(fig); delete(fig); end
end
