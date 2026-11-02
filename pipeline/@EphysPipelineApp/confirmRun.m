function choice = confirmRun(obj, steps, n)
%confirmRun  Before a run, ask "Run <steps> on <n> datasets?": Run, Show plan or Cancel.
%   CHOICE = obj.confirmRun(STEPS, N) is "run", "plan" or "cancel". The
%   dialog is modal and names what will happen: the steps, how many
%   datasets, and whether they are the ticked ones or all (no tick = all).
%   Its "Don't ask again" box is the preference ConfirmRun (group
%   EphysPipelineApp); Run > Ask before running turns the question back
%   on. With the question off, CHOICE is "run" without a dialog. runPipeline
%   asks before every run but a rehearsal and passes Confirm=false to skip
%   the dialog (the tests).
arguments
    obj (1,1) EphysPipelineApp
    steps (1,:) string
    n (1,1) double
end
group = obj.PrefGroup;
if AppPrefs.ispref(group, 'ConfirmRun') && ~logical(AppPrefs.getpref(group, 'ConfirmRun'))
    choice = "run";
    return
end

names = strings(size(steps));
for k = 1:numel(steps)
    names(k) = upper(extractBefore(steps(k), 2)) + extractAfter(steps(k), 1);
end
noun = "datasets";
if n == 1; noun = "dataset"; end
title = sprintf("Run %s on %d %s?", strjoin(names, ", "), n, noun);
if obj.Config.Project.Selection == "list"
    scope = "These are the datasets ticked on the Project tab.";
else
    scope = "No dataset is ticked on the Project tab, so the run takes all of them. Tick rows there to run fewer.";
end

w = 520; h = 230;
pos = [200 200 w h];
try
    p = obj.Fig.Position;
    pos(1:2) = round(p(1:2) + (p(3:4) - [w h]) / 2);
catch
end
dlg = uifigure("Name", "Run the pipeline", "Position", pos, "Resize", "off", "WindowStyle", "modal", "Tag", "ConfirmRun");
dlg.UserData = "cancel";
dlg.CloseRequestFcn = @(~, ~) uiresume(dlg);
g = uigridlayout(dlg, [4 1], "RowHeight", {'fit', '1x', 24, 40}, "Padding", [16 14 16 14], "RowSpacing", 8);
uilabel(g, "Text", title, "WordWrap", "on", "FontSize", 16, "FontWeight", "bold");
uilabel(g, "Text", scope, "WordWrap", "on", "VerticalAlignment", "top", "FontColor", [0.3 0.3 0.3]);
chk = uicheckbox(g, "Text", "Don't ask again", "Tooltip", "Run > Ask before running turns the question back on.");
bg = uigridlayout(g, [1 3], "ColumnWidth", {'1x', '1x', '1x'}, "RowHeight", {40}, "Padding", [0 0 0 0], "ColumnSpacing", 10);
run = uibutton(bg, "Text", "Run", "ButtonPushedFcn", @(~, ~) pick("run"));
plan = uibutton(bg, "Text", "Show plan", "Tooltip", "List what the run would do, without running it.", ...
    "ButtonPushedFcn", @(~, ~) pick("plan"));
cancel = uibutton(bg, "Text", "Cancel", "ButtonPushedFcn", @(~, ~) pick("cancel"));
styleButton(run, "primary");
styleButton(plan);
styleButton(cancel);

uiwait(dlg);
choice = "cancel";
if isvalid(dlg)
    choice = string(dlg.UserData);
    askAgain = ~chk.Value;
    delete(dlg);
    if choice == "run" && ~askAgain
        AppPrefs.setpref(group, 'ConfirmRun', false);
        if ~isempty(obj.ConfirmRunMenu) && isvalid(obj.ConfirmRunMenu); obj.ConfirmRunMenu.Checked = "off"; end
    end
end

    function pick(c)
        dlg.UserData = c;
        uiresume(dlg);
    end
end
