function onFigureTemplate(obj, action, opts)
%onFigureTemplate  The Figures tab's template row: save, update, remove, import, export a template; report an issue.
%   onFigureTemplate(OBJ, ACTION) does what the row's controls do with
%   your figure templates (FigureTemplate, one JSON file each in your
%   templates folder), on the template picked in the Template list and the
%   figure shown:
%     "save"     Save as...: the figure shown as a new template, named and
%                described in a small window (the figure's id offered as
%                the name; one of yours of that name is replaced only when
%                you agree): every setting but its id, title and enabled
%     "update"   Update: the template picked made again from the figure
%                shown, its description kept (asks first). The figures it
%                was applied to keep their settings until it is applied
%                to them again (onApplyTemplate)
%     "remove"   Remove: deletes the template picked (asks first)
%     "import"   Import...: copies template files (.json, one or several)
%                into your folder (asks before replacing one of yours);
%                what reading each reported (a field the code no longer
%                knows, a newer version) and the config's checks of its
%                figure (FigureTemplate.check: its errors) go to the status
%                bar and the Log tab
%     "export"   Export...: writes the template picked to a .json file
%                you name, to share it
%     "issue", "feature"  Report issue (and the list's right-click menu):
%                the Help menu's issue window (IssueReport.dialog) with the
%                title "Figure templates: " and, to send with it, the
%                system info, the template picked (its file) and the Log
%                tab
%     "folder"   opens your templates folder; "choose" keeps them in
%                another (one the lab shares, say: FigureTemplate.setFolder)
%   The Template list is listed again after each (refreshTemplates).
%
%   For scripts and tests: Name= names the template (default the one
%   picked; for "save" it skips the window, replacing one of yours of that
%   name), Description= its description ("save", "update"), File= the
%   file(s) ("import", "export"; the folder for "choose") and
%   Confirm=false skips the questions (an import replaces).
arguments
    obj (1,1) EphysAnalysisApp
    action (1,1) string {mustBeMember(action, ["save" "update" "remove" "import" "export" "issue" "feature" "folder" "choose"])}
    opts.Name (1,1) string = string(missing)
    opts.Description (1,1) string = string(missing)
    opts.File string = string(missing)
    opts.Confirm (1,1) logical = true
end
picked = string(obj.FigureTemplateDropDown.Value);
name = opts.Name;
if ismissing(name) && action ~= "save"; name = picked; end
if ismember(action, ["update" "remove" "export"]) && name == ""
    obj.setStatus("Figure templates: you have no template yet: Save as... keeps the figure shown as one, Import... adds a file.");
    return
end
switch action
    case "save"
        fig = shownFigure(obj, "Save as template");
        if isempty(fig); return; end
        desc = opts.Description;
        if ismissing(desc); desc = ""; end
        if ismissing(name)
            [name, desc, ok] = askTemplateName(obj.Fig, fig.id, desc);
            if ~ok; return; end
        end
        try
            t = FigureTemplate.fromFigure(fig, Description=desc);
            FigureTemplate.save(t, name, Overwrite=true);
            name = FigureTemplate.checkName(name);
        catch ME
            say(obj, opts, "Save as template", ME.message);
            return
        end
        obj.refreshTemplates(name);
        obj.setStatus("Saved " + fig.id + " as the template " + name + " (" + FigureTemplate.summary(t.figure) + ") in " + ...
            FigureTemplate.folder() + ".");

    case "update"
        fig = shownFigure(obj, "Update template");
        if isempty(fig); return; end
        if opts.Confirm
            a = uiconfirm(obj.Fig, "Replace the template " + name + " with the settings of " + fig.id + "? The figures it " + ...
                "was applied to keep their settings until you apply it to them again.", "Update template", ...
                "Options", ["Update" "Cancel"], "DefaultOption", 2, "CancelOption", 2);
            if a ~= "Update"; return; end
        end
        try
            old = FigureTemplate.load(name);
            desc = opts.Description;
            if ismissing(desc); desc = old.description; end
            t = FigureTemplate.fromFigure(fig, Description=desc);
            FigureTemplate.save(t, old.name, Overwrite=true);
        catch ME
            say(obj, opts, "Update template", ME.message);
            return
        end
        obj.refreshTemplates(old.name);
        obj.setStatus("Updated the template " + old.name + " from " + fig.id + ". Apply it to the figures that should follow it.");

    case "remove"
        if opts.Confirm
            a = uiconfirm(obj.Fig, "Delete your template " + name + "? Its file is deleted; the figures it was applied to " + ...
                "keep their settings.", "Remove template", "Options", ["Delete" "Cancel"], "DefaultOption", 2, ...
                "CancelOption", 2, "Icon", "warning");
            if a ~= "Delete"; return; end
        end
        try
            FigureTemplate.remove(name);
        catch ME
            say(obj, opts, "Remove template", ME.message);
            return
        end
        obj.refreshTemplates();
        obj.setStatus("Deleted the template " + name + ".");

    case "import"
        files = opts.File;
        if all(ismissing(files))
            [f, p] = uigetfile("*.json", "Import figure templates", "MultiSelect", "on");
            figure(obj.Fig);
            if isequal(f, 0); return; end
            files = string(fullfile(p, f));
        end
        done = strings(1, 0);
        said = strings(1, 0);
        D = obj.Config.Defaults;
        for file = reshape(files, 1, [])
            [~, stem] = fileparts(file);
            try
                [nm, t] = importOne(obj, file, opts.Confirm);
            catch ME
                said(end+1) = stem + ": " + string(ME.message); %#ok<AGROW>
                continue
            end
            if nm == ""; continue; end   % not replaced
            done(end+1) = nm; %#ok<AGROW>
            notes = t.notes;
            try
                I = FigureTemplate.check(t, D);
                errs = string(I.Message(string(I.Severity) == "error"));
                if ~isempty(errs); notes(end+1) = "the config's checks: " + strjoin(errs, "; "); end %#ok<AGROW>
            catch
            end
            if ~isempty(notes)
                said(end+1) = nm + ": " + strjoin(notes, "; "); %#ok<AGROW>
            end
        end
        for s = said; obj.log("Import template " + s); end
        if isempty(done)
            if ~isempty(said); obj.setStatus("Import template: " + strjoin(said, " | ")); end
            return
        end
        obj.refreshTemplates(done(end));
        msg = "Imported the template" + plural(done) + " " + strjoin(done, ", ") + " into " + FigureTemplate.folder() + ".";
        if ~isempty(said); msg = msg + " " + strjoin(said, " | ") + " (also in the Log tab)."; end
        obj.setStatus(msg);

    case "export"
        file = opts.File;
        if all(ismissing(file))
            [f, p] = uiputfile("*.json", "Export figure template", char(name + ".json"));
            figure(obj.Fig);
            if isequal(f, 0); return; end
            file = string(fullfile(p, f));
        end
        try
            FigureTemplate.export(name, file(1));
        catch ME
            say(obj, opts, "Export template", ME.message);
            return
        end
        obj.setStatus("Exported the template " + name + " to " + file(1) + " (Import... adds it on another computer).");

    case {"issue" "feature"}
        includes = struct( ...
            "Label",   {"System info", "The template", "Log tab"}, ...
            "Tooltip", {"MATLAB release, platform, memory, GPU and the toolboxes installed.", ...
                        "The template picked in the list (" + name + "), as its file holds it.", ...
                        "The tail of the Log tab: what the templates, previews and runs reported."}, ...
            "Bug",     {true, true, true}, ...
            "Feature", {true, false, false});
        IssueReport.dialog(obj.Fig, action.replace("issue", "bug"), Name="EphysAnalysisApp", Includes=includes, ...
            Repo=obj.RepoURL, Title="Figure templates: ", ...
            Report=@(k, desc, on) obj.issueReport(k, Description=desc, System=on(1), Config=false, Logs=on(3), ...
                Extra=templateLines(name, on(2))), ...
            Status=@(msg) obj.setStatus(msg));

    case "folder"
        f = FigureTemplate.folder();
        if ~isfolder(f); mkdir(f); end
        openInSystem(f);

    case "choose"
        folder = opts.File;
        if all(ismissing(folder))
            dd = uigetdir(FigureTemplate.folder(), "Keep my figure templates in");
            figure(obj.Fig);
            if isequal(dd, 0); return; end
            folder = string(dd);
        end
        FigureTemplate.setFolder(folder(1));
        obj.refreshTemplates();
        obj.setStatus("Your figure templates are kept in " + FigureTemplate.folder() + ".");
end
end


function fig = shownFigure(obj, what)
%shownFigure  The figure shown, as the editor holds it now ([] and the status bar says so when there is none).
fig = [];
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures)
    obj.setStatus(what + ": select a figure first.");
    return
