classdef test_TagSet < matlab.unittest.TestCase
    %test_TagSet  TagSet: the tag rules, the set operations and the text forms.
    %   Every tag set is a unique, sorted, lowercase cell row, and {} (0x0)
    %   is the only empty one; reading text never errors on its content,
    %   the editing methods that must stay valid do; bulkApply checks every
    %   target first and obeys its policy; the filter and the text forms
    %   round-trip, also through jsonencode / jsondecode.
    %
    %   Usage:  runtests("test_TagSet")

    methods (Test)
        % ---- canon ----
        function canonFromEveryContainer(tc)
            tc.verifyEqual(TagSet.canon('a'), {'a'});
            tc.verifyEqual(TagSet.canon("a"), {'a'});
            tc.verifyEqual(TagSet.canon(["b" "a"]), {'b', 'a'});
            tc.verifyEqual(TagSet.canon(["b"; "a"]), {'b', 'a'}, 'a string column comes back as a row');
            tc.verifyEqual(TagSet.canon({'b', 'a'}), {'b', 'a'});
            tc.verifyEqual(TagSet.canon({'b'; 'a'}), {'b', 'a'}, 'an Nx1 cell (jsondecode) comes back as a row');
            tc.verifyEqual(TagSet.canon({"b", 'a'}), {'b', 'a'}, 'a cell of strings and chars');
            tc.verifyEqual(TagSet.canon(['ab'; 'cd']), {'ab', 'cd'}, 'a char matrix is one tag per row');
        end

        function canonOfNothingIsTheEmptyCell(tc)
            for in = {[], {}, '', "", string(missing), strings(1, 0), cell(1, 0), cell(0, 1), zeros(1, 0), char(zeros(1, 0))}
                t = TagSet.canon(in{1});
                tc.verifyEqual(t, {}, sprintf('%s %s', class(in{1}), mat2str(size(in{1}))));
                tc.verifySize(t, [0 0]);
            end
        end

        function canonTrimsAndLowercases(tc)
            tc.verifyEqual(TagSet.canon('  Pilot '), {'pilot'});
            tc.verifyEqual(TagSet.canon({' A', 'B  ', sprintf('\tC\n')}), {'a', 'b', 'c'});
            tc.verifyEqual(TagSet.canon(" Draft "), {'draft'});
        end

        function canonKeepsOrderDuplicatesAndBadEntries(tc)
            tc.verifyEqual(TagSet.canon({'b', 'A', 'a', 'x y', ''}), {'b', 'a', 'a', 'x y', ''}, ...
                'nothing is dropped, deduplicated, sorted or validated');
            tc.verifyEqual(TagSet.canon(["a" "" "b"]), {'a', '', 'b'});
            tc.verifyEqual(TagSet.canon(["a" missing]), {'a', ''}, 'a missing string is an empty entry');
            e = TagSet.canon({'a', ''});
            tc.verifySize(e{2}, [0 0], 'one shape for an empty entry');
        end

        function canonRefusesWhatIsNotText(tc)
            tc.verifyError(@() TagSet.canon(5), 'TagSet:BadInput');
            tc.verifyError(@() TagSet.canon({'a', 5}), 'TagSet:BadInput');
            tc.verifyError(@() TagSet.canon({{'a'}}), 'TagSet:BadInput');
            tc.verifyError(@() TagSet.canon(struct('a', 1)), 'TagSet:BadInput');
        end

        % ---- check ----
        function checkAcceptsEveryAllowedCharacter(tc)
            for tag = {'a', 'z', '0', '9', 'a-b', 'a_b', 'a.b', 'abc-123_x.y', repmat('a', 1, 50), '-', '.', '_'}
                [ok, why] = TagSet.check(tag{1});
                tc.verifyTrue(ok, tag{1});
                tc.verifyEqual(why, "");
            end
            [ok, why] = TagSet.check("pilot");
            tc.verifyTrue(ok, 'a string scalar is accepted');
            tc.verifyEqual(why, "");
        end

        function checkRefusesEachRule(tc)
            msg = @(t) sprintf('tag "%s" is not allowed: 1 to 50 characters, letters, digits, - _ . only', t);
            bad = {'', repmat('a', 1, 51), 'x y', 'a,b', 'a;b', 'caf\xe9', 'a/b', 'a!', sprintf('a\n'), sprintf('\t')};
            bad{6} = ['caf' char(233)];
            for k = 1:numel(bad)
                [ok, why] = TagSet.check(bad{k});
                tc.verifyFalse(ok, sprintf('entry %d', k));
                tc.verifyEqual(why, string(msg(bad{k})), sprintf('entry %d', k));
            end
            [~, why] = TagSet.check('x y');
            tc.verifyEqual(why, "tag ""x y"" is not allowed: 1 to 50 characters, letters, digits, - _ . only");
        end

        function checkDoesNotLowercase(tc)
            % canon runs first in every caller, so an uppercase tag never reaches check
            % through them; check itself holds the tag to the rule as given.
            tc.verifyFalse(TagSet.check('Pilot'));
            c = TagSet.canon('Pilot');
            tc.verifyTrue(TagSet.check(c{1}));
        end

        function checkRefusesNonText(tc)
            tc.verifyError(@() TagSet.check(5), 'TagSet:BadInput');
            tc.verifyError(@() TagSet.check({'a'}), 'TagSet:BadInput');
        end

        % ---- parse ----
        function parseKeepsTheValidOnesSortedAndUnique(tc)
            [t, bad, why] = TagSet.parse({'pilot', 'Draft', 'draft', ' PILOT ', 'a-1'});
            tc.verifyEqual(t, {'a-1', 'draft', 'pilot'});
            tc.verifyEqual(bad, {});
            tc.verifySize(bad, [0 0]);
            tc.verifyEqual(why, strings(1, 0));
        end

        function parseReportsTheBadOnesWithMessages(tc)
            [t, bad, why] = TagSet.parse({'ok', 'bad tag!', 'x y', 'x y', '', 'fine'});
            tc.verifyEqual(t, {'fine', 'ok'});
            tc.verifyEqual(bad, {'bad tag!', 'x y', ''}, 'in the order given, each once');
            tc.verifySize(why, [1 3]);
            tc.verifyEqual(why(1), "tag ""bad tag!"" is not allowed: 1 to 50 characters, letters, digits, - _ . only");
            tc.verifyEqual(why(2), "tag ""x y"" is not allowed: 1 to 50 characters, letters, digits, - _ . only");
            tc.verifyEqual(why(3), "tag """" is not allowed: 1 to 50 characters, letters, digits, - _ . only");
        end

        function parseIsIndependentOfOrderAndCase(tc)
            a = TagSet.parse({'B', 'a', 'C'});
            b = TagSet.parse({'c', 'A', 'b'});
            tc.verifyEqual(a, b);
            tc.verifyEqual(a, {'a', 'b', 'c'});
        end

        function parseNeverErrorsOnContentOrCount(tc)
            many = compose("t%d", 1:20);
            [t, bad] = TagSet.parse([many "bad tag"]);
            tc.verifyNumElements(t, 20, 'parse does not apply MaxTags');
            tc.verifyEqual(bad, {'bad tag'});
        end

        function parseOfNothingAndOfAJsondecodeShape(tc)
            [t, bad, why] = TagSet.parse([]);
            tc.verifyEqual(t, {});
            tc.verifyEqual(bad, {});
            tc.verifyEqual(why, strings(1, 0));
            tc.verifyEqual(TagSet.parse({}), {});
            tc.verifyEqual(TagSet.parse(''), {});
            tc.verifyEqual(TagSet.parse({'Pilot'}), {'pilot'});
            tc.verifyEqual(TagSet.parse({'b'; 'a'}), {'a', 'b'});
        end

        % ---- require ----
        function requireReturnsTheValidSet(tc)
            tc.verifyEqual(TagSet.require({'B', 'a', 'b'}), {'a', 'b'});
            tc.verifyEqual(TagSet.require([]), {});
            tc.verifyEqual(TagSet.require("x"), {'x'});
        end

        function requireNamesEveryBadEntry(tc)
            try
                TagSet.require({'ok', 'bad one', 'worse!', 'fine'});
                tc.verifyFail('expected TagSet:Invalid');
            catch err
                tc.verifyEqual(err.identifier, 'TagSet:Invalid');
                tc.verifySubstring(err.message, 'tag "bad one" is not allowed');
                tc.verifySubstring(err.message, 'tag "worse!" is not allowed');
                tc.verifyFalse(contains(err.message, '"ok"') || contains(err.message, '"fine"'), 'valid entries are not named');
            end
        end

        function requireLimitsTheCount(tc)
            twelve = compose("t%d", 1:12);
            tc.verifyNumElements(TagSet.require(twelve), 12, '12 is allowed');
            try
                TagSet.require([twelve "t13"]);
                tc.verifyFail('expected TagSet:TooMany');
            catch err
                tc.verifyEqual(err.identifier, 'TagSet:TooMany');
                tc.verifyEqual(err.message, '13 tags, 1 over the limit of 12');
            end
            tc.verifyError(@() TagSet.require(compose("t%d", 1:14)), 'TagSet:TooMany');
        end

        function requireReportsInvalidBeforeTooMany(tc)
            tc.verifyError(@() TagSet.require([compose("t%d", 1:14) "bad one"]), 'TagSet:Invalid');
        end

        % ---- checkCount ----
        function checkCountMessage(tc)
            [ok, why] = TagSet.checkCount(compose("t%d", 1:12));
            tc.verifyTrue(ok);
            tc.verifyEqual(why, "");
            [ok, why] = TagSet.checkCount(compose("t%d", 1:14));
            tc.verifyFalse(ok);
            tc.verifyEqual(why, "14 tags, 2 over the limit of 12");
            [ok, why] = TagSet.checkCount({});
            tc.verifyTrue(ok);
            tc.verifyEqual(why, "");
            [ok, ~] = TagSet.checkCount(repmat({'a'}, 1, 30));
            tc.verifyTrue(ok, 'only distinct tags count');
        end

        % ---- add / remove / clear / union / intersect ----
        function addKeepsTheSetSortedAndUnique(tc)
            tc.verifyEqual(TagSet.add({'b'}, {'C', 'a', 'b'}), {'a', 'b', 'c'});
            tc.verifyEqual(TagSet.add({}, 'x'), {'x'});
            tc.verifyEqual(TagSet.add({}, []), {});
            tc.verifyEqual(TagSet.add({'a'}, "A"), {'a'}, 'case does not make a new tag');
        end

        function addIsValidated(tc)
            tc.verifyError(@() TagSet.add({'a'}, 'bad tag'), 'TagSet:Invalid');
            tc.verifyError(@() TagSet.add(compose("t%d", 1:12), 'one-more'), 'TagSet:TooMany');
            tc.verifyEqual(TagSet.add(compose("t%d", 1:12), 't3'), sort(cellstr(compose("t%d", 1:12))), ...
                'adding a tag already there fits');
        end

        function removeSetdiffStaysSorted(tc)
            tc.verifyEqual(TagSet.remove({'a', 'b', 'c'}, {'B'}), {'a', 'c'});
            tc.verifyEqual(TagSet.remove({'c', 'a'}, 'zzz'), {'a', 'c'}, 'a tag that is absent is ignored');
            tc.verifyEqual(TagSet.remove({'a'}, {'a'}), {});
            tc.verifySize(TagSet.remove({'a'}, {'a'}), [0 0]);
            tc.verifyEqual(TagSet.remove({}, {'a'}), {});
            tc.verifyEqual(TagSet.remove({'b', 'a'}, []), {'a', 'b'});
        end

        function clearIsTheEmptyCell(tc)
            tc.verifyEqual(TagSet.clear(), {});
            tc.verifySize(TagSet.clear(), [0 0]);
        end

        function unionAndIntersect(tc)
            tc.verifyEqual(TagSet.union({'b', 'a'}, {'C', 'a'}), {'a', 'b', 'c'});
            tc.verifyEqual(TagSet.union({}, {}), {});
            tc.verifyEqual(TagSet.union({'a'}, []), {'a'});
            tc.verifyEqual(TagSet.intersect({'a', 'b', 'c'}, {'C', 'b', 'x'}), {'b', 'c'});
            i = TagSet.intersect({'a'}, {'b'});
            tc.verifyEqual(i, {});
            tc.verifySize(i, [0 0]);
            tc.verifyEqual(TagSet.intersect({}, {'a'}), {});
            tc.verifyEqual(TagSet.union({'a'; 'b'}, {'c'; 'a'}), {'a', 'b', 'c'}, 'Nx1 cells (jsondecode) are accepted');
        end

        function everyReturnedSetHasOneShape(tc)
            sets = {TagSet.parse({'a'}), TagSet.add({}, 'a'), TagSet.remove({'a', 'b'}, 'b'), ...
                TagSet.union({'a'}, {}), TagSet.intersect({'a', 'b'}, {'a'}), TagSet.vocabulary({{'a'}}), ...
                TagSet.require('a')};
            for k = 1:numel(sets)
                tc.verifySize(sets{k}, [1 1], sprintf('one tag is 1x1 (set %d)', k));
                tc.verifyClass(sets{k}, 'cell');
            end
            empties = {TagSet.parse([]), TagSet.add({}, {}), TagSet.remove({'a'}, 'a'), TagSet.union({}, {}), ...
                TagSet.intersect({'a'}, {'b'}), TagSet.vocabulary({}), TagSet.require({}), TagSet.clear(), ...
                TagSet.fromText("", ",")};
            for k = 1:numel(empties)
                tc.verifyEqual(empties{k}, {}, sprintf('empty set %d', k));
                tc.verifySize(empties{k}, [0 0]);
            end
            two = TagSet.union({'b'}, {'a'});
            tc.verifySize(two, [1 2], 'two tags are a row');
        end

        % ---- summarize / vocabulary ----
        function summarizeSplitsCommonAndSome(tc)
            sets = {{'a', 'b'}, {'a', 'c'}, {'a', 'b', 'c', 'd'}};
            [common, some, counts] = TagSet.summarize(sets);
            tc.verifyEqual(common, {'a'});
            tc.verifyEqual(some, {'b', 'c', 'd'});
            tc.verifyEqual(counts, [3 2 2 1], 'aligned with the sorted vocabulary a b c d');
            tc.verifyEqual(TagSet.vocabulary(sets), {'a', 'b', 'c', 'd'});
        end

        function summarizeEdgeCases(tc)
            [common, some, counts] = TagSet.summarize({{'b', 'a'}});
            tc.verifyEqual(common, {'a', 'b'}, 'with one set every tag is common');
            tc.verifyEqual(some, {});
            tc.verifyEqual(counts, [1 1]);

            [common, some, counts] = TagSet.summarize({{}, {}});
            tc.verifyEqual(common, {});
            tc.verifyEqual(some, {});
            tc.verifyEmpty(counts);

            [common, some, counts] = TagSet.summarize({});
            tc.verifyEqual(common, {});
            tc.verifyEqual(some, {});
            tc.verifyEmpty(counts);

            [common, some] = TagSet.summarize({{'a'}, {}});
            tc.verifyEqual(common, {}, 'an empty set shares nothing');
            tc.verifyEqual(some, {'a'});

            [common, some, counts] = TagSet.summarize({{'x'}, {'X'}});
            tc.verifyEqual(common, {'x'});
            tc.verifyEqual(some, {});
            tc.verifyEqual(counts, 2);

            [~, ~, counts] = TagSet.summarize({{'a', 'a'}, {'a'}});
            tc.verifyEqual(counts, 2, 'a tag counts once per set');
        end

        function vocabularyIsTheSortedUnion(tc)
            tc.verifyEqual(TagSet.vocabulary({{'b'}, {'A', 'c'}, {}, {'b'}}), {'a', 'b', 'c'});
            tc.verifyEqual(TagSet.vocabulary({}), {});
            tc.verifyEqual(TagSet.vocabulary({{}, {}}), {});
            tc.verifyEqual(TagSet.vocabulary({{'b'}; {'a'}}), {'a', 'b'}, 'a column of sets');
            tc.verifyEqual(TagSet.vocabulary({'z', 'y'}), {'y', 'z'}, 'a flat cellstr is a list of one-tag sets');
        end

        function aSetListMustBeACell(tc)
            tc.verifyError(@() TagSet.vocabulary('abc'), 'TagSet:BadInput');
            tc.verifyError(@() TagSet.summarize(5), 'TagSet:BadInput');
            tc.verifyEqual(TagSet.vocabulary([]), {});
        end

        % ---- bulkApply ----
        function bulkAddFittingEverySet(tc)
            sets = {{'a'}, {}, {'b', 'c'}};
            [n, ok, why] = TagSet.bulkApply(sets, "add", {'Z', 'a'});
            tc.verifyEqual(n, {{'a', 'z'}, {'a', 'z'}, {'a', 'b', 'c', 'z'}});
            tc.verifyEqual(ok, true(1, 3));
            tc.verifyEqual(why, strings(1, 3));
            tc.verifyClass(ok, 'logical');
        end

        function bulkRemoveNeverFails(tc)
            full = cellstr(compose("t%d", 1:12));
            sets = {full, {'a', 'b'}, {}};
            [n, ok, why] = TagSet.bulkApply(sets, "remove", {'a', 't1'});
            tc.verifyEqual(ok, true(1, 3));
            tc.verifyEqual(why, strings(1, 3));
            tc.verifyEqual(n{1}, setdiff(full, {'t1'}));
            tc.verifyEqual(n{2}, {'b'});
            tc.verifyEqual(n{3}, {});
            [n, ok] = TagSet.bulkApply({{'a'}}, "remove", {'a'}, "all");
            tc.verifyEqual(n, {{}});
            tc.verifyTrue(ok);
        end

        function bulkPolicyAllLeavesEverythingWhenOneIsOver(tc)
            full = cellstr(compose("t%d", 1:12));
            sets = {{'a'}, full, {'b'}};
            [n, ok, why] = TagSet.bulkApply(sets, "add", {'new'}, "all");
            tc.verifyEqual(n, sets, 'nothing to write');
            tc.verifyEqual(ok, [true false true]);
            tc.verifyEqual(why, ["" "13 tags, 1 over the limit of 12" ""]);
            [n2, ok2, why2] = TagSet.bulkApply(sets, "add", {'new'});
            tc.verifyEqual(n2, n, 'the default policy is "all"');
            tc.verifyEqual(ok2, ok);
            tc.verifyEqual(why2, why);
        end

        function bulkPolicySkipEditsTheOthers(tc)
            full = cellstr(compose("t%d", 1:12));
            sets = {{'a'}, full, {'B'}};
            [n, ok, why] = TagSet.bulkApply(sets, "add", {'new'}, "skip");
            tc.verifyEqual(ok, [true false true]);
            tc.verifyEqual(why(2), "13 tags, 1 over the limit of 12");
            tc.verifyEqual(n{1}, {'a', 'new'});
            tc.verifyEqual(n{2}, full, 'the one that does not fit stays as given');
            tc.verifyEqual(n{3}, {'b', 'new'});
        end

        function bulkNamesHowFarOver(tc)
            sets = {cellstr(compose("t%d", 1:11)), cellstr(compose("t%d", 1:12))};
            [~, ok, why] = TagSet.bulkApply(sets, "add", {'x', 'y', 'z'}, "skip");
            tc.verifyEqual(ok, [false false]);
            tc.verifyEqual(why, ["14 tags, 2 over the limit of 12" "15 tags, 3 over the limit of 12"]);
        end

        function bulkAddingWhatIsAlreadyThereFits(tc)
            full = cellstr(compose("t%d", 1:12));
            [n, ok] = TagSet.bulkApply({full}, "add", {'t5'}, "all");
            tc.verifyTrue(ok);
            tc.verifyEqual(n{1}, sort(full(:)).');
        end

        function bulkErrors(tc)
            tc.verifyError(@() TagSet.bulkApply({{'a'}}, "toggle", {'a'}), 'TagSet:BadMode');
            tc.verifyError(@() TagSet.bulkApply({{'a'}}, "add", {'a'}, "some"), 'TagSet:BadPolicy');
            tc.verifyError(@() TagSet.bulkApply({{'a'}}, "add", {'bad tag'}), 'TagSet:Invalid');
        end

        function bulkAcceptsCharAndCaseInModeAndPolicy(tc)
            n = TagSet.bulkApply({{'a'}}, 'Add', 'b', 'SKIP');
            tc.verifyEqual(n, {{'a', 'b'}});
        end

        function bulkWithNoSets(tc)
            [n, ok, why] = TagSet.bulkApply({}, "add", {'a'});
            tc.verifyEqual(n, {});
            tc.verifySize(ok, [1 0]);
            tc.verifySize(why, [1 0]);
        end

        function bulkKeepsTheShapeOfTheSets(tc)
            [n, ok] = TagSet.bulkApply({{'a'}; {'b'}}, "add", {'x'});
            tc.verifySize(n, [2 1]);
            tc.verifySize(ok, [1 2]);
        end

        function bulkTooManyToAddIsNotAnError(tc)
            [n, ok] = TagSet.bulkApply({{}, {'a'}}, "add", compose("t%d", 1:13), "skip");
            tc.verifyEqual(ok, [false false]);
            tc.verifyEqual(n, {{}, {'a'}});
        end

        % ---- matches ----
        function matchesAnyAndAll(tc)
            sets = {{'a', 'b'}, {'b'}, {}, {'a', 'b', 'c'}};
            tc.verifyEqual(TagSet.matches(sets, {'a', 'c'}, "any"), [true false false true]);
            tc.verifyEqual(TagSet.matches(sets, {'a', 'c'}, "all"), [false false false true]);
            tc.verifyEqual(TagSet.matches(sets, 'b'), [true true false true], 'any is the default');
            tc.verifyEqual(TagSet.matches(sets, {'A'}, "all"), [true false false true], 'case is ignored');
        end

        function matchesEmptySelectionPassesEverything(tc)
            sets = {{'a'}, {}};
            for mode = ["any" "all"]
                tc.verifyEqual(TagSet.matches(sets, {}, mode), [true true]);
                tc.verifyEqual(TagSet.matches(sets, [], mode), [true true]);
                tc.verifyEqual(TagSet.matches(sets, "", mode), [true true]);
            end
            tc.verifyEqual(TagSet.matches({}, {'a'}), true(1, 0));
        end

        function matchesAnInvalidTermMatchesNothing(tc)
            sets = {{'a'}, {'b'}};
            [t, bad] = TagSet.fromText("a, bad term", ",");
            tc.verifyEqual(TagSet.matches(sets, [t bad], "any"), [true false], 'any: the valid term still matches');
            tc.verifyEqual(TagSet.matches(sets, [t bad], "all"), [false false], 'all: the invalid one fails every set');
            tc.verifyEqual(TagSet.matches(sets, {'bad term'}, "any"), [false false]);
        end

        function matchesBadMode(tc)
            tc.verifyError(@() TagSet.matches({{'a'}}, {'a'}, "most"), 'TagSet:BadMode');
        end

        % ---- search ----
        function searchIsACaseInsensitiveSubstring(tc)
            sets = {{'pilot', 'draft'}, {'Final'}, {}, {'a-pil'}};
            tc.verifyEqual(TagSet.search(sets, "pil"), [true false false true]);
            tc.verifyEqual(TagSet.search(sets, "PIL"), [true false false true]);
            tc.verifyEqual(TagSet.search(sets, 'fin'), [false true false false], 'a char is accepted');
            tc.verifyEqual(TagSet.search(sets, "zzz"), false(1, 4));
            tc.verifyEqual(TagSet.search(sets, "t"), [true false false false], 'a substring anywhere in a tag');
        end

        function searchBlankPassesEverything(tc)
            sets = {{'a'}, {}};
            tc.verifyEqual(TagSet.search(sets, ""), [true true]);
            tc.verifyEqual(TagSet.search(sets, "   "), [true true]);
            tc.verifyEqual(TagSet.search({}, "a"), true(1, 0));
        end

        % ---- toText / fromText ----
        function toTextJoinsInTheOrderGiven(tc)
            tc.verifyEqual(TagSet.toText({'a', 'b'}, ";"), "a;b");
            tc.verifyEqual(TagSet.toText({'a', 'b'}, TagSet.DisplayDelimiter), "a, b");
            tc.verifyEqual(TagSet.toText({'a', 'b'}), "a, b", 'the display delimiter is the default');
            tc.verifyEqual(TagSet.toText({'a'}, ";"), "a");
            tc.verifyEqual(TagSet.toText({}, ";"), "");
            tc.verifyEqual(TagSet.toText([], ","), "");
            tc.verifyClass(TagSet.toText({}, ";"), 'string');
            tc.verifyEqual(TagSet.toText({'B', 'a'}, "|"), "b|a", 'lowercased, order kept');
        end

        function fromTextSplitsTrimsAndParses(tc)
            tc.verifyEqual(TagSet.fromText(' Pilot , draft', ','), {'draft', 'pilot'});
            tc.verifyEqual(TagSet.fromText("b;a;b", ";"), {'a', 'b'});
            tc.verifyEqual(TagSet.fromText("a,,b,", ","), {'a', 'b'}, 'blank pieces are ignored');
            tc.verifyEqual(TagSet.fromText("a, b", TagSet.EntryDelimiter), {'a', 'b'}, 'the entry delimiter is the default');
            tc.verifyEqual(TagSet.fromText("  ", ","), {});
            tc.verifyEqual(TagSet.fromText("a b", ";"), {}, 'a space is not a delimiter');
        end

        function fromTextReportsTheBadPieces(tc)
            [t, bad, why] = TagSet.fromText("ok, bad one, Fine, x!", ",");
            tc.verifyEqual(t, {'fine', 'ok'});
            tc.verifyEqual(bad, {'bad one', 'x!'});
            tc.verifySize(why, [1 2]);
            tc.verifySubstring(why(1), 'tag "bad one" is not allowed');
        end

        function fromTextOfNothing(tc)
            for in = {"", '', [], {}, string(missing)}
                [t, bad, why] = TagSet.fromText(in{1}, ",");
                tc.verifyEqual(t, {});
                tc.verifyEqual(bad, {});
                tc.verifyEqual(why, strings(1, 0));
            end
        end

        function textRoundTrips(tc)
            sets = {{'a'}, {'a', 'b', 'c'}, {'x-1', 'y_2', 'z.3'}, {}};
            for delim = [";" ","]
                for k = 1:numel(sets)
                    s = TagSet.toText(sets{k}, delim);
                    tc.verifyEqual(TagSet.fromText(s, delim), sets{k}, sprintf('set %d, "%s"', k, delim));
                end
            end
            tc.verifyEqual(TagSet.fromText("", ";"), {});
            tc.verifyEqual(TagSet.toText({}, ";"), "");
            tc.verifyEqual(TagSet.fromText(TagSet.toText({'a', 'b'}, TagSet.ExportDelimiter), TagSet.ExportDelimiter), {'a', 'b'});
        end

        % ---- json ----
        function jsonRoundTrip(tc)
            for set = {{}, {'a'}, {'a', 'b', 'c'}}
                t = set{1};
                txt = jsonencode(struct('tags', {t}));
                back = jsondecode(txt);
                tc.verifyEqual(TagSet.parse(back.tags), t, txt);
                tc.verifyEqual(TagSet.canon(back.tags), t, txt);
            end
            tc.verifyEqual(jsonencode({}), '[]', '{} writes as an empty array');
            tc.verifyEqual(jsonencode(cell(0, 0)), '[]');
            tc.verifyEqual(jsonencode({'a'}), '["a"]');
            tc.verifyEqual(jsonencode({'a', 'b'}), '["a","b"]');
        end

        function canonReadsWhateverJsondecodeGives(tc)
            tc.verifyEqual(TagSet.canon(jsondecode('[]')), {});
            tc.verifyEqual(TagSet.canon(jsondecode('["a"]')), {'a'});
            tc.verifyEqual(TagSet.canon(jsondecode('["a","b"]')), {'a', 'b'});
            tc.verifyEqual(TagSet.canon(jsondecode('""')), {});
            tc.verifyEqual(TagSet.canon(jsondecode('"a"')), {'a'});
            tc.verifyEqual(TagSet.canon(jsondecode('["Pilot","pilot","bad tag!","ok"]')), ...
                {'pilot', 'pilot', 'bad tag!', 'ok'});
            [t, bad] = TagSet.parse(jsondecode('["Pilot","pilot","bad tag!","ok"]'));
            tc.verifyEqual(t, {'ok', 'pilot'});
            tc.verifyEqual(bad, {'bad tag!'});
        end

        % ---- constants ----
        function theLimitsAreTheDocumentedOnes(tc)
            tc.verifyEqual(TagSet.MaxTags, 12);
            tc.verifyEqual(TagSet.MinLength, 1);
            tc.verifyEqual(TagSet.MaxLength, 50);
            tc.verifyEqual(TagSet.DisplayDelimiter, ", ");
            tc.verifyEqual(TagSet.ExportDelimiter, ";");
            tc.verifyEqual(TagSet.EntryDelimiter, ",");
        end
    end
end
