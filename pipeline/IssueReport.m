classdef IssueReport
    %IssueReport  The parts of "Report an issue" / "Request a feature" both apps share.
    %   The Help menus of EphysPipelineApp and EphysAnalysisApp file issues
    %   against the repository itself. Each app writes its own report (what
    %   its session holds: issueReport) and hands it to the static methods
    %   here, which know nothing about either app:
    %
    %     IssueReport.dialog     the dialog: a title, a description box,
    %                            tick boxes for the report's sections, a
    %                            preview of the report as it will be sent,
    %                            and Open on GitHub / Copy report / Cancel
    %     IssueReport.url        the repository's new-issue form with the
    %                            title, the report and the label filled in
    %     IssueReport.headings   the headings the description goes under
    %     IssueReport.systemLines  MATLAB, machine, GPU, toolboxes, version
    %     IssueReport.details    one collapsed <details> section
    %     IssueReport.kv         one aligned "label : value" line
    %
    %   Nothing is filed from MATLAB: the form opens prefilled in the
    %   browser and the user submits it there, no credentials involved.
    %
    %   See also EphysPipelineApp.onReportIssue, EphysAnalysisApp.onReportIssue,
    %   ephysVersion.

    properties (Constant)
        MaxURL = 7000   % the address bar and GitHub's request line both hold about 8 kB
    end

    methods (Static)

        function [url, truncated] = url(repoURL, kind, title, body)
            %url  Address of a prefilled "new issue" form on GitHub.
            %   URL = IssueReport.url(REPOURL, KIND, TITLE, BODY) is REPOURL's
            %   new-issue form with the title, the report and the label filled
            %   in. KIND is "bug" (label "bug") or "feature" (label
            %   "enhancement").
            %
            %   [URL, TRUNCATED] = ... also says whether BODY had to be cut.
            %   GitHub rejects an address beyond roughly 8 kB, so a longer
            %   report is cut at a line boundary and the cut is stated in the
            %   body itself; the caller leaves the whole report on the
            %   clipboard. Nothing else is changed.
            arguments
                repoURL (1,1) string
                kind (1,1) string {mustBeMember(kind, ["bug", "feature"])}
                title (1,1) string = ""
                body (1,1) string = ""
            end
            maxURL = IssueReport.MaxURL;
            label = "bug";
            if kind == "feature"; label = "enhancement"; end
            base = repoURL + "/issues/new";

            truncated = false;
            url = formURL(base, title, body, label);
            if strlength(url) <= maxURL; return; end

            truncated = true;
            note = newline + newline + "_The report was too long for the address bar and was cut here. " + ...
                "The whole report is on the clipboard: paste it in place of this line._";
            chars = char(body);
            % Start from what the overrun says will fit, then shrink until it does.
            n = max(1, min(numel(chars), floor(numel(chars) * maxURL / strlength(url))));
            while n > 0
                cut = char(chars(1:n));
                br = find(cut == newline, 1, 'last');       % end on a whole line
                if ~isempty(br) && br > 1; cut = cut(1:br - 1); end
                kept = string(cut);
                if mod(count(kept, "```"), 2) == 1          % the cut fell inside a code fence: close it
                    kept = kept + newline + "```";
                end
                url = formURL(base, title, kept + note, label);
                if strlength(url) <= maxURL; return; end
                n = min(numel(cut), floor(n * 0.9));
            end
            url = formURL(base, title, strip(note), label);
        end

        function h = headings(kind)
            %headings  The headings a report's description goes under.
            arguments
                kind (1,1) string {mustBeMember(kind, ["bug", "feature"])}
            end
            if kind == "bug"
                h = ["What happened"; "Steps to reproduce"; "What I expected"];
            else
                h = ["What would you like to be able to do"; "Why it would help"; "How it might work"];
            end
        end

        function L = lead(kind, description)
            %lead  The report's opening: the headings, the description under the first.
            heads = IssueReport.headings(kind);
            L = ["### " + heads(1); ""; description; ""];
            for k = 2:numel(heads)
                L = [L; "### " + heads(k); ""; ""];   %#ok<AGROW>
            end
        end

        function L = trailer(appName)
            %trailer  The report's last lines: where it was filed from, and when.
            L = [""; "---"; "_Filed from the " + appName + " Help menu on " + ...
                string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm')) + "._"];
        end

        function L = details(summary, lines, fenced)
            %details  One collapsed <details> section, its lines in a code fence.
            arguments
                summary (1,1) string
                lines (:,1) string
                fenced (1,1) logical = true
            end
            if isempty(lines); lines = "(nothing to report)"; end
            L = [""; "<details>"; "<summary>" + summary + "</summary>"; ""];
            if fenced
                L = [L; "```text"; lines; "```"];
            else
                L = [L; lines];
            end
            L = [L; ""; "</details>"];
        end

        function s = kv(label, value)
            %kv  One aligned "label : value" line.
            value = strip(join(string(value), " "));
            s = string(sprintf('%-16s : %s', label, value));
        end

        function L = systemLines(extra)
            %systemLines  MATLAB, machine, GPU, toolboxes and this checkout of the code.
            %   EXTRA (lines, default none) goes before the toolboxes: the
            %   app's own entries, e.g. the Python interpreter.
            arguments
                extra (:,1) string = string.empty(0, 1)
            end
            kv = @IssueReport.kv;
            L = [kv("MATLAB", version); kv("Platform", computer)];
            osTxt = osDescription();
            if osTxt ~= ""; L = [L; kv("OS", osTxt)]; end
            v = ephysVersion();
            L = [L; kv("Version", v.Text); kv("Repository", v.Folder)];
            try
                L = [L; kv("Compute threads", string(maxNumCompThreads))];
            catch
            end
            if ispc
                try
                    [~, sys] = memory;
                    L = [L; kv("Memory", sprintf('%.1f GB total, %.1f GB free', ...
                        sys.PhysicalMemory.Total / 2^30, sys.PhysicalMemory.Available / 2^30))];
                catch
                end
            end
            gpuTxt = gpuDescription();
            if gpuTxt ~= ""; L = [L; kv("GPU", gpuTxt)]; end
            L = [L; extra];
            tbTxt = toolboxList();
            if tbTxt ~= ""; L = [L; kv("Toolboxes", tbTxt)]; end
        end

        function dialog(fig, kind, opts)
            %dialog  Compose a GitHub issue from a session and open it prefilled.
            %   IssueReport.dialog(FIG, KIND, Name=, Includes=, Report=, Repo=,
            %   Status=) opens a modal dialog on the app window FIG. KIND is
            %   "bug" (the Help menu's "Report an issue") or "feature" ("Request
            %   a feature"). The dialog asks for a title and a description, offers
            %   one tick box per entry of Includes and previews the whole report
            %   exactly as it will be sent. "Open on GitHub" copies the report to
            %   the clipboard and opens the repository's new-issue form with the
            %   title, the report and the label filled in; "Copy report" only
            %   copies. Nothing is filed until the user submits the form.
            %
            %   Name-value arguments
            %     Name      the app's name (the dialog's own wording)
            %     Includes  struct array, one entry per tick box: Label, Tooltip,
            %               Bug and Feature (ticked to start with, in a bug report
            %               and in a feature request)
            %     Report    @(kind, description, ticked) -> the report text, where
            %               ticked is a logical vector, one per Includes entry
            %     Repo      the repository's address (https://github.com/<owner>/<repo>)
            %     Status    @(message) shows a message in the app's status line
            %
            %   If no browser opens, an alert shows the address to copy instead.
            arguments
                fig (1,1) matlab.ui.Figure
                kind (1,1) string {mustBeMember(kind, ["bug", "feature"])}
                opts.Name (1,1) string
                opts.Includes (1,:) struct
                opts.Report (1,1) function_handle
                opts.Repo (1,1) string
                opts.Status (1,1) function_handle = @(~) []
            end
            if kind == "bug"
                heading = "Report an issue";
                what    = "issue";
                prefix  = "[Bug] ";
                prompt  = "What happened, and what were you doing when it happened?";
                include = [opts.Includes.Bug];
            else
                heading = "Request a feature";
                what    = "feature request";
                prefix  = "[Feature] ";
                prompt  = "What would you like to be able to do?";
                include = [opts.Includes.Feature];
            end
            lead = "The report below goes with the " + what + ", filled in from this session. " + ...
                "Untick anything you would rather not send, and edit it further on GitHub: " + ...
                "the form opens prefilled and nothing is filed until you submit it there.";

            p = fig.Position;
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

            nInc = numel(opts.Includes);
            ig = uigridlayout(g, [1 nInc + 1]);
            ig.ColumnWidth = [{56}, repmat({'fit'}, 1, nInc)]; ig.RowHeight = {'1x'};
            ig.Padding = [0 0 0 0]; ig.ColumnSpacing = 12;
            uilabel(ig, "Text", "Include");
            boxes = gobjects(1, nInc);
            for k = 1:nInc
                boxes(k) = uicheckbox(ig, "Text", char(opts.Includes(k).Label), "Value", include(k), ...
                    "Tooltip", char(opts.Includes(k).Tooltip), ...
                    "ValueChangedFcn", @(~,~) refresh());
            end

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
                body = string(opts.Report(kind, desc, logical([boxes.Value])));
            end

            function refresh()
                % Show the report that would be sent, and whether it all fits the address.
                body = currentBody();
                preview.Value = cellstr(splitlines(body));
                [url, cut] = IssueReport.url(opts.Repo, kind, string(titleField.Value), body);
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
                [url, cut] = IssueReport.url(opts.Repo, kind, ttl, body);
                copied = copyReport(body);
                delete(d);
                if web(url, "-browser") ~= 0
                    uialert(fig, "Could not open a web browser. The prefilled form is at:" + ...
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
                opts.Status(msg);
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

    end
end


function url = formURL(base, title, body, label)
%formURL  The new-issue form with its query filled in.
url = base + "?title=" + percentEncode(title) + "&body=" + percentEncode(body) + ...
    "&labels=" + percentEncode(label);
end


function s = percentEncode(txt)
%percentEncode  Percent-encode TXT (UTF-8) for a URL query value.
%   Everything outside the unreserved set of RFC 3986 is encoded, so spaces
%   and newlines survive as %20 and %0A rather than being reshaped.
b = double(unicode2native(char(txt), 'UTF-8'));
if isempty(b); s = ""; return; end
safe = (b >= 48 & b <= 57) | (b >= 65 & b <= 90) | (b >= 97 & b <= 122) | ismember(b, double('-._~'));
out = strings(numel(b), 1);
kept = char(b(safe));
out(safe) = string(kept(:));
out(~safe) = "%" + string(dec2hex(b(~safe), 2));
s = join(out, "");
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


function s = osDescription()
s = "";
try
    if usejava('jvm')
        s = strip(string(java.lang.System.getProperty('os.name')) + " " + ...
            string(java.lang.System.getProperty('os.version')));
    end
catch
end
if s == "" && ispc; s = string(getenv('OS')); end
end


function s = gpuDescription()
s = "";
try
    if isempty(ver('parallel')); return; end
    n = gpuDeviceCount("available");
    s = string(n) + " available";
    if n > 0
        T = gpuDeviceTable;
        s = s + " (" + join(string(T.Name(:)).', ", ") + ")";
    end
catch
end
end


function s = toolboxList()
s = "";
try
    v = ver;
    s = join(string({v.Name}) + " " + string({v.Version}), ", ");
catch
end
end
