function S = collectSessionData(obj, sp, cfg, idx, title)
%collectSessionData  Compute a session plot's data under a cancelable progress dialog.
%   S = collectSessionData(OBJ, SP, CFG, IDX, TITLE) is
%   Runner.sessionData(SP, IDX) for the config CFG (the editors' state),
%   with a progress dialog TITLE whose Cancel button stops it between
%   datasets and inside a compute. Epoched signals that would pass the size
%   limit (epochData:TooLarge, 1024 MB) are offered again with the limit
%   raised to what they need. S is [] when canceled, declined or failed (the
%   failure is shown and logged).
S = [];
if obj.Running; return; end
r = obj.Runner;
r.Config = cfg;
maxMB = 1024;
obj.Running = true;
guard = onCleanup(@() release(obj, r));
while true
    dlg = uiprogressdlg(obj.Fig, "Title", title, "Message", "Starting ...", "Cancelable", "on");
    r.clearCancel();
    r.ProgressFcn = @(f, m) progress(r, dlg, f, m);
    r.PollFcn = @() poll(r, dlg);
    try
        S = r.sessionData(sp, idx, KeepActive=obj.ActiveIdx, Span=[0 1], MaxMB=maxMB);
        close(dlg);
        return
    catch ME
        if isvalid(dlg); close(dlg); end
        if ~isvalid(obj) || ~isvalid(obj.Fig); return; end
        S = [];
        switch ME.identifier
            case "EphysAnalysisRunner:Canceled"
                obj.log("Sessions: " + sp.id + " canceled.");
                obj.setStatus("Sessions: " + sp.id + " canceled.");
                return
            case "epochData:TooLarge"
                need = str2double(regexp(string(ME.message), 'about (\d+) MB', 'tokens', 'once'));
                if isempty(need) || isnan(need) || ~isfinite(need)
                    uialert(obj.Fig, string(ME.message), "Session data");
                    return
                end
                choice = uiconfirm(obj.Fig, string(ME.message) + newline + newline + ...
                    sprintf("Raise the limit to %.0f MB and read the signals?", ceil(need * 1.05)), ...
                    "Session data", "Options", ["Raise the limit" "Cancel"], "DefaultOption", 2, "CancelOption", 2);
                if choice ~= "Raise the limit"; return; end
                maxMB = ceil(need * 1.05);
            otherwise
                obj.log("Sessions: " + sp.id + " data failed: " + string(ME.message));
                uialert(obj.Fig, "The data of " + sp.id + " could not be made:" + newline + string(ME.message), "Session data");
                return
        end
    end
end
end


function progress(r, dlg, fraction, message)
if ~isvalid(dlg); return; end
dlg.Value = min(max(fraction, 0), 1);
dlg.Message = char(message);
if dlg.CancelRequested; r.cancel(); end
drawnow limitrate;
end


function poll(r, dlg)
drawnow limitrate;
if isvalid(dlg) && dlg.CancelRequested; r.cancel(); end
end


function release(obj, r)
if isvalid(r)
    r.ProgressFcn = [];
    r.PollFcn = [];
    r.clearCancel();
end
if isvalid(obj); obj.Running = false; end
end
