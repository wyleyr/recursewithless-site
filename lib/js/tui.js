let TERM = null;
let BUF = null;
let LINE_BUFFER = "";
let DISPLAY = null;
let CURRENT_NODE = document.getElementById("root");

function print(s) {
    for (i = 0; i < s.length; i++){
        TERM.innerHTML += s[i];
        // TODO: slight delay?
    }
}

function printLine(s) {
    print(s + "\n");
}

function printLink(url, s) {
    TERM.innerHTML += `<a href="${url}">${s || url}</a>`;
}


function readKey(e) {
    if (e.code === "Enter"){
        printLine(prompt() + LINE_BUFFER);
        sh(LINE_BUFFER);
        LINE_BUFFER = "";
    }
    else if (e.code === "Backspace") {
        LINE_BUFFER = LINE_BUFFER.substring(0, LINE_BUFFER.length - 1);
    }
    // TODO: can I prevent Tab, ', Ctrl-K and other things from stealing focus?
    // do I want to??
    else if (e.key.length === 1) { // rules out all non-character keys
          LINE_BUFFER += e.key;
    }
    BUF.innerHTML = prompt() + LINE_BUFFER + "█" +
        (LINE_BUFFER.length ? "  ⏎ <small>= run</small>" : "");
}

function getPath(node) {
    let path = "/" + CURRENT_NODE.id;
    while (node && node.id != "root") {
        node = node.parentElement;
        if (node.id) {
            path = "/" + node.id + path;
        }
    }

    return path;
}

function getDesc(node) {
    // Prefer explicit TOC descriptions:
    if (node.dataset.tocd && node.dataset.tocd !== "") {
        return node.dataset.tocd;
    }

    // Otherwise make a best effort:
    switch (node.tagName) {
    case "A": {
        let target = node.href;
        if (node.textContent.length < 50) {
            return node.textContent + " (link)";
        } else if (node.href) {
            return node.href + " (link)";
        } else {
            return "(anchor)";
        }
    }
    case "IMG": {
        if (node.title || node.alt) {
            return (node.title || node.alt) + " (image)";
        } else {
            return "(image)";
        }
    }
    }
}

function prompt() {
    let path = getPath(CURRENT_NODE);
    return `rwlsh:${path}> `;
}

function boot() {
    // since JS is running, hide the static data:
    let dataRoot = document.getElementById("root");
    dataRoot.style.display = "none";
    
    // set up the "terminal":
    let termRoot = document.getElementById("terminal");
    termRoot.innerHTML = ""; // clear any existing content
    termRoot.style.height = "100vh";
    
    // text is printed to TERM when a command is executed:
    TERM = document.createElement("pre");
    termRoot.appendChild(TERM);
    // user input appears in BUF when typed:
    BUF = document.createElement("pre");
    BUF.textContent = prompt() + "█";
    termRoot.appendChild(BUF);
    // DISPLAY shows parts of the document on command:
    DISPLAY = document.createElement("div");
    DISPLAY.id = "display";
    termRoot.appendChild(DISPLAY);

    document.addEventListener('keyup', readKey);

    // greet the user
    motd();
}

function shutdown(args) {
    printLine("Shutting down...");
    let termRoot = document.getElementById("terminal");
    termRoot.innerHTML = ""; // clear everything

    rebootBtn = document.createElement("a");
    rebootBtn.onclick = boot;
    rebootBtn.textContent = "Click here to reboot the terminal interface";

    termRoot.appendChild(rebootBtn);
    termRoot.style.height = ""; // don't take up the whole screen

    document.removeEventListener('keyup', readKey);
    
    let dataRoot = document.getElementById("root");
    dataRoot.style.display = "block";
}

function loadTextFrom(url) {
    fetch(url)
        .then(response => {
            if (!response.ok) {
                throw new Error("Non-200 response");
            } else {
                response.text().then(text => print(text));
            }
        })
        .catch(err => {
            printLine("I'm sorry, I tried to load ");
            printLink(url);
            printLine("\nbut the server responded impolitely (or not at all).")
        })
}

function getUrlFor(id, type) {
    let el = document.getElementById(id);
    if (!el) return undefined;
    
    if (type && el.dataset[type]) {
        return el.dataset[type];
    }
    return el.href;
}

// commands:
function cat(args) {
    const [cmd, ...rest] = args;

    rest.forEach(name => {
        let url = getUrlFor(name);
        if (url) {
            loadTextFrom(url);
        } else {
            printLine(`No such document: ${name}`);
        }
    });
}

function cls(args) {
    TERM.textContent = "";
}