end
cfg = obj.gatherConfig();
fig = cfg.Figures(k);
end


function [name, t] = importOne(obj, file, confirm)
%importOne  Import one template file; asks before replacing one of yours ("" when it was not).
try
    [name, t] = FigureTemplate.import(file);
catch ME
    if ME.identifier ~= "FigureTemplate:Exists"; rethrow(ME); end
    if confirm
        a = uiconfirm(obj.Fig, string(ME.message) + " Replace it with the imported one?", "Import template", ...
            "Options", ["Replace" "Skip"], "DefaultOption", 2, "CancelOption", 2);
        if a ~= "Replace"
            name = "";
            t = [];
            return
        end
    end
    [name, t] = FigureTemplate.import(file, Overwrite=true);
end
end


function L = templateLines(name, on)
%templateLines  The template NAME's file as a collapsed section of the issue (none when ON is false).
L = string.empty(0, 1);
if ~on || name == ""; return; end
try
    t = FigureTemplate.load(name);
    L = IssueReport.details("Figure template " + name, splitlines(string(fileread(t.file))));
catch ME
    L = IssueReport.details("Figure template " + name, "(it could not be read: " + string(ME.message) + ")");
end
end


function say(obj, opts, title, message)
%say  An error: in an alert over the app when a person asked, else on the status bar.
if opts.Confirm
    uialert(obj.Fig, message, title);
else
    obj.setStatus(title + ": " + string(message));
end
end


function s = plural(x)
s = "";
if numel(x) ~= 1; s = "s"; end
end
