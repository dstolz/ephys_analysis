classdef test_TagDialog < matlab.unittest.TestCase
    %test_TagDialog  TagDialog: single and bulk tag edits, driven hidden (Visible=false).
    %   Single mode: picking, typing (valid, invalid, a mix), removing,
    %   clearing, the limit, Cancel and the close button giving [], OK
    %   giving the sorted set. Bulk mode: the On all / On some summary, Add
    %   and Remove results, a target over the limit under policy "all"
    %   (the window stays open and names it) and "skip" (one confirmation,
    %   withdrawn by any change, then the target left out with its reason).
    %   The controls' callbacks take the same paths as the methods.
    %
    %   Usage:  runtests("test_TagDialog")

    properties
        Got = {}        % every result OnDone was called with
    end

    methods (Access = private)
        function dlg = open(tc, sets, vocab, varargin)
            dlg = TagDialog(sets, vocab, "Visible", false, "OnDone", @(r) tc.keep(r), varargin{:});
            tc.addTeardown(@delete, dlg);
        end

        function keep(tc, r)
            tc.Got{end+1} = r;
        end
    end

    methods (Test)
        % ---- single mode ----
        function singleOpensOnTheTargetsSet(tc)
            dlg = tc.open({{'Pilot', 'draft'}}, {'draft', 'pilot', 'shared'}, Labels="rec1");
            tc.verifyEqual(dlg.Mode, "set");
            tc.verifyEqual(dlg.Pending, {'draft', 'pilot'});
            tc.verifyEqual(string(dlg.Ctl.Title.Text), "Tags of rec1");
            tc.verifyEqual(dlg.Ctl.Available.ItemsData, {'shared'}, 'the vocabulary minus the pending set');
            tc.verifyEqual(dlg.Ctl.Current.ItemsData, {'draft', 'pilot'});
            tc.verifyEqual(dlg.OKText, "OK");
            tc.verifyEqual(dlg.ErrorText, "");
            tc.verifyEqual(string(dlg.Fig.WindowStyle), "modal");
            tc.verifyEqual(string(dlg.Fig.Visible), "off");
        end

        function singlePickThenOkGivesTheSortedSet(tc)
            dlg = tc.open({{'draft'}}, {'draft', 'pilot', 'shared'}, Labels="rec1");
            dlg.pick({'shared', 'pilot'});
            tc.verifyEqual(dlg.Pending, {'draft', 'pilot', 'shared'});
            tc.verifyEmpty(dlg.Ctl.Available.ItemsData);
            dlg.ok();
            tc.assertNumElements(tc.Got, 1);
            r = tc.Got{1};
            tc.verifyEqual(r.mode, "set");
            tc.verifyEqual(r.policy, "all");
            tc.verifyEqual(r.tags, {'draft', 'pilot', 'shared'});
            tc.verifyEqual(r.sets, {{'draft', 'pilot', 'shared'}});
            tc.verifyEqual(r.applied, true);
            tc.verifyEqual(r.why, "");
            tc.verifyFalse(isvalid(dlg.Fig), 'OK closes the window');
            dlg.ok();
            dlg.cancel();
            tc.verifyNumElements(tc.Got, 1, 'OnDone is called once');
        end

        function singleAddTyped(tc)
            dlg = tc.open({{}}, {}, Labels="rec1");
            dlg.addTyped(" Pilot , draft,,");
            tc.verifyEqual(dlg.Pending, {'draft', 'pilot'}, 'trimmed, lowercased, sorted; blank pieces ignored');
            tc.verifyEqual(dlg.ErrorText, "");

            dlg.Ctl.NewTag.Value = 'bad tag!';
            dlg.addTyped(dlg.Ctl.NewTag.Value);
            tc.verifyEqual(dlg.Pending, {'draft', 'pilot'}, 'nothing added');
            tc.verifySubstring(dlg.ErrorText, 'tag "bad tag!" is not allowed');
            tc.verifyEqual(dlg.Ctl.Error.FontColor, [0.75 0.1 0.1]);
            tc.verifyEqual(dlg.Ctl.NewTag.Value, 'bad tag!', 'the field keeps what was typed to fix it');

            dlg.addTyped("ok1, x y, z;");
            tc.verifyEqual(dlg.Pending, {'draft', 'pilot'}, 'a mix adds nothing');
            tc.verifySubstring(dlg.ErrorText, 'tag "x y"');
            tc.verifySubstring(dlg.ErrorText, 'tag "z;"');
            tc.verifyNumElements(splitlines(dlg.ErrorText), 2, 'one line per bad entry');

            dlg.addTyped("ok1");
            tc.verifyEqual(dlg.Pending, {'draft', 'ok1', 'pilot'});
            tc.verifyEqual(dlg.ErrorText, "", 'a successful action clears the message');
            tc.verifyEqual(dlg.Ctl.NewTag.Value, '', 'the field is emptied');
        end

        function singleRemoveAndClear(tc)
            dlg = tc.open({{'a', 'b', 'c'}}, {'z'}, Labels="rec1");
            dlg.removeCurrent({'b'});
            tc.verifyEqual(dlg.Pending, {'a', 'c'});
            tc.verifyEqual(dlg.Ctl.Available.ItemsData, {'b', 'z'}, 'a removed tag is offered again');
            dlg.clearAll();
            tc.verifyEqual(dlg.Pending, {});
            dlg.ok();
            tc.verifyEqual(tc.Got{1}.tags, {});
            tc.verifyEqual(tc.Got{1}.sets, {{}});
        end

        function singleOverTheLimitIsRefused(tc)
            full = compose("t%02d", 1:TagSet.MaxTags);
            dlg = tc.open({full}, {}, Labels="rec1");
            dlg.addTyped("extra1, extra2");
            tc.verifyEqual(dlg.Pending, cellstr(full), 'nothing added');
            tc.verifyEqual(dlg.ErrorText, "Cannot add 2 tags: rec1 would have 14 tags, 2 over the limit of 12");
            tc.verifyTrue(isvalid(dlg.Fig), 'the window stays open');
            dlg.ok();
            tc.verifyEqual(tc.Got, {[]}, 'OK with no change closes with []');
            tc.verifyFalse(isvalid(dlg.Fig));
        end

        function cancelAndCloseGiveEmpty(tc)
            dlg = tc.open({{'a'}}, {}, Labels="rec1");
            dlg.pick({'b'});
            dlg.cancel();
            tc.assertNumElements(tc.Got, 1);
            tc.verifyEqual(tc.Got{1}, []);
            tc.verifyFalse(isvalid(dlg.Fig));

            dlg = tc.open({{'a'}}, {}, Labels="rec1");
            dlg.Fig.CloseRequestFcn(dlg.Fig, []);
            tc.assertNumElements(tc.Got, 2);
            tc.verifyEqual(tc.Got{2}, [], 'the window''s close button cancels');
            tc.verifyFalse(isvalid(dlg.Fig));
        end

        function okWithoutChangeGivesEmpty(tc)
            dlg = tc.open({{'a'}}, {'b'}, Labels="rec1");
            dlg.pick({'b'});
            dlg.removeCurrent({'b'});
            dlg.ok();
            tc.verifyEqual(tc.Got, {[]});
        end

        function controlsTakeTheMethodsPaths(tc)
            dlg = tc.open({{'a'}}, {'b', 'c'}, Labels="rec1");
            c = dlg.Ctl;
            c.Available.Value = {'b'};
            c.AddSelected.ButtonPushedFcn(c.AddSelected, []);
            tc.verifyEqual(dlg.Pending, {'a', 'b'}, 'Add selected');
            c.Available.Value = {'c'};
            c.Available.DoubleClickedFcn(c.Available, []);
            tc.verifyEqual(dlg.Pending, {'a', 'b', 'c'}, 'double-click on Available');
            c.Current.Value = {'a'};
            c.Current.DoubleClickedFcn(c.Current, []);
            tc.verifyEqual(dlg.Pending, {'b', 'c'}, 'double-click on Current');
            c.Current.Value = {'b'};
            c.RemoveSelected.ButtonPushedFcn(c.RemoveSelected, []);
            tc.verifyEqual(dlg.Pending, {'c'}, 'Remove selected');
            c.NewTag.Value = 'Typed';
            c.NewTag.ValueChangedFcn(c.NewTag, []);
            tc.verifyEqual(dlg.Pending, {'c', 'typed'}, 'Enter in the field');
            tc.verifyEqual(c.NewTag.Value, '');
            c.NewTag.Value = 'more';
            c.AddTyped.ButtonPushedFcn(c.AddTyped, []);
            tc.verifyEqual(dlg.Pending, {'c', 'more', 'typed'}, 'the Add button');
            c.ClearAll.ButtonPushedFcn(c.ClearAll, []);
            tc.verifyEqual(dlg.Pending, {});
            c.OK.ButtonPushedFcn(c.OK, []);
            tc.verifyEqual(tc.Got{1}.tags, {});
            dlg = tc.open({{'a'}}, {}, Labels="rec1");
            dlg.Ctl.Cancel.ButtonPushedFcn(dlg.Ctl.Cancel, []);
            tc.verifyEqual(tc.Got{2}, []);
        end

        function singleHasNoBulkControls(tc)
            dlg = tc.open({{'a'}}, {}, Labels="rec1");
            tc.verifyEqual(string(dlg.Ctl.Summary.Visible), "off");
            tc.verifyError(@() dlg.setMode("add"), 'TagDialog:BadMode');
        end

        function centersOnTheParent(tc)
            p = uifigure("Visible", "off", "Position", [200 150 1200 800]);
            tc.addTeardown(@delete, p);
            dlg = tc.open({{'a'}}, {}, Parent=p);
            q = dlg.Fig.Position;
            tc.verifyEqual(q(1:2) + q(3:4) / 2, [200 150] + [1200 800] / 2, 'AbsTol', 1);
        end

        function badOptionsError(tc)
            tc.verifyError(@() TagDialog({}, {}, Visible=false), 'TagDialog:NoTargets');
            tc.verifyError(@() TagDialog({{'a'}, {'b'}}, {}, Visible=false, Policy="maybe"), 'TagDialog:BadPolicy');
        end

        % ---- bulk mode ----
        function bulkSummarizesTheTargets(tc)
            dlg = tc.open({{'a', 'b'}, {'a', 'c'}, {'a'}}, {'z'}, Labels=["d1" "d2" "d3"]);
            tc.verifyEqual(dlg.Mode, "add");
            tc.verifyEqual(dlg.Pending, {}, 'nothing to add yet');
            tc.verifyEqual(string(dlg.Ctl.Title.Text), "Tags of 3 ticked datasets");
            tc.verifyEqual(string(dlg.Ctl.Summary.Text), ["On all: a"; "On some: b (1 of 3), c (1 of 3)"]);
            tc.verifyEqual(dlg.Ctl.Available.ItemsData, {'a', 'b', 'c', 'z'});
            tc.verifyEqual(string(dlg.Ctl.Policy.Visible), "on");
        end

        function bulkAddReachesEveryTarget(tc)
            dlg = tc.open({{'a', 'b'}, {'c'}}, {}, Labels=["d1" "d2"]);
            dlg.pick({'b'});
            dlg.addTyped("New");
            tc.verifyEqual(dlg.Pending, {'b', 'new'});
            dlg.ok();
            r = tc.Got{1};
            tc.verifyEqual(r.mode, "add");
            tc.verifyEqual(r.tags, {'b', 'new'});
            tc.verifyEqual(r.sets, {{'a', 'b', 'new'}, {'b', 'c', 'new'}});
            tc.verifyEqual(r.applied, [true true]);
            tc.verifyEqual(r.why, ["" ""]);
        end

        function bulkRemoveFromEveryTarget(tc)
            dlg = tc.open({{'a', 'b'}, {'a', 'c'}, {'a'}}, {'z'}, Labels=["d1" "d2" "d3"]);
            dlg.pick({'x'});
            dlg.setMode("remove");
            tc.verifyEqual(dlg.Pending, {}, 'a mode change starts the list afresh');
            tc.verifyEqual(string(dlg.Ctl.Policy.Visible), "off", 'a removal cannot exceed the limit');
            tc.verifyEqual(string(dlg.Ctl.Available.Items), ["a (3 of 3)" "b (1 of 3)" "c (1 of 3)"]);
            dlg.pick({'z'});
            tc.verifySubstring(dlg.ErrorText, "None of the 3 datasets has z");
            tc.verifyEqual(dlg.Pending, {});
            dlg.pick({'a', 'b'});
            tc.verifyEqual(dlg.ErrorText, "");
            tc.verifyEqual(string(dlg.Ctl.Current.Items), ["a (3 of 3)" "b (1 of 3)"]);
            dlg.ok();
            r = tc.Got{1};
            tc.verifyEqual(r.mode, "remove");
            tc.verifyEqual(r.tags, {'a', 'b'});
            tc.verifyEqual(r.sets, {{}, {'c'}, {}});
            tc.verifyEqual(r.applied, true(1, 3));
        end

        function bulkClearAll(tc)
            dlg = tc.open({{'a', 'b'}, {'c'}}, {}, Labels=["d1" "d2"]);
            dlg.pick({'a'});
            dlg.clearAll();
            tc.verifyEqual(dlg.Pending, {}, 'Add mode: nothing to add');
            dlg.setMode("remove");
            dlg.clearAll();
            tc.verifyEqual(dlg.Pending, {'a', 'b', 'c'}, 'Remove mode: every tag of the targets');
            dlg.Ctl.Mode.Value = 'add';
            dlg.Ctl.Mode.ValueChangedFcn(dlg.Ctl.Mode, []);
            tc.verifyEqual(dlg.Mode, "add", 'the Mode dropdown');
        end

        function overTheLimitUnderAllKeepsTheWindowOpen(tc)
            full = compose("t%02d", 1:TagSet.MaxTags);
            dlg = tc.open({full, {'a'}, full}, {}, Labels=["full1" "small" "full2"]);
            dlg.addTyped("new1, new2");
            dlg.ok();
            tc.verifyEmpty(tc.Got, 'nothing applied');
            tc.verifyTrue(isvalid(dlg.Fig));
            tc.verifyEqual(dlg.ErrorText, ...
                "Cannot add 2 tags: full1 would have 14 tags, 2 over the limit of 12" + newline + ...
                "Cannot add 2 tags: full2 would have 14 tags, 2 over the limit of 12");
            tc.verifyEqual(dlg.OKText, "OK");
            dlg.removeCurrent({'new2'});
            tc.verifyEqual(dlg.ErrorText, "");
            dlg.ok();
            tc.verifyEmpty(tc.Got, 'one over is still over');
            tc.verifySubstring(dlg.ErrorText, "Cannot add 1 tag: full1 would have 13 tags, 1 over the limit of 12");
        end

        function overTheLimitUnderSkipConfirmsOnce(tc)
            full = compose("t%02d", 1:TagSet.MaxTags);
            dlg = tc.open({full, {'a'}}, {}, Labels=["full" "small"]);
            dlg.addTyped("new1, new2");
            dlg.setPolicy("skip");
            tc.verifyEqual(string(dlg.Ctl.Policy.Value), "skip");
            dlg.ok();
            tc.verifyEmpty(tc.Got, 'the first OK only shows what would be skipped');
            tc.verifyTrue(isvalid(dlg.Fig));
            tc.verifyEqual(dlg.ErrorText, "Will skip 1 of 2 datasets: full (14 tags, 2 over the limit of 12)");
            tc.verifyEqual(dlg.OKText, "Apply to 1");
            dlg.ok();
            tc.assertNumElements(tc.Got, 1);
            r = tc.Got{1};
            tc.verifyEqual(r.mode, "add");
            tc.verifyEqual(r.policy, "skip");
            tc.verifyEqual(r.applied, [false true]);
            tc.verifyEqual(r.why, ["14 tags, 2 over the limit of 12" ""]);
            tc.verifyEqual(r.sets, {cellstr(full), {'a', 'new1', 'new2'}}, 'the skipped target stays as given');
            tc.verifyFalse(isvalid(dlg.Fig));
        end

        function anyChangeWithdrawsTheSkipConfirmation(tc)
            full = compose("t%02d", 1:TagSet.MaxTags);
            dlg = tc.open({full, {'a'}}, {}, Labels=["full" "small"], Policy="skip");
            tc.verifyEqual(dlg.Policy, "skip", 'the policy passed in');
            dlg.addTyped("new1");
            changes = {@() dlg.addTyped("new2"), @() dlg.removeCurrent({'new2'}), ...
                @() dlg.pick({'a'}), @() dlg.setPolicy("all"), @() dlg.setMode("remove")};
            for k = 1:numel(changes)
                if dlg.Policy == "all"; dlg.setPolicy("skip"); end
                if dlg.Mode == "remove"; dlg.setMode("add"); dlg.addTyped("new1"); end
                dlg.ok();
                tc.verifyEqual(dlg.OKText, "Apply to 1", sprintf('change %d: armed', k));
                changes{k}();
                tc.verifyEqual(dlg.OKText, "OK", sprintf('change %d withdraws the confirmation', k));
                tc.verifyFalse(startsWith(dlg.ErrorText, "Will skip"), sprintf('change %d clears the skip list', k));
            end
            tc.verifyEmpty(tc.Got, 'nothing applied along the way');
            % After a withdrawn confirmation OK asks again rather than applying.
            dlg.setMode("add");
            dlg.addTyped("new1");
            dlg.setPolicy("skip");
            dlg.ok();
            dlg.addTyped("new3");
            dlg.ok();
            tc.verifyEmpty(tc.Got);
            tc.verifyEqual(dlg.OKText, "Apply to 1");
            tc.verifySubstring(dlg.ErrorText, "full (14 tags, 2 over the limit of 12)");
        end

        function skipWhenNothingFitsIsRefused(tc)
            full = compose("t%02d", 1:TagSet.MaxTags);
            dlg = tc.open({full, full}, {}, Labels=["f1" "f2"], Policy="skip");
            dlg.addTyped("new1");
            dlg.ok();
            tc.verifyEmpty(tc.Got);
            tc.verifyEqual(dlg.OKText, "OK", 'no Apply to 0');
            tc.verifySubstring(dlg.ErrorText, "Cannot add 1 tag: f1 would have 13 tags");
        end
    end
end
