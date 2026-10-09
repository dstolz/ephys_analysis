classdef test_SubjectAndDate < matlab.unittest.TestCase
    %test_SubjectAndDate  subjectAndDate: the Subject and Date columns of the tables that list datasets.
    %   The SubjectID and the recording's day come from the name pattern; a
    %   recording's own start (ACQ) wins for the day; a name that does not
    %   match gives "" and a pattern with no Date or Time token still gives
    %   the subject.
    %
    %   Usage:  runtests("test_SubjectAndDate")

    properties (Constant)
        Pattern = "{SubjectID}_{Date:yyMMdd}_{Time:HHmmss}"
    end

    methods (Test)
        function fromTheName(tc)
            [s, d] = subjectAndDate(["rec1_260101_120000"; "SUBJ-ID-7_261231_235959"], tc.Pattern);
            tc.verifyEqual(s, ["rec1"; "SUBJ-ID-7"]);
            tc.verifyEqual(d, ["2026-01-01"; "2026-12-31"]);
        end

        function aNameThatDoesNotMatch(tc)
            [s, d] = subjectAndDate(["rec1_260101_120000"; "something else"], tc.Pattern);
            tc.verifyEqual(s, ["rec1"; ""]);
            tc.verifyEqual(d, ["2026-01-01"; ""]);
        end

        function theRecordingStartWins(tc)
            acq = [datetime(2026, 3, 4, 5, 6, 7); NaT];
            [s, d] = subjectAndDate(["rec1_260101_120000"; "rec2_260102_120000"], tc.Pattern, acq);
            tc.verifyEqual(s, ["rec1"; "rec2"]);
            tc.verifyEqual(d, ["2026-03-04"; "2026-01-02"], 'the start where known, else the name''s date');
        end

        function aPatternWithoutDateAndTime(tc)
            [s, d] = subjectAndDate("rec1_extra", "{SubjectID}_*");
            tc.verifyEqual(s, "rec1");
            tc.verifyEqual(d, "");
            [~, d] = subjectAndDate("rec1_extra", "{SubjectID}_*", datetime(2026, 5, 6));
            tc.verifyEqual(d, "2026-05-06", 'the recording''s start does not need the name');
        end

        function noNames(tc)
            [s, d] = subjectAndDate(strings(0, 1), tc.Pattern);
            tc.verifyEqual(size(s), [0 1]);
            tc.verifyEqual(size(d), [0 1]);
        end
    end
end
