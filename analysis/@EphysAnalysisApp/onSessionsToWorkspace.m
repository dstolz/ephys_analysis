function S = onSessionsToWorkspace(obj, sp, opts)
%onSessionsToWorkspace  Put a session plot's data in the base workspace.
%   S = app.onSessionsToWorkspace(SP) computes the session plot SP (an id of
%   the config's session plots, or a session plot struct) over its datasets
%   (the ticked ones, or its list) as EphysAnalysisRunner.sessionData does
%   -- the merged and per-session results, and the epochs and signals its
%   data list asks for -- and assigns the struct to the base workspace as
%   sessions_<id> (a valid variable name). A cancelable progress dialog
%   shows the datasets being read; epoched signals over the size limit are
%   offered again with a raised limit. A variable of that name is replaced
%   only after asking, and an alert lists the fields. Nothing is written to
%   disk. Returns the struct ([] when canceled or nothing could be made).
%
%   Variable=NAME gives the variable's name and skips the questions (the
%   overwrite question and the final alert), for scripts and tests.
%
%   See also onSaveSessionData, EphysAnalysisRunner.sessionData, epochLongTable.
arguments
    obj (1,1) EphysAnalysisApp
    sp
    opts.Variable (1,1) string = ""
end
S = [];
dlgTitle = "Sessions to the workspace";
if obj.Running; return; end
[cfg, sp, idx] = sessionPlotContext(obj, sp);
if isempty(sp); return; end
asked = opts.Variable == "";
name = opts.Variable;
if asked
    name = string(matlab.lang.makeValidName("sessions_" + sp.id));
    if evalin('base', "exist('" + name + "', 'var')") == 1
        choice = uiconfirm(obj.Fig, "The base workspace already has a variable " + name + "." + newline + newline + "Replace it?", ...
            dlgTitle, "Options", ["Replace" "Cancel"], "DefaultOption", 2, "CancelOption", 2);
        if choice ~= "Replace"; return; end
    end
end
obj.setStatus("Sessions: reading the data of " + sp.id + " ...");
S = collectSessionData(obj, sp, cfg, idx, dlgTitle);
if isempty(S)
    return
end
assignin('base', name, S);
nDone = nnz(S.sessions.status == "done");
obj.log(sprintf("Sessions: %s in the base workspace as %s (%d of %d sessions with data).", sp.id, name, nDone, height(S.sessions)));
obj.setStatus(sprintf("Sessions: %s is in the base workspace as %s.", sp.id, name));
if asked
    msg = sprintf("The data of session plot %s is in the base workspace as:\n\n    %s\n\n" + ...
        "Sessions: %d (%d with data)\nFigures: %d\nPer session: %s\nEpochs: %s\nFields: %s\n\n" + ...
        "epochLongTable(%s) unrolls it to a table.", ...
        sp.id, name, height(S.sessions), nDone, numel(S.results), yesNo(~isempty(S.perSession)), ...
        yesNo(~isempty(S.epochs)), strjoin(string(fieldnames(S)), ", "), name);
    uialert(obj.Fig, msg, dlgTitle, "Icon", "success");
end
end


function t = yesNo(tf)
if tf; t = "yes"; else; t = "no"; end
end
