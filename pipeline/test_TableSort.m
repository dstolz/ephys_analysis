classdef test_TableSort < matlab.unittest.TestCase
    %test_TableSort  TableSort: a uitable's sort kept as a state and applied to new rows.
    %   apply: no sort and a column the rows lack keep the order given;
    %   numbers, logicals, dates, durations and categories by value; text
    %   ignoring case; ties in the order given; empty, NaN, NaT, <missing>
    %   and <undefined> last in either direction; a cell column of numbers
    %   as numbers (an empty cell missing), a mixed one as text; a cell or
    %   numeric array by its header. fromDisplay / fromEvent: the column
    %   clicked (InteractionVariable, else InteractionColumn) and the
    %   direction most neighboring values follow, missing values left out;
    %   a click that shows no order gives ascend, or the other direction on
    %   the same column; an edit changes nothing. toPref / fromPref round
    %   trip, and anything else reads as no sort.
    %
    %   Usage:  runtests("test_TableSort")

    methods (Test)
        function noSortKeepsOrder(tc)
            T = table((1:4).', [4; 3; 2; 1], 'VariableNames', {'id', 'x'});
            [D, ord] = TableSort.apply(T, TableSort.none());
            tc.verifyEqual(D, T);
            tc.verifyEqual(ord, (1:4).');
            [D, ord] = TableSort.apply(T, sortBy("nope", "ascend"));
            tc.verifyEqual(D, T, 'a column the rows lack: the order given');
            tc.verifyEqual(ord, (1:4).');
            [D, ord] = TableSort.apply(T(1, :), sortBy("x", "ascend"));
            tc.verifyEqual(D, T(1, :));
            tc.verifyEqual(ord, 1);
            [D, ord] = TableSort.apply(T([], :), sortBy("x", "ascend"));
            tc.verifyEqual(height(D), 0);
            tc.verifyEqual(ord, zeros(0, 1));
        end

        function numbersTiesAndNaN(tc)
            T = table((1:5).', [3; NaN; 1; 2; 1], 'VariableNames', {'id', 'x'});
            [D, ord] = TableSort.apply(T, sortBy("x", "ascend"));
            tc.verifyEqual(ord, [3; 5; 4; 1; 2], 'ascending, ties in the order given, NaN last');
            tc.verifyEqual(D.id, ord, 'the rows move whole');
            [~, ord] = TableSort.apply(T, sortBy("x", "descend"));
            tc.verifyEqual(ord, [1; 4; 3; 5; 2], 'descending, ties in the order given, NaN still last');
        end

        function textIgnoresCase(tc)
            s = ["b"; ""; "A"; "x"; "a"];
            s(4) = missing;
            T = table((1:5).', s, 'VariableNames', {'id', 's'});
            [~, ord] = TableSort.apply(T, sortBy("s", "ascend"));
            tc.verifyEqual(ord, [3; 5; 1; 2; 4], '"A" and "a" tie; "" and <missing> last');
            [~, ord] = TableSort.apply(T, sortBy("s", "descend"));
            tc.verifyEqual(ord, [1; 3; 5; 2; 4]);
            C = table({'beta'; 'Alpha'; ''}, 'VariableNames', {'c'});
            [~, ord] = TableSort.apply(C, sortBy("c", "ascend"));
            tc.verifyEqual(ord, [2; 1; 3], 'a cellstr variable as text');
        end

        function otherTypes(tc)
            dt = [datetime(2026, 1, 3); NaT; datetime(2026, 1, 1); datetime(2026, 1, 2)];
            T = table(dt, 'VariableNames', {'when'});
            [~, ord] = TableSort.apply(T, sortBy("when", "ascend"));
            tc.verifyEqual(ord, [3; 4; 1; 2], 'dates; NaT last');
            [~, ord] = TableSort.apply(T, sortBy("when", "descend"));
            tc.verifyEqual(ord, [1; 4; 3; 2]);
            c = categorical(["b"; "a"; "x"; "c"]);
            c(3) = missing;
            [~, ord] = TableSort.apply(table(c), sortBy("c", "ascend"));
            tc.verifyEqual(ord, [2; 1; 4; 3], 'categories; <undefined> last');
            [~, ord] = TableSort.apply(table(seconds([5; NaN; 1]), 'VariableNames', {'d'}), sortBy("d", "ascend"));
            tc.verifyEqual(ord, [3; 1; 2], 'durations');
            [~, ord] = TableSort.apply(table([true; false; true], 'VariableNames', {'b'}), sortBy("b", "ascend"));
            tc.verifyEqual(ord, [2; 1; 3], 'logicals');
        end

        function cellArraysByHeader(tc)
            C = {7, 'good', 4.5; 3, 'mua', ''; 5, 'Good', 9; 4, 'noise', NaN; 6, 'MUA', 4.5};
            names = {'Unit', 'Group', 'SNR'};
            [D, ord] = TableSort.apply(C, sortBy("SNR", "descend"), names);
            tc.verifyEqual(ord, [3; 1; 5; 2; 4], 'numbers in a cell column; an empty cell and NaN last');
            tc.verifyEqual(cell2mat(D(:, 1)), [5; 7; 6; 3; 4], 'the rows move whole');
            [~, ord] = TableSort.apply(C, sortBy("Group", "ascend"), names);
            tc.verifyEqual(ord, [1; 3; 2; 5; 4], 'text in a cell column, ignoring case');
            [~, ord] = TableSort.apply({10; 'abc'; 9}, sortBy("V", "ascend"), {'V'});
            tc.verifyEqual(ord, [1; 3; 2], 'a column mixing numbers and text sorts as text');
            [~, ord] = TableSort.apply(C, sortBy("SNR", "descend"), {'Unit', 'Group'});
            tc.verifyEqual(ord, (1:5).', 'a header the table does not have: the order given');
            [M, ord] = TableSort.apply([3 10; 1 20; 2 30], sortBy("a", "ascend"), {'a', 'b'});
            tc.verifyEqual(ord, [2; 3; 1]);
            tc.verifyEqual(M, [1 20; 2 30; 3 10], 'a numeric array by its header');
        end

        function directionFromDisplay(tc)
            T = table([1; 2; 3], ["c"; "b"; "a"], 'VariableNames', {'n', 's'});
            s = TableSort.fromDisplay(T, T([3 2 1], :), 1, {'N', 'S'});
            tc.verifyEqual(s, sortBy("n", "descend"), 'a table: the variable clicked, the order shown');
            s = TableSort.fromDisplay(T, T([3 2 1], :), [], {}, TableSort.none(), "s");
            tc.verifyEqual(s, sortBy("s", "ascend"), 'InteractionVariable names the column');
            C = {1, 'x'; 2, 'y'; 3, 'z'};
            s = TableSort.fromDisplay(C, C([3 2 1], :), 1, {'A', 'B'});
            tc.verifyEqual(s, sortBy("A", "descend"), 'a cell array: the header clicked');
            tc.verifyEqual(TableSort.direction([1; 2; 3; 2]), "ascend", 'most neighboring values decide');
            tc.verifyEqual(TableSort.direction([NaN; 3; NaN; 1]), "descend", 'missing values are left out');
            tc.verifyEqual(TableSort.direction({'' ; 'b'; 'B'; 'a'}), "descend");
            tc.verifyEqual(TableSort.direction([2; 2]), "");
        end

        function noOrderShown(tc)
            T = table([1; 1; 1], (1:3).', 'VariableNames', {'k', 'id'});
            s = TableSort.fromDisplay(T, T, 1, {});
            tc.verifyEqual(s, sortBy("k", "ascend"), 'a new column: ascend, as a first click');
            s = TableSort.fromDisplay(T, T, 1, {}, sortBy("k", "ascend"));
            tc.verifyEqual(s, sortBy("k", "descend"), 'the same column again: the other direction');
            s = TableSort.fromDisplay(T, T, 1, {}, sortBy("k", "descend"));
            tc.verifyEqual(s, sortBy("k", "ascend"));
            prev = sortBy("id", "descend");
            tc.verifyEqual(TableSort.fromDisplay(T, T, 9, {}, prev), prev, 'a column that is not there: PREV');
        end

        function fromEvent(tc)
            T = table([1; 2; 3], ["c"; "b"; "a"], 'VariableNames', {'n', 's'});
            tbl = struct('Data', T, 'DisplayData', T([3 2 1], :), 'ColumnName', {{'N', 'S'}});
            prev = sortBy("s", "descend");
            tc.verifyEqual(TableSort.fromEvent(tbl, struct('Interaction', 'edit', 'InteractionColumn', 1), prev), prev, ...
                'an edit is not a sort');
            tc.verifyEqual(TableSort.fromEvent(tbl, struct('Interaction', 'sort', 'InteractionColumn', 1), prev), ...
                sortBy("n", "descend"));
            tc.verifyEqual(TableSort.fromEvent(tbl, struct('Interaction', 'sort', 'InteractionColumn', 1, ...
                'InteractionVariable', 's')), sortBy("s", "ascend"), 'InteractionVariable before InteractionColumn');
        end

        function preferences(tc)
            s = sortBy("SNR", "descend");
            p = TableSort.toPref(s);
            tc.verifyClass(p.column, 'char');
            tc.verifyEqual(TableSort.fromPref(p), s, 'a state round-trips');
            P = TableSort.toPref(struct('Review', s, 'Trials', TableSort.none()));
            tc.verifyEqual(TableSort.fromPref(P.Review), s, 'a struct of states, one per table');
            tc.verifyFalse(TableSort.isSorted(TableSort.fromPref(P.Trials)));
            tc.verifyEqual(TableSort.toPref(struct()), struct());
            for bad = {5, "x", struct('column', "x", 'direction', "sideways"), struct('column', "", 'direction', "ascend"), ...
                    struct('column', {"a", "b"}, 'direction', "ascend"), struct('direction', "ascend")}
                tc.verifyEqual(TableSort.fromPref(bad{1}), TableSort.none(), 'anything else is no sort');
            end
            tc.verifyFalse(TableSort.isSorted(TableSort.none()));
            tc.verifyTrue(TableSort.isSorted(s));
        end
    end
end


function s = sortBy(column, direction)
s = struct('column', string(column), 'direction', string(direction));
end
