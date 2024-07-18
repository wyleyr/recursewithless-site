// auto-generate TOC data for each paragaph containing a cite element

function findParentParagraph(element) {
    if (element.tagName === "P") {
        return element;
    }
    return findParentParagraph(element.parentElement);
}

function addIDAndTocdFor(cite) {
    if (cite.hasAttribute("data-key")) {
        let parentP = findParentParagraph(cite);
        let id = cite.getAttribute("data-key");
        let tocd = cite.innerText.trim().replaceAll("\n", " ");
        parentP.setAttribute("id", id);
        parentP.setAttribute("data-tocd", tocd);
    }
    return;
}

let cites = document.getElementsByTagName("cite");
for (const cite of cites) {
    addIDAndTocdFor(cite);
}
