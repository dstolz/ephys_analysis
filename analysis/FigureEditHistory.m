classdef FigureEditHistory
    %FIGUREEDITHISTORY  The figure editor's undo and redo: the figures before and after each edit.
    %   H = FigureEditHistory() is an empty history. The analysis app keeps
    %   one (EphysAnalysisApp.FigureHistory) and records every edit of its
    %   Figures tab: what Config.Figures was before the edit and is after
    %   it, a label naming the edit ("Add panel", "Bin"), and where the
    %   editor was (the figure, panel and layer selected), so undo and redo
    %   go back there. Only the figures are kept, never the whole config:
    %   undoing a figure edit leaves the Source, Export and Report settings
    %   changed since as they are. A value class: each method returns the
    %   history changed.
    %
    %     H = H.record(before, after, "Add panel");
    %     [H, step] = H.undo();     % step.Before: the figures to show again
    %     [H, step] = H.redo();     % step.After
    %     H.undoLabel()             % "Add panel" ("" with nothing to undo)
    %
    %   An edit that changes nothing (BEFORE equals AFTER) is not recorded.
    %   A burst of edits from one control (KEY, the same selection, each
    %   under CoalesceSeconds after the last) is one step; typed back to
    %   where it started, the step goes. A new edit drops what was undone
    %   (the redo steps); past Depth steps the oldest goes.
    %
    %   Properties
    %     Undo             the steps to undo, the last edit last: struct
    %                      array of Label, Key, Selection ([figure panel
    %                      layer] as the edit left them), Time (datetime),
    %                      Before and After (Config.Figures)
    %     Redo             the steps undone, the next to redo last
    %     Depth            the most steps kept (100)
    %     CoalesceSeconds  the most time between two edits of one control
    %                      that make one step (1 s)
    %
    %   See also EphysAnalysisApp, EphysAnalysisConfig.

    properties (SetAccess = private)
        Undo struct = struct('Label', {}, 'Key', {}, 'Selection', {}, 'Time', {}, 'Before', {}, 'After', {})
        Redo struct = struct('Label', {}, 'Key', {}, 'Selection', {}, 'Time', {}, 'Before', {}, 'After', {})
    end

    properties
        Depth (1,1) double {mustBePositive, mustBeInteger} = 100
        CoalesceSeconds (1,1) double {mustBeNonnegative} = 1
    end

    methods
        function H = record(H, before, after, label, opts)
            %record  Note an edit: the figures BEFORE and AFTER it, named LABEL.
            %   Key=KEY (any value; [] by default: never merged) names the
            %   control the edit came from; Selection=[figure panel layer]
            %   is where the editor was. An edit equal to the last step's
            %   key and selection, under CoalesceSeconds after it and
            %   continuing it (its After is BEFORE), joins that step.
            arguments
                H (1,1) FigureEditHistory
                before struct
                after struct
                label (1,1) string
                opts.Key = []
                opts.Selection (1,3) double = [0 0 0]
            end
            if isequaln(before, after); return; end
            t = datetime("now");
            if ~isempty(H.Undo) && isempty(H.Redo) && ~isempty(opts.Key)
                last = H.Undo(end);
                if isequal(last.Key, opts.Key) && isequal(last.Selection, opts.Selection) ...
                        && seconds(t - last.Time) <= H.CoalesceSeconds && isequaln(last.After, before)
                    if isequaln(last.Before, after)
                        H.Undo(end) = [];   % back where the burst started: nothing to undo
                    else
                        H.Undo(end).After = after;
                        H.Undo(end).Time = t;
                    end
                    return
                end
            end
            H.Undo(end+1) = struct('Label', label, 'Key', {opts.Key}, 'Selection', opts.Selection, 'Time', t, ...
                'Before', {before}, 'After', {after});
            H.Undo(1:end - H.Depth) = [];
            H.Redo = H.Redo([]);
        end

        function [H, step] = undo(H)
            %undo  Take the last step off the undo list (onto the redo list); STEP its Before is what to show. [] with none.
            step = [];
            if isempty(H.Undo); return; end
            step = H.Undo(end);
            H.Undo(end) = [];
            H.Redo(end+1) = step;
        end

        function [H, step] = redo(H)
            %redo  Take the last step undone back onto the undo list; STEP its After is what to show. [] with none.
            step = [];
            if isempty(H.Redo); return; end
            step = H.Redo(end);
            H.Redo(end) = [];
            H.Undo(end+1) = step;
        end

        function s = undoLabel(H)
            %undoLabel  What Undo would undo ("" with nothing to undo).
            s = "";
            if ~isempty(H.Undo); s = H.Undo(end).Label; end
        end

        function s = redoLabel(H)
            %redoLabel  What Redo would redo ("" with nothing to redo).
            s = "";
            if ~isempty(H.Redo); s = H.Redo(end).Label; end
        end

        function H = clear(H)
            %clear  Forget every step (another config opened or made new); Depth and CoalesceSeconds stay.
            H.Undo = H.Undo([]);
            H.Redo = H.Redo([]);
        end
    end
end
