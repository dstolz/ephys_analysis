function trialNote(ax, notes, style)
%trialNote  What a trial panel left out, in small gray text at its bottom right (role "layerNote").
%   trialNote(AX, NOTES, STYLE) writes NOTES (a string row: values <= 0 on
%   a log axis, a display this MATLAB lacks), one per line, in normalized
%   units at the bottom right of AX (figLayerNotes writes the skipped
%   layers' at the bottom left). Nothing for no note.
%
%   See also drawTrialDistPanel, drawTrialHistPanel, drawTrialScatterPanel, figLayerNotes.
if isempty(notes); return; end
tagPart(text(ax, 0.98, 0.03, strjoin(notes, newline), 'Units', 'normalized', 'HorizontalAlignment', 'right', ...
    'VerticalAlignment', 'bottom', 'FontSize', max(6, style.FontSize - 2), 'Color', [0.4 0.4 0.4], 'Interpreter', 'none'), ...
    "layerNote");
end
