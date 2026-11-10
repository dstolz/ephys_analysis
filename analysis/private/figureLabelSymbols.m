function txt = figureLabelSymbols(txt)
%figureLabelSymbols  A figure's text with its TeX character names, such as \mu or \pm, as the characters they name: "Amplitude (\muV)" is "Amplitude (µV)".
%   TXT = figureLabelSymbols(TXT) replaces each backslash name on the list
%   below by its character, in a text drawn as typed (Interpreter "none"):
%   a figure's title, a panel's title, x and y labels and note (a TeX note
%   reads its own), a layer's name (the legend) and a trial measure's
%   label. A name is the longest on the list that the letters after the
%   backslash start with, as MATLAB's TeX reads them: "\muV" is "µV",
%   "\infty" is "∞" (not "∈fty"). "^\circ" and "^{\circ}" are the degree
%   sign, as "\circ" is. A backslash before no name on the list stays as
%   typed, and so does every other character: an "_" or "^" in a unit's or
%   a dataset's name is no subscript or power. Converting twice changes
%   nothing more. TXT is text (char, a string or a string array: each
%   element); a char comes back as a char.
%
%   The names (MATLAB's TeX characters, with \varepsilon and \varphi)
%     Greek     \alpha α  \beta β  \gamma γ  \delta δ  \epsilon \varepsilon ε
%               \zeta ζ  \eta η  \theta θ  \vartheta ϑ  \iota ι  \kappa κ
%               \lambda λ  \mu µ  \nu ν  \xi ξ  \pi π  \varpi ϖ  \rho ρ
%               \sigma σ  \varsigma ς  \tau τ  \upsilon υ  \phi \varphi φ
%               \chi χ  \psi ψ  \omega ω  \Gamma Γ  \Delta Δ  \Theta Θ
%               \Lambda Λ  \Xi Ξ  \Pi Π  \Sigma Σ  \Upsilon Υ  \Phi Φ
%               \Psi Ψ  \Omega Ω
%     Math      \pm ±  \times ×  \div ÷  \cdot ·  \circ °  \leq ≤
%               \geq ≥  \neq ≠  \approx ≈  \sim ∼  \equiv ≡  \cong ≅
%               \propto ∝  \infty ∞  \partial ∂  \nabla ∇  \int ∫
%               \surd √  \prime ′  \ast ∗  \perp ⊥  \angle ∠  \neg ¬
%               \wedge ∧  \vee ∨  \forall ∀  \exists ∃  \in ∈  \ni ∋
%               \subset ⊂  \subseteq ⊆  \supset ⊃  \supseteq ⊇  \cap ∩
%               \cup ∪  \oplus ⊕  \otimes ⊗  \oslash ⊘  \aleph ℵ  \Re ℜ
%               \Im ℑ  \wp ℘  \lceil ⌈  \rceil ⌉  \lfloor ⌊  \rfloor ⌋
%               \langle ⟨  \rangle ⟩  \mid |
%     Arrows    \leftarrow ←  \rightarrow →  \leftrightarrow ↔  \uparrow ↑
%               \downarrow ↓  \Leftarrow ⇐  \Rightarrow ⇒
%     Other     \bullet •  \ldots …  \copyright ©  \clubsuit ♣
%               \diamondsuit ♦  \heartsuit ♥  \spadesuit ♠
%   (\mu is the micro sign, as in the figures' own "µm"; \epsilon and \phi
%   are the usual letter forms.)
%
%   See also figureLabelFill, figureLabelVariables, trialMeasureLabel.

persistent pat names chars
if isempty(pat)
    [names, chars] = symbolList();
    [~, o] = sort(strlength(names), 'descend');   % the longest first: "\infty" before "\int" before "\in"
    names = names(o);
    chars = chars(o);
    pat = char("\\(" + strjoin(names, "|") + ")");
end
wasChar = ischar(txt);
txt = string(txt);
for i = 1:numel(txt)
    t = txt(i);
    if ismissing(t) || ~contains(t, "\"); continue; end
    t = regexprep(t, '\^(\\circ|\{\\circ\})', char(176));   % a degree written as TeX's power of \circ
    [tok, rest] = regexp(char(t), pat, 'tokens', 'split');
    if ~isempty(tok)
        [~, j] = ismember(string(cellfun(@(c) c{1}, tok, 'UniformOutput', false)), names);
        parts = strings(1, 2 * numel(tok) + 1);
        parts(1:2:end) = string(rest);
        parts(2:2:end) = chars(j);
        t = join(parts, "");
    end
    txt(i) = t;
end
if wasChar; txt = char(txt); end
end


function [names, chars] = symbolList()
%symbolList  Each TeX name (without its backslash) and its character.
L = [
    "alpha" "α"; "beta" "β"; "gamma" "γ"; "delta" "δ"; "epsilon" "ε"; "varepsilon" "ε"; "zeta" "ζ"; "eta" "η"
    "theta" "θ"; "vartheta" "ϑ"; "iota" "ι"; "kappa" "κ"; "lambda" "λ"; "mu" "µ"; "nu" "ν"; "xi" "ξ"; "pi" "π"
    "varpi" "ϖ"; "rho" "ρ"; "sigma" "σ"; "varsigma" "ς"; "tau" "τ"; "upsilon" "υ"; "phi" "φ"; "varphi" "φ"
    "chi" "χ"; "psi" "ψ"; "omega" "ω"
    "Gamma" "Γ"; "Delta" "Δ"; "Theta" "Θ"; "Lambda" "Λ"; "Xi" "Ξ"; "Pi" "Π"; "Sigma" "Σ"; "Upsilon" "Υ"
    "Phi" "Φ"; "Psi" "Ψ"; "Omega" "Ω"
    "pm" "±"; "times" "×"; "div" "÷"; "cdot" "·"; "circ" "°"; "leq" "≤"; "geq" "≥"; "neq" "≠"; "approx" "≈"
    "sim" "∼"; "equiv" "≡"; "cong" "≅"; "propto" "∝"; "infty" "∞"; "partial" "∂"; "nabla" "∇"; "int" "∫"
    "surd" "√"; "prime" "′"; "ast" "∗"; "perp" "⊥"; "angle" "∠"; "neg" "¬"; "wedge" "∧"; "vee" "∨"
    "forall" "∀"; "exists" "∃"; "in" "∈"; "ni" "∋"; "subset" "⊂"; "subseteq" "⊆"; "supset" "⊃"; "supseteq" "⊇"
    "cap" "∩"; "cup" "∪"; "oplus" "⊕"; "otimes" "⊗"; "oslash" "⊘"; "aleph" "ℵ"; "Re" "ℜ"; "Im" "ℑ"; "wp" "℘"
    "lceil" "⌈"; "rceil" "⌉"; "lfloor" "⌊"; "rfloor" "⌋"; "langle" "⟨"; "rangle" "⟩"; "mid" "|"
    "leftarrow" "←"; "rightarrow" "→"; "leftrightarrow" "↔"; "uparrow" "↑"; "downarrow" "↓"
    "Leftarrow" "⇐"; "Rightarrow" "⇒"
    "bullet" "•"; "ldots" "…"; "copyright" "©"; "clubsuit" "♣"; "diamondsuit" "♦"; "heartsuit" "♥"; "spadesuit" "♠"
    ];
names = L(:, 1);
chars = L(:, 2);
end