function cn(args) {
    const [cmd, ...rest] = args;
    if (!rest.length) {
        printLine("What node do you want to go to?");
        return;
    }

    let name = rest[0];
    let newNode = null;
    if (name === "..") {
        newNode = CURRENT_NODE.parentElement;
        while (!newNode.id) {
            newNode = newNode.parentElement;
        }
    } else {
        newNode = document.getElementById(name);
    }

    if (newNode) {
        hide(); // make sure DISPLAY stays current
        CURRENT_NODE = newNode;
    } else {
        printLine(`I couldn't find the node '${name}' in this document.`);
    }
}

function browse(args) {
    const [cmd, ...rest] = args;
    if (!rest.length) {
        printLine(`What do you want to ${cmd}?`);
        return;
    }

    let name = rest[0]; // TODO: loop over all args?
    let url = getUrlFor(name);
    if (url) {
        let opened = window.open(url, "_blank");
        if (!opened) {
            printLine(`I couldn't open ${name} myself. You can try:`);
            printLink(url);
            print("\n");
        }
    } else {
        printLine(`Sorry, I'm not sure where '${name}' is.`);
    }
}

function echo(args) {
    const [cmd, ...rest] = args;
    printLine(rest.join(" "));
}

function feedback(args) {
    let addr = 'feedback';
    let domain = 'recursewithless.net';
    let opened = window.open(`mailto:${addr}@${domain}`);
    if (!opened) {
        printLine(`Sorry, I couldn't open your mail client.`);
        printLine(`You can send feedback to ${addr}@${domain}.`);
    }
}

function follow(args) {
    const [cmd, ...rest] = args;

    let node = rest.length ? document.getElementById(rest[0]) : CURRENT_NODE;

    if (node.href) {
        window.location = node.href;
    } else if (node.src) {
        window.location = node.src;
    } else if (node.cite) {
        window.location = node.cite;
    } else { // other attributes can hold URLs, but I don't expect to use them
        printLine(`Sorry, I couldn't find a URL to follow at ${node.id}`);
        printLine("Maybe you meant 'change'?")
    }
}

function hide(args) {
    DISPLAY.innerHTML = "";
}

function help(args) {
    const [cmd, ...rest] = args;
    if (!rest || !rest.length) {
        printLine("");
        printLine("The following commands are available:");
        for (cmdName in COMMANDS) {
            printLine("  " + cmdName + COMMANDS[cmdName].help);
        }
        printLine("");
        where();

    } 
    // TODO command specific help 

}

function collectChildren(node) {
    // a node's "children" might not be its direct children in the DOM,
    // So if there are no immediate named children,
    // recurse down the DOM until we find a named element.
    // Returns an object mapping names to TOC descriptions.
    if (!node || node.childElementCount === 0) return {};
    
    let namedChildren = {};
    for (child of node.children) {
        if (child.id && child.id.length) {
            namedChildren[child.id] = getDesc(child);
        } else {
            let others = collectChildren(child);
            namedChildren = {...namedChildren, ...others};
        }
    }

    return namedChildren;
}

function ls(args) {
    const [cmd, ...rest] = args;

    let node = rest.length ? document.getElementById(rest[0]) : CURRENT_NODE;
    if (node) {
        let contents = collectChildren(node);
        let empty = true; 
        for (name in contents) {
            empty = false;
            print(name);
            if (contents[name]) {
                print(': ');
                print(contents[name]);
            }
            print('\n');
        }
        if (empty) printLine("No nodes to list. Try 'show'?");

    } else {
        printLine(`${cmd}: Sorry, I couldn't find node ${rest[0]}`);
    }
}

function motd() {
    printLine("//////////////////////////////////////////////////");
    printLine(`| ${document.title} @ recursewithless.net`);
    for(let i = 0; i < 50; i++) print("\\"); print("\n");
    printLine("Welcome! This is the rwl shell, a rather wearisome loop.");
    printLine("I will do my best to assist you.");
    printLine("If this is your first time here, try: help");

}

function relabel(node) {
    if (node.id && node.id.length) {
        node.id = node.id + "-displayed"; 
    }
    if (node.childElementCount === 0) return;
    for (child of node.children) relabel(child);
}

function show(args) {
    const [cmd, ...rest] = args;
    let node = rest.length ? document.getElementById(rest[0]) : CURRENT_NODE;
    let toDisplay = node.cloneNode(true);

    if (toDisplay.id === "root") {
        // allow the whole doc to be shown: 
        toDisplay.style.display = "";
    }

    // prevent duplicate IDs;
    relabel(toDisplay);
    
    DISPLAY.innerHTML = "";
    DISPLAY.appendChild(toDisplay);

}

