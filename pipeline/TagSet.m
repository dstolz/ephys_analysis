classdef TagSet
    % TagSet  Every rule about tags: what a tag is, how a set of them is kept, edited and matched.
    %   A tag is a short free-form label (draft, pilot, 2-shank, noisy.ch3)
    %   that the user puts on a dataset, and later on other things, to sort
    %   them into groups, filter on them and read them in exports. Tags are
    %   metadata only: no step, export or figure reads them to decide
    %   anything.
    %
    %   A tag is 1 to 50 characters (MinLength, MaxLength) of lowercase
    %   letters, digits, hyphen, underscore and period (Allowed). What the
    %   user types is trimmed and lowercased first, so " Pilot " is the tag
    %   pilot. A set holds at most 12 tags (MaxTags).
    %
    %   A set of tags is a cell row of character vectors, unique and sorted
    %   (ASCII order, so it does not depend on the order or the case of the
    %   entries) and {} when it holds none: {} (0x0) is the only empty set,
    %   never cell(1,0) and never []. jsonencode writes a set as a JSON
    %   array of strings ({} as []); jsondecode gives it back as an Nx1
    %   cell (a 1x1 cell for one tag, [] for none), which canon reads.
    %
    %   TagSet holds every tag rule. The tag dialog, the tables, the filter
    %   and the exports call it and hold none of their own. It never sees
    %   what a set belongs to (a dataset, a unit, a signal): it works on
    %   cell arrays of tags, so any entity that can read and write its set
    %   can use it.
    %
    %   Reading text (canon, parse, fromText) is lenient and never errors
    %   on the content of a tag; the editing methods that must stay valid
    %   (require, add, bulkApply) do error. Error ids: TagSet:Invalid (a tag
    %   breaks the rules), TagSet:TooMany (over MaxTags), TagSet:BadMode
    %   and TagSet:BadPolicy (an unknown mode or policy), TagSet:BadInput
    %   (something that is not text).
    %
    %   Entries read from text:   TagSet.canon, check, parse, require, fromText
    %   Editing a set:            add, remove, clear, union, intersect, checkCount
    %   Several sets at once:     summarize, vocabulary, bulkApply
    %   Filtering and showing:    matches, search, toText
    %
    %   Example:
    %     t = TagSet.fromText(' Pilot , draft', TagSet.EntryDelimiter);   % {'draft','pilot'}
    %     t = TagSet.add(t, 'shared');                                    % {'draft','pilot','shared'}
    %     TagSet.toText(t, TagSet.DisplayDelimiter)                       % "draft, pilot, shared"
    %
    %   See also TagDialog, EphysDataset.

    properties (Constant)
        MaxTags = 12                       % per entity
        MinLength = 1                      % characters in a tag
        MaxLength = 50
        Allowed = '^[a-z0-9._-]+$'         % checked after lowercasing: letters, digits, hyphen, underscore, period
        DisplayDelimiter = ", "            % table cells, dialog lists, HTML / PDF report text
        ExportDelimiter = ";"              % tabular exports (CSV, tables): commas would break CSV
        EntryDelimiter = ","               % what the user types in the dialog's field and the filter box
    end

    methods (Static)
        function t = canon(in)
            %canon  Text as a tag row, trimmed and lowercased: T = TagSet.canon(IN).
            %   IN is anything that holds text: a character vector (one
            %   tag; a character matrix gives one tag per row), a string
            %   scalar or array, a cellstr of any orientation (as
            %   jsondecode returns a JSON array of strings: Nx1), [] or {}.
            %   T is a 1xN cellstr, each entry strtrim'd then lowercased,
            %   in the order given: nothing is dropped, deduplicated,
            %   sorted or validated (an empty entry of a cell or string
            %   array stays ''; a missing one becomes ''). T is {} (0x0)
            %   when IN holds no entry: [], {}, '', "" and a missing
            %   string scalar all give {}. Anything else (a
            %   number, a nested cell) errors with TagSet:BadInput.
            %   Use parse to drop what is not a valid tag.
            if isstring(in) && isscalar(in) && (ismissing(in) || strlength(in) == 0)
                c = {};
            elseif isstring(in)
                c = reshape(in, 1, []);
                c(ismissing(c)) = "";
                c = cellstr(c);
            elseif ischar(in)
                if isempty(in)
                    c = {};
                else
                    c = reshape(cellstr(in), 1, []);
                end
            elseif iscell(in)
                c = cell(1, numel(in));
                for k = 1:numel(in)
                    e = in{k};
                    if isstring(e) && isscalar(e)
                        if ismissing(e); e = ""; end
                        e = char(e);
                    end
                    if ~ischar(e) || ~(isrow(e) || isempty(e))
                        error('TagSet:BadInput', ...
                            'Tags must be text; entry %d is a %s.', k, class(e));
                    end
                    c{k} = e;
                end
            elseif isnumeric(in) && isempty(in)
                c = {};
            else
                error('TagSet:BadInput', 'Tags must be text, not a %s.', class(in));
            end
            c = lower(strtrim(c));
            for k = find(cellfun(@isempty, c))
                c{k} = '';                  % one shape for an empty entry (0x0)
            end
            t = shaped(c);
        end

        function [ok, why] = check(tag)
            %check  Whether one tag follows the rules: [OK, WHY] = TagSet.check(TAG).
            %   TAG is one tag as canon gives it (trimmed, lowercase): a
            %   character vector or a string scalar. OK is true when it has
            %   MinLength to MaxLength characters, all of them in Allowed.
            %   WHY is "" when OK, else a string scalar such as
            %     tag "x y" is not allowed: 1 to 50 characters, letters, digits, - _ . only
            %   check does not canon: an uppercase tag fails.
            if isstring(tag) && isscalar(tag)
                tag = char(tag);
            end
            if ~ischar(tag) || ~(isrow(tag) || isempty(tag))
                error('TagSet:BadInput', 'check takes one tag as text.');
            end
            m = regexp(tag, TagSet.Allowed, 'match', 'once');
            ok = numel(tag) >= TagSet.MinLength && numel(tag) <= TagSet.MaxLength ...
                && isequal(m, tag);
            why = "";
            if ~ok
                why = sprintf('tag "%s" is not allowed: %d to %d characters, letters, digits, - _ . only', ...
                    tag, TagSet.MinLength, TagSet.MaxLength);
                why = string(why);
            end
        end

        function [tags, bad, why] = parse(in)
            %parse  The valid tags of some text, and what was rejected: [TAGS, BAD, WHY] = TagSet.parse(IN).
            %   IN is anything canon takes. Each entry is canon'd and
            %   checked. TAGS are the valid ones, unique and sorted ({} when
            %   none). BAD are the rejected entries as canon'd (a 1xK
            %   cellstr, in the order given, each once; {} when none) and WHY
            %   a 1xK string array, one check message each (strings(1,0)
            %   when none). parse never errors on the content, and does not
            %   limit the count: use require or checkCount for that.
            %   Nor does it error on what is not text (canon does): an
            %   entry of a cell that is not text (a number, [] from a JSON
            %   null, a nested cell) is a BAD entry, written as "<class>",
            %   with a WHY such as "entry 2 is not text (double)", and the
            %   other entries are kept; a whole IN that is not text and not
            %   a cell (a number, a logical, a struct) gives TAGS {} and
            %   one BAD entry. These come after the text entries in BAD.
            nonText = {};
            nonWhy = strings(1, 0);
            if iscell(in)
                in = in(:)';
                isText = cellfun(@isTextEntry, in);
                for k = find(~isText)
                    nonText{end+1} = ['<' class(in{k}) '>']; %#ok<AGROW>
                    nonWhy(end+1) = sprintf('entry %d is not text (%s)', k, class(in{k})); %#ok<AGROW>
                end
                in = in(isText);
            elseif ~(ischar(in) || isstring(in) || (isnumeric(in) && isempty(in)))
                nonText = {['<' class(in) '>']};
                nonWhy = string(sprintf('value is not text (%s)', class(in)));
                in = {};
            end
            t = TagSet.canon(in);
            valid = true(1, numel(t));
            msg = strings(1, numel(t));
            for k = 1:numel(t)
                [valid(k), msg(k)] = TagSet.check(t{k});
            end
            tags = tidy(t(valid));
            [bad, ia] = unique(t(~valid), 'stable');
            bad = shaped(bad);
            msg = msg(~valid);
            why = reshape(msg(ia), 1, []);
            if ~isempty(nonText)
                bad = shaped([bad, nonText]);
                why = [why, nonWhy];
            end
        end

        function tags = require(in)
            %require  A valid, limited tag set from some text, or an error: TAGS = TagSet.require(IN).
            %   IN is anything canon takes. TAGS is as parse gives it. Errors
            %   TagSet:Invalid, naming every entry that breaks the rules
            %   (the messages of check, joined by "; "), and TagSet:TooMany
            %   when TAGS holds more than MaxTags (the message of
            %   checkCount, "14 tags, 2 over the limit of 12").
            [tags, ~, why] = TagSet.parse(in);
            if ~isempty(why)
                error('TagSet:Invalid', '%s', strjoin(why, '; '));
            end
            [ok, msg] = TagSet.checkCount(tags);
            if ~ok
                error('TagSet:TooMany', '%s', msg);
            end
        end

        function [ok, why] = checkCount(tags)
            %checkCount  Whether a set is within MaxTags: [OK, WHY] = TagSet.checkCount(TAGS).
            %   TAGS is anything canon takes; its distinct tags are
            %   counted. WHY is "" when OK, else a string scalar such as
            %   "14 tags, 2 over the limit of 12".
            n = numel(tidy(TagSet.canon(tags)));
            ok = n <= TagSet.MaxTags;
            why = "";
            if ~ok
                why = string(sprintf('%d tags, %d over the limit of %d', ...
                    n, n - TagSet.MaxTags, TagSet.MaxTags));
            end
        end

        function tags = add(tags, more)
            %add  A set with more tags in it: TAGS = TagSet.add(TAGS, MORE).
            %   The union of the two as TagSet.require checks it: errors
            %   TagSet:Invalid when MORE holds a tag that breaks the rules
            %   and TagSet:TooMany when the result holds more than MaxTags.
            %   Unique and sorted; {} only when both are empty.
            tags = TagSet.require(TagSet.union(tags, more));
        end

        function tags = remove(tags, fewer)
            %remove  A set without some tags: TAGS = TagSet.remove(TAGS, FEWER).
            %   Entries of FEWER that TAGS lacks are ignored (case does not
            %   matter). Unique and sorted; {} when nothing is left.
            tags = tidy(setdiff(TagSet.canon(tags), TagSet.canon(fewer)));
        end

        function tags = clear()
            %clear  The empty set, {}.
            tags = {};
        end

        function u = union(a, b)
            %union  The tags of A and B together: U = TagSet.union(A, B).
            %   A and B are anything canon takes. Nothing is validated.
            %   Unique and sorted; {} when both are empty.
            u = tidy([TagSet.canon(a), TagSet.canon(b)]);
        end

        function i = intersect(a, b)
            %intersect  The tags that A and B share: I = TagSet.intersect(A, B).
            %   A and B are anything canon takes. Unique and sorted; {}
            %   when they share none.
            i = tidy(intersect(TagSet.canon(a), TagSet.canon(b)));
        end

        function [common, some, counts] = summarize(sets)
            %summarize  What a group of sets share: [COMMON, SOME, COUNTS] = TagSet.summarize(SETS).
            %   SETS is a cell array of tag sets (one per target). COMMON
            %   are the tags on every set, SOME the tags on at least one set
            %   but not all; each is unique and sorted ({} when none).
            %   COUNTS is a 1xU double row: how many sets hold each tag of
            %   TagSet.vocabulary(SETS), in that order (a tag counts once
            %   per set). With one set every tag is common; with no set all
            %   three are empty.
            sets = setList(sets);
            m = numel(sets);
            vocab = TagSet.vocabulary(sets);
            counts = zeros(1, numel(vocab));
            for k = 1:m
                counts = counts + ismember(vocab, tidy(TagSet.canon(sets{k})));
            end
            counts = reshape(counts, 1, []);        % 1x0, not 0x0, when no tag is in use
            if m == 0
                common = {};
                some = {};
                return
            end
            common = tidy(vocab(counts == m));
            some = tidy(vocab(counts < m));
        end

        function v = vocabulary(sets)
            %vocabulary  Every tag in use: V = TagSet.vocabulary(SETS).
            %   SETS is a cell array of tag sets; V is their union, unique
            %   and sorted ({} when none). It is computed when needed and
            %   never stored, so a tag nobody holds any more is gone.
            sets = setList(sets);
            lists = cell(1, numel(sets));
            for k = 1:numel(sets)
                lists{k} = TagSet.canon(sets{k});
            end
            v = tidy([lists{:}]);
        end

        function [newSets, ok, why] = bulkApply(sets, mode, tags, policy)
            %bulkApply  Add or remove tags on several sets: [NEWSETS, OK, WHY] = TagSet.bulkApply(SETS, MODE, TAGS, POLICY).
            %   SETS is a cell array of tag sets (one per target), MODE
            %   "add" or "remove" (anything else errors TagSet:BadMode),
            %   TAGS what to add or remove (anything canon takes; for "add"
            %   it must be valid, else TagSet:Invalid), POLICY "all"
            %   (default) or "skip" (anything else errors TagSet:BadPolicy).
            %
            %   Every set is checked first. OK is a logical row, one per
            %   set: true when the edited set fits MaxTags. WHY is a string
            %   row of the same size, "" where OK, else the checkCount
            %   message ("14 tags, 2 over the limit of 12"). Remove never
            %   fails (a set only shrinks): OK is all true.
            %
            %   POLICY "all": when any set is not OK, NEWSETS is SETS as
            %   given, so there is nothing to write; otherwise every set is
            %   edited. POLICY "skip": the sets that are OK are edited and
            %   the others stay as given. NEWSETS has the size of SETS;
            %   each edited set is unique and sorted.
            arguments
                sets
                mode
                tags
                policy = "all"
            end
            mode = lower(string(mode));
            if ~isscalar(mode) || ~ismember(mode, ["add" "remove"])
                error('TagSet:BadMode', 'Unknown mode "%s": use "add" or "remove".', strjoin(mode, ' '));
            end
            policy = lower(string(policy));
            if ~isscalar(policy) || ~ismember(policy, ["all" "skip"])
                error('TagSet:BadPolicy', 'Unknown policy "%s": use "all" or "skip".', strjoin(policy, ' '));
            end
            sets = setList(sets);
            m = numel(sets);
            edited = cell(size(sets));
            ok = true(1, m);
            why = strings(1, m);
            if mode == "add"
                [t, ~, badWhy] = TagSet.parse(tags);
                if ~isempty(badWhy)
                    error('TagSet:Invalid', '%s', strjoin(badWhy, '; '));
                end
                for k = 1:m
                    edited{k} = TagSet.union(sets{k}, t);
                    [ok(k), why(k)] = TagSet.checkCount(edited{k});
                end
            else
                for k = 1:m
                    edited{k} = TagSet.remove(sets{k}, tags);
                end
            end
            newSets = sets;
            if policy == "all"
                if all(ok)
                    newSets = edited;
                end
            else
                newSets(ok) = edited(ok);
            end
        end

        function tf = matches(sets, selected, mode)
            %matches  Which sets pass a tag filter: TF = TagSet.matches(SETS, SELECTED, MODE).
            %   SETS is a cell array of tag sets and SELECTED the tags
            %   wanted (anything canon takes). TF is a logical row, one per
            %   set. MODE "any" (default): the set holds at least one of
            %   SELECTED; "all": it holds every one. An empty SELECTED
            %   passes every set. SELECTED is canon'd but not validated, so
            %   a term that is no valid tag matches nothing: to filter on
            %   typed text, pass [tags, bad] from TagSet.fromText.
            %   Any other MODE errors TagSet:BadMode.
            arguments
                sets
                selected
                mode = "any"
            end
            mode = lower(string(mode));
            if ~isscalar(mode) || ~ismember(mode, ["any" "all"])
                error('TagSet:BadMode', 'Unknown mode "%s": use "any" or "all".', strjoin(mode, ' '));
            end
            sets = setList(sets);
            sel = tidy(TagSet.canon(selected));
            tf = true(1, numel(sets));
            if isempty(sel)
                return
            end
            for k = 1:numel(sets)
                has = ismember(sel, TagSet.canon(sets{k}));
                if mode == "any"
                    tf(k) = any(has);
                else
                    tf(k) = all(has);
                end
            end
        end

        function tf = search(sets, text)
            %search  Which sets have a tag containing some text: TF = TagSet.search(SETS, TEXT).
            %   SETS is a cell array of tag sets and TEXT a string or
            %   character vector. TF is a logical row, one per set: true when
            %   any tag of the set contains TEXT, ignoring case. A blank
            %   TEXT ("") passes every set, those with no tags included.
            arguments
                sets
                text (1,1) string
            end
            sets = setList(sets);
            text = lower(strtrim(text));
            tf = true(1, numel(sets));
            if ismissing(text) || strlength(text) == 0
                return
            end
            for k = 1:numel(sets)
                tf(k) = any(contains(string(TagSet.canon(sets{k})), text));
            end
        end

        function s = toText(tags, delim)
            %toText  A set as one string: S = TagSet.toText(TAGS, DELIM).
            %   TAGS is anything canon takes; the tags are joined in the
            %   order given with DELIM (default TagSet.DisplayDelimiter;
            %   use ExportDelimiter for tables). S is a string scalar, ""
            %   for the empty set.
            arguments
                tags
                delim (1,1) string = TagSet.DisplayDelimiter
            end
            t = TagSet.canon(tags);
            if isempty(t)
                s = "";
            else
                s = join(string(t), delim);
            end
        end

        function [tags, bad, why] = fromText(s, delim)
            %fromText  The tags typed or exported as text: [TAGS, BAD, WHY] = TagSet.fromText(S, DELIM).
            %   S is split at DELIM (default TagSet.EntryDelimiter; use
            %   ExportDelimiter for a table cell) and each piece is
            %   trimmed; blank pieces ("a,,b", a trailing comma) are
            %   ignored. The outputs are those of parse: TAGS the valid
            %   tags (unique, sorted), BAD the pieces rejected, WHY a
            %   message each. "" gives {}. toText(TAGS, DELIM) and fromText
            %   are inverses for a valid set.
            arguments
                s
                delim (1,1) string = TagSet.EntryDelimiter
            end
            txt = "";
            if ~(isnumeric(s) && isempty(s)) && ~isempty(s)
                txt = join(reshape(string(s), 1, []), delim);
                if ismissing(txt)
                    txt = "";
                end
            end
            pieces = strtrim(split(txt, delim));
            pieces = pieces(strlength(pieces) > 0);
            [tags, bad, why] = TagSet.parse(pieces);
        end
    end
end


function c = shaped(c)
%shaped  A cell list in the one shape a tag row has: {} (0x0) when empty, else 1xN.
if isempty(c)
    c = {};
else
    c = reshape(c, 1, []);
end
end


function t = tidy(c)
%tidy  A cellstr as a set: unique, sorted (ASCII), 1xN, {} when empty.
if isempty(c)
    t = {};
else
    t = shaped(unique(c, 'sorted'));
end
end


function tf = isTextEntry(e)
%isTextEntry  Whether one cell entry is text canon takes: a character row (or '') or a string scalar.
tf = (ischar(e) && (isrow(e) || isempty(e))) || (isstring(e) && isscalar(e));
end


function sets = setList(sets)
%setList  The cell array of sets a method takes; [] and {} are no sets.
if iscell(sets)
    return
end
if isempty(sets)
    sets = {};
    return
end
error('TagSet:BadInput', 'Expected a cell array of tag sets, not a %s.', class(sets));
end
