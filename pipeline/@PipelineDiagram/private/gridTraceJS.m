function s = gridTraceJS()
%gridTraceJS  Hovering (or focusing) a box lights its arrows and the boxes at their other ends.
%   Runs in the app and in a saved page.
s = join([ ...
    "(function () {"
    "  var edges = document.querySelectorAll('.edge'), nodes = document.querySelectorAll('.node');"
    "  function trace(id) {"
    "    var lit = {}; lit[id] = true;"
    "    for (var i = 0; i < edges.length; i++) {"
    "      var a = edges[i].getAttribute('data-from'), b = edges[i].getAttribute('data-to');"
    "      var on = a === id || b === id;"
    "      if (on) { lit[a] = true; lit[b] = true; }"
    "      edges[i].classList.toggle('lit', on);"
    "    }"
    "    for (var j = 0; j < nodes.length; j++) {"
    "      nodes[j].classList.toggle('lit', !!lit[nodes[j].getAttribute('data-id')]);"
    "    }"
    "    document.body.classList.add('trace');"
    "  }"
    "  function untrace() { document.body.classList.remove('trace'); }"
    "  for (var k = 0; k < nodes.length; k++) {"
    "    (function (n) {"
    "      var id = n.getAttribute('data-id');"
    "      n.addEventListener('mouseenter', function () { trace(id); });"
    "      n.addEventListener('mouseleave', untrace);"
    "      n.addEventListener('focusin', function () { trace(id); });"
    "      n.addEventListener('focusout', untrace);"
    "    })(nodes[k]);"
    "  }"
    "})();"
    ], newline);
end
