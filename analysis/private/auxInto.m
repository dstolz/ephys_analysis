function auxInto(ax, A, X, W, style, over, label)
%auxInto  Draw the mean aux traces of A (auxMean) into the axes AX.
%   auxInto(AX, A, X, W, STYLE, OVER, LABEL) draws every trace of A -- each
%   channel's mean, or the magnitude's, per group -- as X (auxLooks) says,
%   on the time axis W ([t0 t1] s, the plot's), with each trace's
%   error band under it when STYLE.ShowSEM (A.err: mean +/- SEM or SD, or a
%   bootstrap 95% CI, over the epochs; errorPatch in STYLE's Error* look).
%   The lines are tagged
%   "auxTrace" and the bands "auxSem", both with X's group (tagPart), and
%   kept out of legends (auxStandIns stands in for them there).
%     OVER false  AX is an aux panel of its own: the bands are opaque by
%                 default (as the PSTH's), the axes styled (styleAxes, without
%                 Style.YLim: that is for rates) and the y axis automatic
%     OVER true   the traces go on AX's right y axis (yyaxis), over what
%                 AX shows (a PSTH's rate, a raster's rows): the bands are
%                 semitransparent (opacity 0.2, unless ErrorFaceAlpha sets
%                 one), so what is under them shows through.
%                 The left side is the active one again after, both y
%                 axes in AX's x axis color
%   LABEL true names the aux y axis (the panel's, or AX's right one)
%   X.label; false (a grid, whose layout names its panels) leaves it.
%
%   See also auxLooks, auxStandIns, renderPSTH, renderRaster.

if over
    yyaxis(ax, 'right');
    ax.LineStyleOrder = '-';   % a yyaxis side cycles through markers otherwise
    ax.YDir = 'normal';        % the active side's: a raster's rows run down on the left
end
held = ishold(ax);
hold(ax, 'on');
[~, nTr, nGa] = size(A.mean);
t = A.t(:);
[eLo, eHi] = resultBounds(A, 'mean');
alpha = NaN;
if over; alpha = 0.2; end
for g = 1:nGa
    for c = 1:nTr
        L = X.trace(c, g);
        m = double(A.mean(:, c, g));
        if style.ShowSEM
            errorPatch(ax, t, eLo(:, c, g), eHi(:, c, g), L.color, L.group, style, "auxSem", alpha);
        end
        tagPart(line(ax, t, m, 'Color', L.color, 'LineStyle', char(L.lineStyle), 'LineWidth', style.LineWidth, ...
            'HandleVisibility', 'off'), "auxTrace", L.group);
    end
end
if ~held; hold(ax, 'off'); end
xlim(ax, W);
if label; ylabel(ax, X.label, 'Interpreter', 'none'); end
if over
    yyaxis(ax, 'left');
    set(ax.YAxis, 'Color', ax.XAxis.Color);
else
    flat = style;
    flat.YLim = [];
    styleAxes(ax, flat);
end
end