function tocUnder(node) {
    let name = node.id;
    let desc = getDesc(node);
    let subentries = [];
    let tocEntry = { name, desc };
    
    if (node.childElementCount === 0) {
        if (name && name !== "") {
            return tocEntry;
        } else {
            return undefined;
        }
    }

    for (child of node.children) {
        let subtoc = tocUnder(child);
        if (Array.isArray(subtoc)) {
            subentries = subentries.concat(subtoc);
        } else if (subtoc && subtoc.hasOwnProperty('name')) {
            subentries.push(subtoc);
        }
    }
    
    if (name && name !== "") {
        tocEntry.subentries = subentries;
        return tocEntry;
    } else {
        return subentries;
    }
    
}

function printTOC(entry, depth) {
    let indent = "  ".repeat(depth);
    let desc = entry.desc ? `: ${entry.desc}` : "";
    let here = entry.name === CURRENT_NODE.id ? " (* you are here)" : "";
    printLine(`${indent}${entry.name}${desc}${here}`);

    if (entry.subentries && entry.subentries.length) {
        entry.subentries.forEach(e => printTOC(e, depth+1));
    }
}

function toc(args) {
    const [cmd, ...rest] = args;
    let node = rest.length ? document.getElementById(rest[0]) : document.getElementById("root");

    let theTOC = tocUnder(node);

    printTOC(theTOC, 0);
}

function where(args) {
    printLine(`You are at the node '${CURRENT_NODE.id}'.`);
    let tag = CURRENT_NODE.tagName;
    let article = "AEIOU".includes(tag[0]) ? "an" : "a";
    printLine(`This is ${article} ${tag} node.`);

    if (tag === "IMG") {
        printLine("Use 'show' to see the image.");
    } else {
        printLine("Use 'show' to see its content.");
    }

    let url = CURRENT_NODE.href || CURRENT_NODE.src || CURRENT_NODE.cite;
    if (url) {
        printLine(`This node contains a link to: ${url}`);
        printLine("Use 'follow' to visit this URL.");
    }
}

function who(args) {
    let addr = document.getElementById("contact");
    printLine(addr.textContent);
}

// The command interpreter:
const COMMANDS = {
//    cat: { impl: cat, help: ` DOC: display DOC here`, aliases: ['type', 'print']},
    clear: { impl: cls, help: `: clear screen`, aliases: ['cls'] },
//    echo: { impl: echo, help: ` ARGS: display ARGS`, aliases: []},
    feedback: { impl: feedback, help: `: send feedback`, aliases: []},
    follow: { impl: follow, help: ` [NAME]: follow link or URL here [or at NAME]`, aliases: ['visit']},
    'goto': { impl: cn, help: ` NAME: go to node NAME`, aliases: ['cd', 'jump']},
    list: { impl: ls, help: ` [NAME]: list nodes here [or under NAME]`, aliases: ['ls', 'dir']},
    help: { impl: help, help: `: display help`, aliases: ['?', '??']},
    hide: { impl: hide, help: `: hide what is currently shown`, aliases: ['close']},
    show: { impl: show, help: ` [NAME]: show contents here [or of NAME]`, aliases: ['open', 'view']},
    shutdown: { impl: shutdown, help: `: turn off this interface`, aliases: ['quit', 'exit', 'die']},
    toc: { impl: toc, help: ` [NAME]: display the table of contents [under NAME]`, aliases: []},
    where: { impl: where, help: `: where are you?`, aliases: ['look', 'describe']},
    who: { impl: who, help: `: who am I?`, aliases: ['w', 'finger']},
};

function findCommand(cmd) {
    for (c in COMMANDS) {
        if (c === cmd || COMMANDS[c].aliases.includes(cmd)) {
            return COMMANDS[c];
        }
    }
    return undefined;
}

function sh(input) {
    if (!input || !input.length) return;
    
    let args = input.split(" ").filter(a => a != "");
    if (!args.length) return;
    
    let cmd = args[0].toLowerCase();
    let cmdStruct = findCommand(cmd);

    if (cmdStruct) {
        cmdStruct.impl(args);
    } else if (document.getElementById(cmd)) {
        printLine(`Sorry, I don't understand '${cmd}'. Did you mean 'goto ${cmd}'?`);
    } else { 
        printLine(`Sorry, I don't understand '${cmd}'. Try 'help'?`)
    }

    BUF.scrollIntoView();
}

boot();
