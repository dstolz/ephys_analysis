classdef test_VariableDialog < matlab.unittest.TestCase
    %test_VariableDialog  The variable dialog's grid: names that follow the label, types, values per target, rename, remove, the result.
    %   Built hidden (Visible=false) and driven through its methods, the
    %   same paths as the clicks; one check edits a grid cell through the
    %   table's CellEditCallback, as a typed value arrives.
    %
    %   Usage:  runtests("test_VariableDialog")

    properties
        A    % a set: probeDepth (number, µm) and code (text "007")
        Voc  % the vocabulary: probeDepth, code and cohort
        R    % what OnDone got ("unset" until it was called)
    end

    methods (TestMethodSetup)
        function makeSets(tc)
            tc.A = struct('probeDepth', DatasetVariables.entry("Probe Depth", 1200, Units="µm"), ...
                'code', DatasetVariables.entry("Code", "007"));
            tc.Voc = DatasetVariables.vocabulary({tc.A, struct('cohort', DatasetVariables.entry("Cohort", 3, Description="batch"))});
            tc.R = "unset";
        end
    end

    methods (Test)
        function opensOnTheTargetsVariables(tc)
            dlg = tc.open({tc.A, struct()});
            tc.verifyEqual([dlg.Defs.name], ["probeDepth" "code"]);
            tc.verifyEqual(dlg.Cells, ["1200" "007"; "" ""]);
            tc.verifyEqual([dlg.Defs.type], ["number" "text"], 'A type from the values it holds.');
            tc.verifyEqual(dlg.Current, 1);
            tc.verifyEqual(string(dlg.Ctl.Grid.ColumnName(:).'), ["Dataset" "Probe Depth (µm)" "Code"]);
            tc.verifyEqual(dlg.Ctl.Grid.Data(:, 1), {'recA'; 'recB'});
            tc.verifyEqual(string(dlg.Ctl.Label.Value), "Probe Depth");
        end

        function suggestsTheNameUntilOneIsTyped(tc)
            dlg = tc.open({struct()});
            dlg.newVariable();
            dlg.setLabel("Drug Dose");
            tc.verifyEqual(dlg.Defs(end).name, "drugDose", 'The name follows the label.');
            tc.verifySubstring(string(dlg.Ctl.NameNote.Text), "Suggested");
            dlg.setLabel("Drug dose (mg/kg)");
            tc.verifyEqual(dlg.Defs(end).name, "drugDoseMgKg");
            dlg.setName("dose");
            dlg.setLabel("Dose of the drug");
            tc.verifyEqual(dlg.Defs(end).name, "dose", 'A name typed by hand stays.');
            dlg.setName("");
            tc.verifyEqual(dlg.Defs(end).name, "doseOfTheDrug", 'Cleared: the suggestion is back.');
            dlg.newVariable("Dose of the drug");
            tc.verifyEqual(dlg.Defs(end).name, "doseOfTheDrug2", 'A suggestion keeps clear of the other columns.');
        end

        function returnsEachTargetsNewSet(tc)
            dlg = tc.open({tc.A, struct()});
            dlg.newVariable("Drug Dose");
            dlg.setUnits("mg/kg");
            dlg.setValue(1, "drugDose", "0.5");
            dlg.setValue(2, 3, "1");
            dlg.useExisting("cohort");
            tc.verifyEqual(dlg.Defs(end).description, "batch", 'Use existing brings the definition.');
            dlg.fillColumn("3");
            dlg.select(1);
            dlg.setValue(2, 1, "1300");
            dlg.ok();
            r = tc.R;
            tc.verifyEqual(r.changed, [true true]);
            tc.verifyEqual(DatasetVariables.values(r.sets{1}), struct('probeDepth', 1200, 'code', "007", 'drugDose', 0.5, 'cohort', 3));
            tc.verifyEqual(DatasetVariables.values(r.sets{2}), struct('probeDepth', 1300, 'drugDose', 1, 'cohort', 3));
            tc.verifyEqual(r.sets{2}.drugDose.units, "mg/kg");
            tc.verifyClass(r.sets{1}.code.value, 'string', 'A value not typed again keeps its type ("007" stays text).');
        end

        function refusesBadValuesAndDefinitions(tc)
            dlg = tc.open({tc.A});
            dlg.setValue(1, "probeDepth", "deep");
            dlg.ok();
            tc.verifyEqual(tc.R, "unset", 'The window stays open.');
            tc.verifySubstring(dlg.ErrorText, "not a number");
            dlg.setType("text");
            dlg.newVariable();
            dlg.ok();
            tc.verifySubstring(dlg.ErrorText, "label");
            tc.verifySubstring(dlg.ErrorText, "type a value");
            dlg.setLabel("Code");
            tc.verifyEqual(dlg.Defs(3).name, "code2", 'The suggestion keeps clear of code.');
            dlg.setName("code");
            dlg.setValue(1, 3, "x");
            dlg.ok();
            tc.verifySubstring(dlg.ErrorText, "named", 'Two variables cannot share a name.');
            dlg.removeVariable();
            dlg.ok();
            tc.verifyEqual(tc.R.sets{1}.probeDepth.value, "deep", 'Type Text keeps it as text.');
        end

        function renamesAndRemoves(tc)
            dlg = tc.open({tc.A, struct('code', DatasetVariables.entry("Code", "9"))});
            dlg.select(1);
            dlg.setName("depth");
            tc.verifySubstring(string(dlg.Ctl.NameNote.Text), "Renamed from probeDepth");
            dlg.select(2);
            dlg.clearColumn();
            dlg.setValue(1, 2, "007");
            dlg.ok();
            r = tc.R;
            tc.verifyEqual(r.renamed{1}, ["probeDepth" "depth"]);
            tc.verifyEmpty(r.renamed{2}, 'Only a target that had the variable renames it.');
            tc.verifyEqual(DatasetVariables.names(r.sets{2}), strings(1, 0), 'An emptied cell removes the variable.');
            [~, ~, a] = DatasetVariables.update(tc.A, [], r.sets{1}, Renamed=r.renamed{1});
            tc.verifyEqual([a.action], "renamed");
        end

        function okWithoutAChangeGivesNothing(tc)
            dlg = tc.open({tc.A});
            dlg.setValue(1, 1, "1200");
            dlg.ok();
            tc.verifyEmpty(tc.R);
            tc.verifyFalse(isvalid(dlg.Fig), 'OK closes the window.');
            dlg = tc.open({tc.A});
            dlg.cancel();
            tc.verifyEmpty(tc.R);
        end

        function takesATypedCell(tc)
            dlg = tc.open({tc.A});
            evt = struct('Indices', [1 3], 'NewData', ' A7 ');
            dlg.Ctl.Grid.CellEditCallback(dlg.Ctl.Grid, evt);
            tc.verifyEqual(dlg.Cells(1, 2), "A7");
            tc.verifyEqual(dlg.Current, 2, 'The edited column becomes the current one.');
        end

        function describesWhatWasDone(tc)
            s = struct('probeDepth', DatasetVariables.entry("Probe Depth", 1));
            [~, ~, a1] = DatasetVariables.update(struct(), [], s);
            none = DatasetVariables.emptyHistory();
            tc.verifyEqual(VariableDialog.describe({a1, none}, ["recA" "recB"]), "Variables of recA: probeDepth created.");
            tc.verifyEqual(VariableDialog.describe({a1, a1}, ["recA" "recB"]), "Variables of 2 datasets: 2 created.");
            tc.verifyEqual(VariableDialog.describe({none}, "recA"), "No variable changed.");
        end
    end

    methods
        function dlg = open(tc, sets)
            labels = "rec" + string(char('A' + (0:numel(sets) - 1))');
            dlg = VariableDialog(sets, tc.Voc, Labels=labels, Visible=false, OnDone=@(r) tc.got(r));
            tc.addTeardown(@() delete(dlg));
        end

        function got(tc, r)
            tc.R = r;
        end
    end
end
