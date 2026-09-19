function onHelp(obj, page)
%onHelp  Open a wiki page (helpURL) in the system browser.
url = obj.helpURL(page);
if web(url, "-browser") ~= 0
    uialert(obj.Fig, "Could not open a web browser. The page is at:" + newline + url, "Help");
    return
end
obj.setStatus("Opened " + url + " in the browser.");
end
