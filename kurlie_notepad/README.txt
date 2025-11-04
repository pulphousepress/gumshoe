# Notebook

An interactive in-game notebook with page-flipping, handwriting fonts, and autosave.

---

## ✍️ Adding More Handwriting Fonts

1. **Add to Google Import (style.css, line 1)**  
   Example:

   ```css
   @import url('https://fonts.googleapis.com/css2?family=Gloria+Hallelujah&family=Patrick+Hand&family=Indie+Flower&family=Reenie+Beanie&family=Rock+Salt&family=Allison&display=swap');

Append new fonts to this list from Google Fonts
.

Add a CSS class (style.css)
Example for a new font:

.handwriting7 { font-family: 'Shadows Into Light', cursive; }


Add to the dropdown (index.html)
Example:

<option value="handwriting7">Shadows Into Light</option>


The value must match the CSS class name.

📖 Changing Page Amount

Open script.js and change line 3:

let totalPages = 20;


Replace 20 with however many pages you want.

Each “turn” displays two pages (left & right).

The system handles overflow and will push extra text into the next page automatically.

💾 Saving & Autosave

Manual save: Click Save or close the notebook.

Autosave: Text is automatically saved 2 seconds after you stop typing.

Pages also save when flipping forward/backward.

Saved data includes:

Current page number

Page contents

Note ID (to distinguish multiple notes)

🎶 Page Flip Sound

The flip sound is loaded from flip.mp3.

Make sure flip.mp3 is in the same directory as your HTML.

⚙️ Key Features

Multiple handwriting fonts, easily extendable.

Realistic two-page book layout with flip animations.

Overflow handling: typing too much on one page will spill into the next automatically.

Font picker lets you change handwriting styles on the fly.

Autosave keeps notes persistent without needing constant manual saves.

