function onEditProbeJSON(obj)
    % Open the selected probe .json in the MATLAB editor (or system default).
    pf = obj.selectedProbeFile();
    if pf == "" || ~isfile(pf)
        uialert(obj.Fig, "Select a probe first.", "Edit Probe JSON");
        return
    end
    matlab.desktop.editor.openDocument(char(pf));
end
