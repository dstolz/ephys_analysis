function C = reviewTableRows(R)
%reviewTableRows  The Review units table, one row per cluster of R (loadReviewResults).
%   Unit, Group, Shank, Ch (name, else recording channel), X, Y (template
%   center), #Spk, FR, Amp, Cont%, QC (meets the criteria: "yes" / "no",
%   blank without metrics), ISIv (isiViolationsRatio), Pres (presenceRatio),
%   Cutoff (amplitudeCutoff), SNR, Notes (editable).
U = numel(R.clusterID);
C = cell(U, 16);
q = R.units;
hasQ = isfield(R, 'qc') && R.qc.has;
for u = 1:U
    ch = R.channelName(u);
    if ch == "" && isfinite(R.recChan(u)); ch = string(R.recChan(u)); end
    C{u, 1}  = R.clusterID(u);
    C{u, 2}  = char(R.group(u));
    C{u, 3}  = R.shank(u);
    C{u, 4}  = char(ch);
    C{u, 5}  = round(R.x(u), 1);
    C{u, 6}  = round(R.y(u), 1);
    C{u, 7}  = R.nSpikes(u);
    C{u, 8}  = round(R.firingRate(u), 2);
    C{u, 9}  = round(R.ampUnit(u), 1);
    C{u, 10} = round(R.contam(u), 1);
    if hasQ
        C{u, 11} = ternary(R.qc.pass(u), 'yes', 'no');
        C{u, 12} = round(q.isiViolationsRatio(u), 2);
        C{u, 13} = round(q.presenceRatio(u), 2);
        C{u, 14} = round(q.amplitudeCutoff(u), 3);
        C{u, 15} = round(q.snr(u), 1);
    else
        C(u, 11:15) = {''};
    end
    C{u, 16} = char(R.notes(u));
end
end


function out = ternary(c, a, b)
if c; out = a; else; out = b; end
end
