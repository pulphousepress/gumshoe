let pages = {};
let currentLeftPage = 1;
let totalPages = 20;
let saveTimeout;

window.addEventListener("message", function (event) {
    if (event.data.type === "openNotepad") {
        pages = event.data.pages || {};
        currentLeftPage = event.data.currentPage || 1;
        window.currentNoteId = event.data.noteId || "default";
        updateUI();
        document.body.style.display = "flex";
    }
});

function updateUI() {
    document.getElementById("notepadLeft").value = pages[currentLeftPage] || "";
    document.getElementById("notepadRight").value = pages[currentLeftPage + 1] || "";
    document.getElementById("label-left").innerText = "Page " + currentLeftPage;
    document.getElementById("label-right").innerText = "Page " + (currentLeftPage + 1);

    document.getElementById("arrow-left").style.display =
        currentLeftPage > 1 ? "block" : "none";
    document.getElementById("arrow-right").style.display =
        currentLeftPage + 1 < totalPages ? "block" : "none";
}

function nextPages() {
    playFlipSound();
    const right = document.getElementById("page-right");
    right.classList.add("flip-right");

    setTimeout(() => {
        pages[currentLeftPage] = document.getElementById("notepadLeft").value;
        pages[currentLeftPage + 1] = document.getElementById("notepadRight").value;
        if (currentLeftPage + 2 <= totalPages) {
            currentLeftPage += 2;
        }
        updateUI();
        right.classList.remove("flip-right");
    }, 700);
}

function prevPages() {
    playFlipSound();
    const left = document.getElementById("page-left");
    left.classList.add("flip-left");

    setTimeout(() => {
        pages[currentLeftPage] = document.getElementById("notepadLeft").value;
        pages[currentLeftPage + 1] = document.getElementById("notepadRight").value;
        if (currentLeftPage - 2 >= 1) {
            currentLeftPage -= 2;
        }
        updateUI();
        left.classList.remove("flip-left");
    }, 700);
}

function save() {
    pages[currentLeftPage] = document.getElementById("notepadLeft").value;
    pages[currentLeftPage + 1] = document.getElementById("notepadRight").value;
    fetch(`https://${GetParentResourceName()}/saveNotepad`, {
        method: "POST",
        body: JSON.stringify({
            pages: pages,
            currentPage: currentLeftPage,
            noteId: window.currentNoteId,
        }),
    });
    closePad();
}

function closePad() {
    fetch(`https://${GetParentResourceName()}/closeNotepad`, { method: "POST" });
    document.body.style.display = "none";
}

function playFlipSound() {
    const audio = document.getElementById("page-flip-sound");
    if (audio) {
        audio.currentTime = 0;
        audio.play();
    }
}

function changeFont() {
    const selected = document.getElementById("font-style").value;
    const left = document.getElementById("notepadLeft");
    const right = document.getElementById("notepadRight");

    left.className = left.className.replace(/handwriting\d+/g, "").trim();
    right.className = right.className.replace(/handwriting\d+/g, "").trim();

    left.classList.add(selected);
    right.classList.add(selected);
}

/* =====================
   Overflow Handling
   ===================== */

function preventTypingOnOverflow(textarea, isLeftPage) {
    textarea.addEventListener("input", function () {
        if (textarea.scrollHeight > textarea.clientHeight) {
            let overflowText = "";

            while (textarea.scrollHeight > textarea.clientHeight) {
                overflowText = textarea.value.slice(-1) + overflowText;
                textarea.value = textarea.value.slice(0, -1);
            }

            moveOverflowToNextPage(overflowText, isLeftPage);
        }

        // queue autosave
        queueSave();
    });

    textarea.addEventListener("paste", function (e) {
        e.preventDefault();
        const pasteText =
            (e.clipboardData || window.clipboardData).getData("text") || "";
        textarea.value += pasteText;
        textarea.dispatchEvent(new Event("input"));
    });
}

function moveOverflowToNextPage(text, isLeftPage) {
    const currentTextarea = isLeftPage
        ? document.getElementById("notepadLeft")
        : document.getElementById("notepadRight");
    const nextTextarea = isLeftPage
        ? document.getElementById("notepadRight")
        : document.getElementById("notepadLeft");
    const currentPageNum = isLeftPage ? currentLeftPage : currentLeftPage + 1;

    pages[currentPageNum] = currentTextarea.value;

    if (isLeftPage && currentLeftPage + 1 <= totalPages) {
        nextTextarea.focus();
        nextTextarea.value = text + nextTextarea.value;
        nextTextarea.setSelectionRange(text.length, text.length);
    } else if (!isLeftPage && currentLeftPage + 2 <= totalPages) {
        nextPages();
        setTimeout(() => {
            const leftTextarea = document.getElementById("notepadLeft");
            leftTextarea.focus();
            leftTextarea.value = text + leftTextarea.value;
            leftTextarea.setSelectionRange(text.length, text.length);
        }, 750);
    }
}

/* =====================
   Autosave (Optional)
   ===================== */

function queueSave() {
    clearTimeout(saveTimeout);
    saveTimeout = setTimeout(() => {
        pages[currentLeftPage] = document.getElementById("notepadLeft").value;
        pages[currentLeftPage + 1] = document.getElementById("notepadRight").value;
        fetch(`https://${GetParentResourceName()}/saveNotepad`, {
            method: "POST",
            body: JSON.stringify({
                pages: pages,
                currentPage: currentLeftPage,
                noteId: window.currentNoteId,
            }),
        });
    }, 2000);
}

/* =====================
   Initialize once
   ===================== */

window.addEventListener("DOMContentLoaded", () => {
    preventTypingOnOverflow(document.getElementById("notepadLeft"), true);
    preventTypingOnOverflow(document.getElementById("notepadRight"), false);
});
