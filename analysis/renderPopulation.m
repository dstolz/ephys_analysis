function h = renderPopulation(P, S, kind, target, opts)
%renderPopulation  Draw one population figure: mean PSTH, shares responsive, tuning or depth.
%   H = renderPopulation(P, S, KIND, TARGET) draws populationAnalysis' P and
%   populationSummary's S into TARGET (an axes, a figure, a panel or a
%   tiled layout):
%     "psth"       each group's mean PSTH +/- SEM across its units
%     "fractions"  per group, the share of the units tested that are
%                  excited and suppressed (responsive, by direction) and
%                  tuned, and of the units the auROC called, those called
%                  up and down (the cutoff, pooled over the family's unit x
%                  group curves, in the subtitle)
%     "tuning"     each group's mean tuning curve +/- SEM across its units
%                  (S.tuning.normalize); a text parameter is spaced evenly
%     "depth"      every unit at its probe y against its response
%                  (responseRate - baselineRate, spikes/s), colored by
%                  direction
%   Groups take the lines colors in the order of S.groups and are named
%   with their unit counts. H: layout ([] when TARGET is an axes), axes.
%
%   Options: Style (an EphysAnalysisConfig Style: FontSize, Grid,
%   LineWidth, ShowSEM, Legend, LegendLocation, LegendOrientation, LegendBox).
%
%   See also populationAnalysis, populationSummary, writePopulation.

arguments
    P (1,1) struct
    S (1,1) struct
    kind (1,1) string {mustBeMember(kind, ["psth" "fractions" "tuning" "depth"])}
    target
    opts.Style = struct()
end

