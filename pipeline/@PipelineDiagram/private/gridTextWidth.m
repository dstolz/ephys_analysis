function w = gridTextWidth(s, px)
%gridTextWidth  Rough width of S in Segoe UI at PX pixels (a little generous).
c = char(s);
em = 0.53 * ones(1, numel(c));
em(isstrprop(c, "upper")) = 0.64;
em(isstrprop(c, "digit")) = 0.56;
em(ismember(c, 'mwMW@%')) = 0.86;
em(ismember(c, 'ijlt.,:;''|!()[] ')) = 0.3;
em(ismember(c, 'frs-/_')) = 0.42;
w = sum(em) * px;
end


