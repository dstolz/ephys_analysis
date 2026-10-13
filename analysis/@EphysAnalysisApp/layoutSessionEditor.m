function layoutSessionEditor(obj)
%layoutSessionEditor  Pack the Sessions tab editor's shown sections to the top and size them.
%   As layoutPlotEditor (formStack): each section packs its shown rows and
%   takes its height, the header alone when collapsed, none when hidden.
%   syncSessionEditor decides what shows; onSessionSectionToggled what is
%   collapsed.
obj.SessionSections = formStack(obj.SessionSections, obj.SessionEditorGrid);
end