style = EphysAnalysisConfig.normalizeSection("Style", opts.Style);
[tl, ax] = renderLayout(target, 1, 1, style);
if isempty(ax); ax = nexttile(tl); end
G = S.groups;
nG = height(G);
C = lines(max(nG, 1));
names = G.group + " (" + string(G.nUnits) + ")";
hold(ax, 'on');
switch kind
    case "psth"
        t = S.psth.t;
        if style.ShowSEM
            for g = 1:nG
                semBand(ax, t, S.psth.mean(:, g), S.psth.sem(:, g), C(g, :));
            end
        end
        hl = gobjects(1, nG);
        for g = 1:nG
            hl(g) = plot(ax, t, S.psth.mean(:, g), 'Color', C(g, :), 'LineWidth', style.LineWidth);
        end
        xline(ax, 0, ':', 'Color', [0.4 0.4 0.4], 'HandleVisibility', 'off');
        xlabel(ax, 'Time from the event (s)');
        ylabel(ax, S.psth.units);
        title(ax, 'Population PSTH (mean \pm SEM across units)', 'FontWeight', 'normal');
        if style.Legend && nG > 1; placeLegend(ax, hl, names, style, tl, 'best'); end
    case "fractions"
        if ~any(G.nTested > 0)
            note(ax, 'No unit was tested (populationAnalysis Tests=false).');
        else
            Y = [G.nExcited G.nSuppressed] ./ G.nTested;
            leg = ["excited" "suppressed"];
            fc = [0.85 0.25 0.15; 0.2 0.4 0.8];
            if any(G.nTuningTested > 0)
                Y = [Y, G.nTuned ./ G.nTuningTested];
                leg(end+1) = "tuned";
                fc(end+1, :) = [0.35 0.6 0.35];
            end
            if any(G.nAurocCalled > 0)
                Y = [Y, [G.nAurocIncrease G.nAurocDecrease] ./ G.nAurocCalled];
                leg = [leg "auROC up" "auROC down"];
                fc = [fc; 0.95 0.6 0.45; 0.55 0.7 0.95];
            end
            nS = size(Y, 2);
            w = 0.8 / nS;
            b = gobjects(1, nS);
            for i = 1:nS   % one series at a time: a single group draws as plainly as many
                b(i) = bar(ax, (1:nG).' + (i - (nS + 1) / 2) * w, Y(:, i), w, 'FaceColor', fc(i, :), 'EdgeColor', 'none');
            end
            xticks(ax, 1:nG);
            xticklabels(ax, cellstr(G.group));
            ax.TickLabelInterpreter = 'none';
            xlim(ax, [0.5 nG + 0.5]);
            ylim(ax, [0 1]);
            ylabel(ax, 'Share of the units tested');
            title(ax, 'Responsive and tuned units', 'FontWeight', 'normal');
            if any(G.nAurocCalled > 0); subtitle(ax, aurocNote(S.auroc), 'FontSize', style.FontSize - 1); end
            if style.Legend; placeLegend(ax, b, leg, style, tl, 'best'); end
        end
    case "tuning"
        lev = S.tuning.levels;
        if isempty(lev)
            note(ax, 'No tuning parameter (populationAnalysis Param=).');
        else
            if isnumeric(lev)
                x = double(lev(:));
            else
                x = (1:numel(lev)).';
            end
            if style.ShowSEM
                for g = 1:nG
                    semBand(ax, x, S.tuning.mean(:, g), S.tuning.sem(:, g), C(g, :));
                end
            end
            hl = gobjects(1, nG);
            for g = 1:nG
                hl(g) = plot(ax, x, S.tuning.mean(:, g), '-o', 'Color', C(g, :), 'LineWidth', style.LineWidth, ...
                    'MarkerFaceColor', C(g, :), 'MarkerSize', 4);
            end
            if ~isnumeric(lev)
                xticks(ax, x);
                xticklabels(ax, cellstr(string(lev)));
            end
            xlabel(ax, P.tuning.param, 'Interpreter', 'none');
            if S.tuning.normalize == "peak"
                ylabel(ax, 'Rate / the unit''s highest level');
            else
                ylabel(ax, 'spikes/s');
            end
            title(ax, 'Tuning (mean \pm SEM across units)', 'FontWeight', 'normal');
            if style.Legend && nG > 1; placeLegend(ax, hl, names, style, tl, 'best'); end
        end
    case "depth"
        U = P.units;
        d = U.responseRate - U.baselineRate;
        dirn = string(U.direction);
        cats = ["excited" "suppressed" "other"];
        col = [0.85 0.25 0.15; 0.2 0.4 0.8; 0.55 0.55 0.55];
        is = [dirn == "excited" & U.responsive, dirn == "suppressed" & U.responsive];
        is(:, 3) = ~any(is, 2);
        hs = gobjects(1, 0);
        leg = strings(1, 0);
        for i = 1:3
            if ~any(is(:, i)); continue; end
            hs(end+1) = scatter(ax, d(is(:, i)), U.y(is(:, i)), 18, col(i, :), 'filled'); %#ok<AGROW>
            leg(end+1) = cats(i) + " (" + nnz(is(:, i)) + ")"; %#ok<AGROW>
        end
        xline(ax, 0, ':', 'Color', [0.4 0.4 0.4], 'HandleVisibility', 'off');
        xlabel(ax, 'Response - baseline rate (spikes/s)');
        ylabel(ax, 'Probe y (\mum)');
        title(ax, 'Units along the probe', 'FontWeight', 'normal');
        if style.Legend && ~isempty(hs); placeLegend(ax, hs, leg, style, tl, 'best'); end
end
styleAxes(ax, style);
hold(ax, 'off');
h = struct('layout', tl, 'axes', ax);
end


function s = aurocNote(A)
%aurocNote  How the auROC calls were made, e.g. "auROC: 95% CI cutoff +/-0.083 over 48 curves of 24 units".
F = A.families;
switch A.cutoff
    case "ci"
        if height(F) == 1
            s = sprintf("auROC: 95%% CI cutoff \\pm%.3g over %d curves of %d units", F.cutoffValue, F.nCurves, F.nUnits);
        else
            s = sprintf("auROC: 95%% CI cutoff \\pm%.3g to \\pm%.3g over each dataset's units", ...
                min(F.cutoffValue), max(F.cutoffValue));
        end
    case "fixed"
        s = sprintf("auROC: fixed cutoff \\pm%.3g", F.cutoffValue(1));
    otherwise
        s = "auROC: a test per unit, corrected over " + ternary(height(F) == 1, "every unit", "each dataset");
end
end


function s = ternary(c, a, b)
if c; s = a; else; s = b; end
end


function note(ax, msg)
text(ax, 0.5, 0.5, msg, 'Units', 'normalized', 'HorizontalAlignment', 'center', 'Color', [0.35 0.35 0.35]);
axis(ax, 'off');
end
