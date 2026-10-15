function modulationWindow(ax, R)
%modulationWindow  Shade the auROC modulation window: the windows that decide each unit's call.
%   modulationWindow(AX, R) for a spikePSTH result R with BaselineMode
%   "auroc" shades R.auroc.modulationWindow in AX (an xregion tagged
%   "modWindow"); nothing without a cutoff or with marks off. Drawn by
%   a figure's PSTH panel (drawPsthPanel).
%
%   See also callMarks, drawPsthPanel.
A = R.auroc;
if A.cutoff == "none" || (isfield(A, 'settings') && ~A.settings.marks); return; end
m = A.modulationWindow;
tagPart(xregion(ax, m(1), m(2), 'FaceColor', [0.5 0.5 0.5], 'FaceAlpha', 0.12, 'HandleVisibility', 'off'), "modWindow");
end
