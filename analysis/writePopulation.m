function files = writePopulation(P, S, folder, opts)
%writePopulation  Write a population analysis: its tables as CSV, its figures, a JSON record.
%   FILES = writePopulation(P, S, FOLDER) writes populationAnalysis' P and
%   populationSummary's S into FOLDER (created when missing):
%     population_units.csv     P.units, one row per unit
%     population_groups.csv    S.groups, one row per group
%     population_psth.csv      t and each group's mean and SEM PSTH
%     population_tuning.csv    the levels and each group's mean and SEM
%                              tuning (with a Param)
%     population_<kind>.<fmt>  renderPopulation's figures: psth and depth;
%                              fractions when the units were tested;
%                              tuning with a Param
%     population.json          P.params, P.datasets, S.params,
%                              P.provenance, P.created and the files
%                              written (non-finite numbers as strings)
%   and returns the files written. A file of the same name is replaced.
%
%   Options: Formats (["png"]; exportFigure's png / eps / svg / pdf), Dpi
%   (150), FigureSizeCm ([18 12]), Style (renderPopulation's).
%
%   See also populationAnalysis, populationSummary, renderPopulation.

arguments
    P (1,1) struct
    S (1,1) struct
    folder (1,1) string
    opts.Formats (1,:) string = "png"
    opts.Dpi (1,1) double {mustBePositive} = 150
    opts.FigureSizeCm (1,2) double {mustBePositive} = [18 12]
    opts.Style = struct()
end

if ~isfolder(folder)
    [ok, msg] = mkdir(folder);
    if ~ok
        error('writePopulation:CannotWrite', 'Cannot create %s: %s', folder, msg);
    end
end
files = strings(1, 0);

f = fullfile(folder, "population_units.csv");
writetable(P.units, f);
files(end+1) = f;
f = fullfile(folder, "population_groups.csv");
writetable(S.groups, f);
files(end+1) = f;
f = fullfile(folder, "population_psth.csv");
writetable(curves("t", S.psth.t, S.psth.mean, S.psth.sem, S.groups.group), f);
files(end+1) = f;
withTuning = ~isempty(S.tuning.levels);
if withTuning
    f = fullfile(folder, "population_tuning.csv");
    writetable(curves(P.tuning.param, S.tuning.levels, S.tuning.mean, S.tuning.sem, S.groups.group), f);
    files(end+1) = f;
end

kinds = "psth";
if any(S.groups.nTested > 0); kinds(end+1) = "fractions"; end
if withTuning; kinds(end+1) = "tuning"; end
kinds(end+1) = "depth";
for kind = kinds
    fig = newExportFigure(struct('FigureSizeCm', opts.FigureSizeCm));
    closer = onCleanup(@() close(fig));
    renderPopulation(P, S, kind, fig, Style=opts.Style);
    files = [files, exportFigure(fig, fullfile(folder, "population_" + kind), Format=opts.Formats, Dpi=opts.Dpi)]; %#ok<AGROW>
    clear closer
end

rec = struct();
rec.params = P.params;
rec.summary = S.params;
rec.datasets = table2struct(P.datasets);
rec.provenance = P.provenance;
rec.created = P.created;
f = fullfile(folder, "population.json");
rec.files = [files, f];
writeJsonFile(f, rec, NonFinite="string");
files(end+1) = f;
end


function T = curves(xName, x, m, s, groups)
%curves  A table: X, then "mean <group>" and "sem <group>" for each group.
T = table(x(:), 'VariableNames', cellstr(xName));
for g = 1:numel(groups)
    T.("mean " + groups(g)) = m(:, g);
    T.("sem " + groups(g)) = s(:, g);
end
end
