// tui.js
// This work is licensed under the Creative Commons Attribution-ShareAlike 4.0 International License.
// To view a copy of this license, visit http://creativecommons.org/licenses/by-sa/4.0/ 
// 
// Thanks for your interest!

// Global state 
let LINE_BUFFER = ""; // stores user input before Enter is pressed
let BUF = null; // <pre> where LINE_BUFFER is displayed 
let TERM = null;  // <pre> node where output is printed
let DISPLAY = null; // <div> where content is show()-n
let CURRENT_NODE = document.getElementById("root"); // current location in document

// boot: initialize the shell when JS is running.
// This is the entry point for the interface; it is called in the last
// line of this script.
function boot() {
    // don't even try if we're on a small device; this UI needs a real keyboard:
    // TODO: a tablet is big enough but need to pop up the virtual keyboard
    if (window.screen.width < 768 || window.screen.height < 768) {
        return;
    }

    // since JS is running, hide the static data:
    let dataRoot = document.getElementById("root");
    dataRoot.style.display = "none";

    let navRoot = document.getElementById("nav");
    navRoot.style.display = "none";
   
    let uiRoot = document.getElementById("ui");
    uiRoot.style.display = "flex";
    uiRoot.style.height = "100vh";

    // set up the "terminal":
    let termRoot = document.getElementById("terminal"); 
    termRoot.innerHTML = ""; // clear reboot message left by shutdown()

    // text is printed to TERM when a command is executed:
    TERM = document.createElement("pre");
    termRoot.appendChild(TERM);
    // user input appears in BUF when typed:
    BUF = document.createElement("pre");
    BUF.textContent = prompt() + "█";
    termRoot.appendChild(BUF);

    // DISPLAY shows parts of the document on command:
    DISPLAY = document.getElementById("display");

    // event listeners handle keyboard input:
    document.addEventListener('keyup', readKeyUp);
    document.addEventListener('keydown', readKeyDown);

    // greet the user
    motp();
}

// shutdown: reverse the changes to the DOM made by boot().
// Re-displays the underlying document as it would normally look (plus a link to reboot)
function shutdown(args) {
    printLine("Shutting down...");
    let termRoot = document.getElementById("terminal");
    termRoot.innerHTML = ""; // clear everything
    DISPLAY.innerHTML = "";

    rebootBtn = document.createElement("a");
    rebootBtn.onclick = boot;
    rebootBtn.textContent = "Click here to reboot the terminal interface";
    termRoot.appendChild(rebootBtn);

    let uiRoot = document.getElementById("ui");
    uiRoot.style.height = ""; // don't take up the whole screen

    document.removeEventListener('keyup', readKeyUp);
    document.removeEventListener('keydown', readKeyDown);
    
    let dataRoot = document.getElementById("root");
    dataRoot.style.display = "block";

    let navRoot = document.getElementById("nav");
    navRoot.style.display = "block";

}

// Event listeners; these handle keyboard input events to 

function readKeyUp(e) {
    // these are handled on keyDown; don't process them again here:
    if (e.code === "Backspace" || e.ctrlKey) return; 
    
    if (e.code === "Enter"){
        printLine(prompt() + LINE_BUFFER);
        sh(LINE_BUFFER);
        LINE_BUFFER = "";
    } 
    // TODO: can I prevent Tab, ', Ctrl-K and other things from stealing focus?
    // do I want to??
    else if (e.key.length === 1) { // rules out all non-character keys
        LINE_BUFFER += e.key;
    }
    BUF.innerHTML = prompt() + LINE_BUFFER + "█" +
        (LINE_BUFFER.length ? "  ⏎ <small>= run</small>" : "");
}

function readKeyDown(e) {
    // reading on keyDown allows repeats when key is held down:
    if (e.code === "Backspace") {
        let i = Math.max(0, LINE_BUFFER.length - 1);
        LINE_BUFFER = LINE_BUFFER.substring(0, i);
    } else if (e.ctrlKey && e.key === "k"){
        e.preventDefault();
        LINE_BUFFER = "";
    }

    BUF.innerHTML = prompt() + LINE_BUFFER + "█" +
        (LINE_BUFFER.length ? "  ⏎ <small>= run</small>" : "");

}

// The command interpreter:

