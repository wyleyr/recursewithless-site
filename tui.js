let TERM = null;
let BUF = null;
let LINE_BUFFER = "";
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

function getPath() {
    let node = CURRENT_NODE;
    let path = "/" + CURRENT_NODE.id;
    while (node && node.id != "root") {
        node = node.parentElement;
        if (node.id) {
            path = "/" + node.id + path;
        }
    }

    return path;
}

function prompt() {
    let path = getPath();
    return `rwlsh:${path}> `;
}

function boot() {
    // since JS is running, hide the static data:
    let data = document.getElementById("root");
    data.style.display = "none";
    
    // set up the "terminal":
    let root = document.getElementById("terminal");
    TERM = document.createElement("pre");
    root.appendChild(TERM);
    BUF = document.createElement("pre");
    BUF.textContent = prompt() + "█";
    root.appendChild(BUF);

    document.addEventListener('keyup', readKey);

    // greet the user
    motd();
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
        printLine("What node do you want to change to?");
        return;
    }

    let name = rest[0];
    let newNode = document.getElementById(name);
    if (newNode) {
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

function help(args) {
    const [cmd, ...rest] = args;
    if (!rest || !rest.length) {
        printLine("The following commands are available:");
        for (cmdName in COMMANDS) {
            printLine(" " + cmdName + COMMANDS[cmdName].help);
        }

        printLine("The following documents are available:");
        // TODO

        printLine("The following portals are available:");
        // TODO
    } 
    // TODO command specific help, 

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
            namedChildren[child.id] = child.dataset.tocd;
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
        for (name in contents) {
            print(name);
            if (contents[name]) {
                print(': ');
                print(contents[name]);
            }
            print('\n');
        }
    } else {
        printLine(`${cmd}: Sorry, I couldn't find node ${rest[0]}`);
    }
}

function motd() {
    printLine("Welcome to recursewithless.net!\n");
    printLine("I am rwl, a rather wearisome loop.");
    printLine("I will do my best to assist you.")
    //printLine("Type command and press Enter to run it.");
}

function who(args) {
    let addr = document.getElementById("author");
    printLine(addr.textContent);
}

const COMMANDS = {
    cat: { impl: cat, help: ` DOC: display DOC here`, aliases: ['type', 'print']},
    cn: { impl: cn, help: ` NAME: change to node NAME`, aliases: ['cd']},
    cls: { impl: cls, help: `: clear screen`, aliases: [] },
    echo: { impl: echo, help: ` ARGS: display ARGS`, aliases: ['print']},
    ls: { impl: ls, help: ` [NAME]: list nodes here [or under NAME]`, aliases: ['dir']},
    help: { impl: help, help: ` [CMD]: display help [on CMD]`, aliases: ['?', '??']},
    open: {impl: browse, help: ` DOC/PORTAL: view DOC/PORTAL in a new tab`, aliases: ['browse', 'view']},
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
function notFound(s) {
    printLine(`Sorry, I don't understand ${s}. Try 'help'?`)
}


function sh(input) {
    if (!input || !input.length) return;
    
    let args = input.split(" ").filter(a => a != "");
    if (!args.length) return;
    
    let cmd = args[0].toLowerCase();
    let cmdStruct = findCommand(cmd);
    let docs = {}; //TODO
    let portals = {}; //TODO

    if (cmdStruct) {
        cmdStruct.impl(args);
    } else if (cmd in docs) {
        // implicitly display documents at the terminal:
        cat(['cat', ...args]);
    } else if (cmd in portals) {
        // implicitly open portals in a new tab:
        browse(['open', ...args]);
    } else { 
        notFound(cmd);
    }
}


boot();
