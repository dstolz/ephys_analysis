classdef test_ReadNewLines < matlab.unittest.TestCase
    %test_ReadNewLines  readNewLines: whole lines from a byte offset, as a terminal shows them.
    %   A log written in pieces: a partial line waits for its newline, the
    %   offset resumes after the last whole line, CRLF endings lose their
    %   CR, a carriage-return progress line keeps its final state, blank
    %   lines are left out, and a missing file gives nothing.
    %
    %   Usage:  runtests("test_ReadNewLines")

    methods (Test)
        function pieces(tc)
            tmp = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            f = fullfile(tmp.Folder, "ks4_run.log");
            writeText(f, "first line" + newline + "second, still being written");
            [L, pos] = readNewLines(f, 0);
            tc.verifyEqual(L, "first line");
            tc.verifyEqual(pos, strlength("first line") + 1);
            appendText(f, " now done" + newline + "  " + newline + sprintf("10%%\r50%%\r100%%") + newline ...
                + "windows line" + sprintf("\r") + newline + "partial");
            [L, pos2] = readNewLines(f, pos);
            tc.verifyEqual(L, ["second, still being written now done"; "100%"; "windows line"], ...
                'the rest of the line, the progress line''s last state, the CRLF line; no blank line');
            d = dir(f);
            tc.verifyEqual(pos2, d.bytes - strlength("partial"), 'the partial line is left for next time');
            [L, pos3] = readNewLines(f, pos2);
            tc.verifyEmpty(L);
            tc.verifyEqual(pos3, pos2, 'no newline yet: nothing consumed');
        end

        function missing(tc)
            [L, pos] = readNewLines(fullfile(tempdir, "no_such_log_" + string(randi(1e9)) + ".log"), 7);
            tc.verifyEmpty(L);
            tc.verifyEqual(pos, 7);
            [L, pos] = readNewLines("", 0);
            tc.verifyEmpty(L);
            tc.verifyEqual(pos, 0);
        end
    end
end


function writeText(f, txt)
fid = fopen(f, 'w');
fwrite(fid, char(txt), 'char');
fclose(fid);
end


function appendText(f, txt)
fid = fopen(f, 'a');
fwrite(fid, char(txt), 'char');
fclose(fid);
end