// sh(): The top-level of the shell interface. Reads a command on input
// and executes the corresponding function, if any. It provides all words
// typed on the command line (including the command name) as an array to the function.
function sh(input) {
    if (!input || !input.length) return;
    
    let args = input.split(" ").filter(a => a != "");
    if (!args.length) return;
    
    let cmd = args[0].toLowerCase();
    let cmdStruct = findCommand(cmd);

    if (cmdStruct) {
        cmdStruct.impl(args);
    } else if (document.getElementById(cmd)) {
        // when a node name is given as a command, implicitly change
        // to it and show its contents:
        let cnArgs = ['cn', ...args];
        cn(cnArgs);
    } else { 
        printLine(`Sorry, I don't understand '${cmd}'. Try 'toc' or 'help'?`)
    }

    BUF.scrollIntoView();
}

const COMMANDS = {
    bling: { impl: bling, help: ` N: change to color scheme N`, aliases: [], hidden: true },
    clear: { impl: cls, help: `: clear screen`, aliases: ['cls'] },
    mail: { impl: feedback, help: `: send (love|hate|feedback)`, aliases: ['feedback']},
    follow: { impl: follow, help: ` [NAME]: follow link or URL here [or at NAME]`, aliases: ['visit'], hidden: true},
    'goto': { impl: cn, help: ` NAME: go to NAME`, aliases: ['go', 'cd', 'jump']},
    help: { impl: help, help: `: display help`, aliases: ['?', '??']},
    hide: { impl: hide, help: `: hide what is currently shown`, aliases: ['close'], hidden: true},
    show: { impl: show, help: ` [NAME]: show contents here [or of NAME]`, aliases: ['open', 'view'], hidden: true},
    shutdown: { impl: shutdown, help: `: turn off this interface`, aliases: ['quit', 'exit', 'die']},
    toc: { impl: toc, help: ` [NAME]: display the table of contents [under NAME]`, aliases: ['ls', 'dir']},
    where: { impl: where, help: `: where are you?`, aliases: ['look', 'describe'], hidden: true},
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


// Implementations of the commands in the shell:

function bling(args) {
    const [cmd, ...rest] = args;
    const colors = [
        // fg, bg:
        ['black', 'white'],
        ['orange', 'black'],
        ['white', 'mediumblue'],
        ['lime', 'darkgreen'],
        ['gold', 'purple'],
        ['magenta', 'midnightblue'],
        ['peru', 'bisque'],
        ['red', 'maroon'],
    ];
    const TUI = document.getElementById("terminal");
    const oldBg = TUI.style.backgroundColor || "white";
    const oldFg = TUI.style.color || "black";

    if (rest.length === 0) {
        printLine("Which bling do you want? Use 'bling N':");
        for (let i = 0; i < colors.length; i++) {
            let [fg, bg] = colors[i];
            printLine(`  ${i}: ${fg} on ${bg}`);
        }
        printLine("Or use 'bling invert' to invert the current colors.");
        return;
    }

    let scheme = rest[0].toLowerCase().trim();
    if (scheme === 'invert') {
        TUI.style.backgroundColor = oldFg;
        TUI.style.color = oldBg;
        return;
    }

    let schemeIdx = parseInt(scheme);
    if (schemeIdx < colors.length) {
        let [newFg, newBg] = colors[schemeIdx];
        TUI.style.backgroundColor = newBg;
        TUI.style.color = newFg;
        return;
    } 
    
}

function cls(args) {
    TERM.innerHTML = "";
    DISPLAY.innerHTML = "";
}

// 'change node' (like Unix 'cd'), because 'goto' is a keyword...
function cn(args) {
    const [cmd, ...rest] = args;
    if (!rest.length) {
        printLine("What node do you want to go to? (Try 'toc'?)");
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

        if (newNode.href && (newNode.tagName == "A" || newNode.tagName == "LINK")) {
            // if the node is just a link, automatically follow it, for better UX:
            window.location = newNode.href;
        } else {
            // otherwise display its contents:
            let showArgs = ['show']
            show(showArgs);
        }
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

function feedback(args) {
    let addr = 'rwl';
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

function help(args) {
    const [cmd, ...rest] = args;
    if (!rest || !rest.length) {
        printLine("");
        printLine("This is the rwl shell, a rather wearisome loop.");
        printLine("I will do my best to assist you.");
        printLine("The following commands are available:");
        for (cmdName in COMMANDS) {
            let cmdStruct = COMMANDS[cmdName];
            if (!cmdStruct.hidden) {
                printLine("  " + cmdName + cmdStruct.help);
            }
        }
        printLine("");

    } 
    // TODO command specific help 

}

function motp() {
    let title = `=> ${document.title} <=`;
    for(let i = 0; i < title.length; i++) print("/"); print("\n");
    printLine(title);
    for(let i = 0; i < title.length; i++) print("\\"); print("\n");

    let motpNode = document.getElementById("motp");

    if (motpNode) {
        // pandoc can introduce spurious whitespace and newlines,
        // so strip that, but allow explicit linebreaks:
        let motp = motpNode.innerText.replaceAll("\n", " ").replaceAll("<br>", "\n").trim();
        print("\n");
        print(motp);
        print("\n");
    }

}

function hide(args) {
    DISPLAY.innerHTML = "";
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

function toc(args) {
    const [cmd, ...rest] = args;
    let node = rest.length ? document.getElementById(rest[0]) : document.getElementById("root");

    let theTOC = tocUnder(node);

    printTOC(theTOC, 0);
    printLine("\nType the name of an entry to display it.")
}

function where(args) {
    printLine(`You are at the node '${CURRENT_NODE.id}'.`);
    let tag = CURRENT_NODE.tagName;
    let article = "AEIOU".includes(tag[0]) ? "an" : "a";
    printLine(`This is ${article} ${tag} node.`);

    let url = CURRENT_NODE.href || CURRENT_NODE.src || CURRENT_NODE.cite;
    if (url) {
        printLine(`This node contains a link to: ${url}`);
        printLine("Use 'follow' to visit this URL.");
    }
}

function who(args) {
    let uname = 'rwl';
    let domain = 'recursewithless.net';
    let addrHTML = `
          <figure>
            <img src="lib/img/selfportrait.png" title="self-portrait">
            <figcaption>
              <address>Richard W. Lawrence<br>
                <a href="mailto:${uname}@${domain}">${uname}@${domain}</a>
              </address>
           </figcaption>
          </figure>`;
    DISPLAY.innerHTML = addrHTML;

}

// Utility functions needed by the commands above:

// print: display output to the terminal
function print(s) {
    for (i = 0; i < s.length; i++){
        TERM.innerHTML += s[i];
        // TODO: slight delay?
    }
}

// printLine: print() and add a newline at the end
function printLine(s) {
    print(s + "\n");
}

// printLink: insert a link into the terminal output
function printLink(url, s) {
    TERM.innerHTML += `<a href="${url}">${s || url}</a>`;
}


// getPath: given a (named) node, find its path in the document tree
// Returns a string like "/root/some/node"
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

// getDesc: return a description of the given node
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
            return node.textContent.replaceAll("\n", " ") + " (link)";
        } else if (node.href) {
            return node.href + " (link)";
        } else {
            return "(anchor)";
        }
    }
    case "IMG": {
        if (node.title || node.alt) {
            return (node.title || node.alt).replaceAll("\n", " ") + " (image)";
        } else {
            return "(image)";
        }
    }
    }
}

// prompt: returns a shell prompt 
function prompt() {
    let path = getPath(CURRENT_NODE);
    return `rwlsh:${path}> `;
}

// collectChilden: return the immediate children of the given node in the
// document tree. Returns an object mapping node names to descriptions.
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

// relabel: recursively change the id attributes of the given node and its
// children. Ensures that a cloned node can be inserted into the document
// by show() without duplicating IDs.
function relabel(node) {
    if (node.id && node.id.length) {
        node.id = node.id + "-displayed"; 
    }
    if (node.childElementCount === 0) return;
    for (child of node.children) relabel(child);
}

// tocUnder: recursively find the table of contents under the given node.
// Returns either (a) an object containing 'name', 'desc' and
// 'subentries' fields for the given node, or (b) an array of such objects.
// The latter is used for unnamed document nodes which do not themselves
// generate a toc entry, but have named descendants which do.
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

// printTOC: recursively print a table of contents object of the sort
// returned by tocUnder(), with proper indentation.
function printTOC(entry, depth) {
    let indent = "  ".repeat(depth);
    let desc = entry.desc ? `: ${entry.desc}` : "";
    let here = entry.name === CURRENT_NODE.id ? " (⇐ you are here)" : "";
    printLine(`${indent}${entry.name}${desc}${here}`);

    if (entry.subentries && entry.subentries.length) {
        entry.subentries.forEach(e => printTOC(e, depth+1));
    }
}

// Main entry point: start the shell interface
boot();
