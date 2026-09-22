function onReportIssue(obj, kind)
%onReportIssue  Compose a GitHub issue about this session and open it prefilled.
%   onReportIssue(OBJ, "bug") opens the Help menu's issue dialog: a title, a
%   box for what happened, tick boxes for what to send with it (system info,
%   the pipeline options, the logs and the last error) and a preview of the
%   whole report exactly as it will be sent (issueReport). "Open on GitHub"
%   copies the report to the clipboard and opens the repository's new-issue
%   form with the title, the report and the "bug" label filled in
%   (issueURL); nothing is filed until the user submits it there.
%
%   onReportIssue(OBJ, "feature") is the same dialog for a feature request:
%   it asks what the app should do instead, starts with only the system info
%   ticked and uses the "enhancement" label.
%
%   If no browser opens, an alert shows the address to copy instead.
arguments
    obj (1,1) EphysPreprocessingApp
    kind (1,1) string {mustBeMember(kind, ["bug", "feature"])}
end

if kind == "bug"
    heading = "Report an issue";
    what    = "issue";
    prefix  = "[Bug] ";
    prompt  = "What happened, and what were you doing when it happened?";
    include = [true true true];
else
    heading = "Request a feature";
    what    = "feature request";
    prefix  = "[Feature] ";
    prompt  = "What would you like to be able to do?";
    include = [true false false];
end
lead = "The report below goes with the " + what + ", filled in from this session. " + ...
    "Untick anything you would rather not send, and edit it further on GitHub: " + ...
    "the form opens prefilled and nothing is filed until you submit it there.";

p = obj.Fig.Position;
w = 780; h = 660;
d = uifigure("Name", heading, "Position", ...
    [p(1) + max(0, (p(3) - w) / 2), p(2) + max(0, (p(4) - h) / 2), w, h]);
try
    d.WindowStyle = "modal";
catch
end

g = uigridlayout(d, [8 1]);
g.RowHeight   = {'fit', 26, 18, '1x', 26, 'fit', '1.6x', 30};
g.ColumnWidth = {'1x'};
g.RowSpacing  = 6;
g.Padding     = [12 12 12 12];

uilabel(g, "Text", char(lead), "WordWrap", "on");

tg = uigridlayout(g, [1 2]);
tg.ColumnWidth = {56, '1x'}; tg.RowHeight = {'1x'}; tg.Padding = [0 0 0 0]; tg.ColumnSpacing = 6;
uilabel(tg, "Text", "Title");
titleField = uieditfield(tg, "text", "Value", char(prefix), ...
    "ValueChangedFcn", @(~,~) refresh());

uilabel(g, "Text", char(prompt));
descArea = uitextarea(g, "ValueChangedFcn", @(~,~) refresh());

ig = uigridlayout(g, [1 4]);
ig.ColumnWidth = {56, 'fit', 'fit', 'fit'}; ig.RowHeight = {'1x'};
ig.Padding = [0 0 0 0]; ig.ColumnSpacing = 12;
uilabel(ig, "Text", "Include");
sysBox = uicheckbox(ig, "Text", "System info", "Value", include(1), ...
    "Tooltip", "MATLAB release, platform, memory, GPU, Python and the toolboxes installed.", ...
    "ValueChangedFcn", @(~,~) refresh());
cfgBox = uicheckbox(ig, "Text", "Pipeline options", "Value", include(2), ...
    "Tooltip", "The working config, including the project and output paths it names.", ...
    "ValueChangedFcn", @(~,~) refresh());
logBox = uicheckbox(ig, "Text", "Logs and last error", "Value", include(3), ...
    "Tooltip", "The tail of the Run, Kilosort and Copy logs and the error the last run stopped on.", ...
    "ValueChangedFcn", @(~,~) refresh());

sizeLabel = uilabel(g, "Text", "", "FontAngle", "italic", "WordWrap", "on", ...
    "FontColor", [0.25 0.25 0.25]);
preview = uitextarea(g, "Editable", "off", "FontName", "Consolas", "Value", {''}, ...
    "Tooltip", "Exactly what is sent. Copy report puts this on the clipboard.");

bg = uigridlayout(g, [1 4]);
bg.ColumnWidth = {'1x', 140, 110, 90}; bg.RowHeight = {'1x'};
bg.Padding = [0 0 0 0]; bg.ColumnSpacing = 8;
uilabel(bg, "Text", "");
gh = uibutton(bg, "Text", "Open on GitHub", "ButtonPushedFcn", @(~,~) openOnGitHub());
uibutton(bg, "Text", "Copy report", "ButtonPushedFcn", @(~,~) copyOnly());
uibutton(bg, "Text", "Cancel", "ButtonPushedFcn", @(~,~) delete(d));
styleButton(findall(bg, "Type", "uibutton"));
styleButton(gh, "primary");

refresh();

    function body = currentBody()
        % The report as the tick boxes and the description box leave it.
        desc = join(string(descArea.Value(:)).', newline);
        if isempty(desc) || ismissing(desc); desc = ""; end
        body = obj.issueReport(kind, Description=desc, ...
            System=sysBox.Value, Config=cfgBox.Value, Logs=logBox.Value);
    end

    function refresh()
        % Show the report that would be sent, and whether it all fits the address.
        body = currentBody();
        preview.Value = cellstr(splitlines(body));
        [url, cut] = obj.issueURL(kind, string(titleField.Value), body);
        txt = string(sprintf('The report is %d characters; the address would be %d.', ...
            strlength(body), strlength(url)));
        if cut
            txt = txt + " That is more than the address bar holds: Open on GitHub sends what fits" + ...
                " and puts the whole report on the clipboard for you to paste in.";
        end
        sizeLabel.Text = char(txt);
    end

    function openOnGitHub()
        body = currentBody();
        ttl = strip(string(titleField.Value));
        if ttl == "" || ttl == strip(string(prefix))
            uialert(d, "Give the " + what + " a title first.", heading);
            return
        end
        [url, cut] = obj.issueURL(kind, ttl, body);
        copied = copyReport(body);
        delete(d);
        if web(url, "-browser") ~= 0
            uialert(obj.Fig, "Could not open a web browser. The prefilled form is at:" + ...
                newline + url, heading);
            return
        end
        msg = "Opened a new " + what + " on GitHub with the report filled in." + ...
            " Nothing is filed until you submit it there.";
        if cut && copied
            msg = msg + " The report was cut to fit the address; the whole of it is on the clipboard.";
        elseif cut
            msg = msg + " The report was cut to fit the address and the clipboard could not be written.";
        end
        obj.setStatus(msg, "");
    end

    function copyOnly()
        body = currentBody();
        if copyReport(body)
            sizeLabel.Text = char("The whole report is on the clipboard (" + ...
                strlength(body) + " characters).");
        else
            uialert(d, "The clipboard could not be written.", heading);
        end
    end
end


function ok = copyReport(body)
%copyReport  Put the report on the clipboard; false when that is not possible.
ok = false;
try
    clipboard('copy', char(body));
    ok = true;
catch
end
end
