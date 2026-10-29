classdef test_DatasetFilter < matlab.unittest.TestCase
    %test_DatasetFilter  datasetFilter: subject, tag and text filters over a list of datasets.
    %   Subjects (case, comma text versus string array, wildcards, "(any)"),
    %   ExcludeSubjects (after Subjects, and alone), Tags with "any" and
    %   "all" (a term that is no valid tag matches nothing), ExcludeTags
    %   (datasets with no tags are kept), Search (every word, a custom Text),
    %   ACTIVE, zero datasets and the errors.
    %
    %   Usage:  runtests("test_DatasetFilter")

    properties
        Subject = ["M1"; "m2"; "F3"; "M10"; ""]
        Sets = {{'draft', 'pilot'}, {'pilot'}, {}, {'draft'}, {'noisy.ch3'}}
    end

    methods (Test)
        % ---- Subjects ----
        function noOptionsKeepsEverything(tc)
            [keep, active] = datasetFilter(tc.Subject, tc.Sets);
            tc.verifyEqual(keep, true(5, 1));
            tc.verifyFalse(active);
        end

        function subjectsMatchWholeSubjectIgnoringCase(tc)
            keep = datasetFilter(tc.Subject, tc.Sets, Subjects="m2");
            tc.verifyEqual(keep, [false; true; false; false; false]);
            keep = datasetFilter(tc.Subject, tc.Sets, Subjects="M");
            tc.verifyEqual(keep, false(5, 1), 'a value must match the whole subject');
        end

        function subjectsCommaTextEqualsStringArray(tc)
            a = datasetFilter(tc.Subject, tc.Sets, Subjects="M1, F3");
            b = datasetFilter(tc.Subject, tc.Sets, Subjects=["M1" "F3"]);
            c = datasetFilter(tc.Subject, tc.Sets, Subjects={'M1', 'F3'});
            tc.verifyEqual(a, [true; false; true; false; false]);
            tc.verifyEqual(b, a);
            tc.verifyEqual(c, a);
        end

        function subjectsWildcards(tc)
            tc.verifyEqual(datasetFilter(tc.Subject, tc.Sets, Subjects="M*"), [true; true; false; true; false]);
            tc.verifyEqual(datasetFilter(tc.Subject, tc.Sets, Subjects="M?"), [true; true; false; false; false]);
            tc.verifyEqual(datasetFilter(tc.Subject, tc.Sets, Subjects="*1*"), [true; false; false; true; false]);
        end

        function subjectsTakeRegexCharactersLiterally(tc)
            keep = datasetFilter(["a.b"; "axb"; "a+b"], {{}, {}, {}}, Subjects="a.b");
            tc.verifyEqual(keep, [true; false; false]);
            keep = datasetFilter(["a.b"; "axb"; "a+b"], {{}, {}, {}}, Subjects="a+b");
            tc.verifyEqual(keep, [false; false; true]);
        end

        function anyAndBlankAreIgnored(tc)
            [keep, active] = datasetFilter(tc.Subject, tc.Sets, Subjects="(any)");
            tc.verifyEqual(keep, true(5, 1));
            tc.verifyFalse(active);
            [keep, active] = datasetFilter(tc.Subject, tc.Sets, Subjects=" , ", Tags="", Search="  ");
            tc.verifyEqual(keep, true(5, 1));
            tc.verifyFalse(active);
            keep = datasetFilter(tc.Subject, tc.Sets, Subjects="(any), F3");
            tc.verifyEqual(keep, [false; false; true; false; false]);
        end

        % ---- ExcludeSubjects ----
        function excludeSubjectsAlone(tc)
            keep = datasetFilter(tc.Subject, tc.Sets, ExcludeSubjects="M*");
            tc.verifyEqual(keep, [false; false; true; false; true]);
        end

        function excludeSubjectsAfterSubjects(tc)
            keep = datasetFilter(tc.Subject, tc.Sets, Subjects="M*", ExcludeSubjects="M1?");
            tc.verifyEqual(keep, [true; true; false; false; false]);
            keep = datasetFilter(tc.Subject, tc.Sets, Subjects="M1", ExcludeSubjects="m1");
            tc.verifyEqual(keep, false(5, 1), 'a subject in both lists is dropped');
        end

        % ---- Tags ----
        function tagsAny(tc)
            keep = datasetFilter(tc.Subject, tc.Sets, Tags="pilot, noisy.ch3");
            tc.verifyEqual(keep, [true; true; false; false; true]);
            keep = datasetFilter(tc.Subject, tc.Sets, Tags="PILOT", TagMode="any");
            tc.verifyEqual(keep, [true; true; false; false; false], 'case is ignored');
        end

        function tagsAll(tc)
            keep = datasetFilter(tc.Subject, tc.Sets, Tags="draft, pilot", TagMode="all");
            tc.verifyEqual(keep, [true; false; false; false; false]);
            keep = datasetFilter(tc.Subject, tc.Sets, Tags=["draft" "pilot"], TagMode="All");
            tc.verifyEqual(keep, [true; false; false; false; false]);
        end

        function invalidTagTermMatchesNothing(tc)
            [keep, active] = datasetFilter(tc.Subject, tc.Sets, Tags="not a tag");
            tc.verifyEqual(keep, false(5, 1));
            tc.verifyTrue(active);
            keep = datasetFilter(tc.Subject, tc.Sets, Tags="pilot, not a tag", TagMode="all");
            tc.verifyEqual(keep, false(5, 1));
        end

        function tagsAndSubjectsTogether(tc)
            keep = datasetFilter(tc.Subject, tc.Sets, Subjects="M*", Tags="pilot");
            tc.verifyEqual(keep, [true; true; false; false; false]);
        end

        function badTagModeErrors(tc)
            tc.verifyError(@() datasetFilter(tc.Subject, tc.Sets, Tags="pilot", TagMode="some"), 'TagSet:BadMode');
        end

        % ---- ExcludeTags ----
        function excludeTagsDropsHoldersOnly(tc)
            keep = datasetFilter(tc.Subject, tc.Sets, ExcludeTags="pilot");
            tc.verifyEqual(keep, [false; false; true; true; true], 'the dataset with no tags stays');
        end

        function excludeTagsAnyOfSeveral(tc)
            keep = datasetFilter(tc.Subject, tc.Sets, ExcludeTags="Draft, noisy.ch3");
            tc.verifyEqual(keep, [false; true; true; false; false]);
        end

        function excludeTagsAfterTags(tc)
            keep = datasetFilter(tc.Subject, tc.Sets, Tags="draft", ExcludeTags="pilot");
            tc.verifyEqual(keep, [false; false; false; true; false]);
        end

        function excludeInvalidTagDropsNothing(tc)
            [keep, active] = datasetFilter(tc.Subject, tc.Sets, ExcludeTags="not a tag");
            tc.verifyEqual(keep, true(5, 1));
            tc.verifyTrue(active);
        end

        % ---- Search ----
        function searchNeedsEveryWordInSubjectByDefault(tc)
            keep = datasetFilter(tc.Subject, tc.Sets, Search="M 1");
            tc.verifyEqual(keep, [true; false; false; true; false]);
            keep = datasetFilter(tc.Subject, tc.Sets, Search="m1 f3");
            tc.verifyEqual(keep, false(5, 1));
        end

        function searchLooksInCustomText(tc)
            text = ["rec_a M1 pilot"; "rec_b m2"; "rec_c F3 draft"; "rec_d"; "rec_e"];
            keep = datasetFilter(tc.Subject, tc.Sets, Search="REC pilot", Text=text);
            tc.verifyEqual(keep, [true; false; false; false; false]);
            keep = datasetFilter(tc.Subject, tc.Sets, Search="rec_", Text=text);
            tc.verifyEqual(keep, true(5, 1));
            keep = datasetFilter(tc.Subject, tc.Sets, Search="M1", Text=text);
            tc.verifyEqual(keep, [true; false; false; false; false], 'Text replaces the subject');
        end

        function searchAsStringArrayIsTheSameWords(tc)
            a = datasetFilter(tc.Subject, tc.Sets, Search="m 1");
            b = datasetFilter(tc.Subject, tc.Sets, Search=["m" "1"]);
            tc.verifyEqual(b, a);
        end

        % ---- active, empty, errors ----
        function activeIsTrueWhenAnyFilterIsOn(tc)
            opts = {{'Subjects', "M1"}, {'ExcludeSubjects', "M1"}, {'Tags', "pilot"}, ...
                {'ExcludeTags', "pilot"}, {'Search', "m"}};
            for k = 1:numel(opts)
                [~, active] = datasetFilter(tc.Subject, tc.Sets, opts{k}{:});
                tc.verifyTrue(active, opts{k}{1});
            end
        end

        function zeroDatasets(tc)
            [keep, active] = datasetFilter(strings(0, 1), {}, Subjects="M*", Tags="pilot", ...
                ExcludeSubjects="F*", ExcludeTags="draft", Search="x");
            tc.verifyEqual(size(keep), [0 1]);
            tc.verifyClass(keep, 'logical');
            tc.verifyTrue(active);
            keep = datasetFilter(strings(0, 1), {});
            tc.verifyEqual(size(keep), [0 1]);
        end

        function mismatchedLengthsError(tc)
            tc.verifyError(@() datasetFilter(tc.Subject, tc.Sets(1:3)), 'datasetFilter:BadSize');
            tc.verifyError(@() datasetFilter(tc.Subject, tc.Sets, Search="a", Text=["a"; "b"]), 'datasetFilter:BadSize');
        end
    end
end
