function keepCost(obj, key, secsCompute, secsDraw)
%keepCost  The two parts of the preview just drawn (FigurePreviewCost), which previewCost predicts the next one from.
%   KEY is the data key it computed (previewDataKey). The compute's time
%   is kept when the data were computed: another key, or a time longer
%   than the one kept (the runner had forgotten them). A preview of the
%   same data reused them and took next to no time to compute, which
%   says nothing of what the next edit of the data costs: the time kept
%   stays. The drawing's time is always the last one.
C = obj.FigurePreviewCost;
if ~isequaln(C.key, key) || secsCompute > C.compute
    C.compute = secsCompute;
end
C.key = key;
C.draw = max(secsDraw, 0);
obj.FigurePreviewCost = C;
end
