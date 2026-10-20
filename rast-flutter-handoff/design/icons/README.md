# rast SVG icons

These 36 SVGs were extracted from the `paths` object in `prototype/dist/app.js`, source commit `de646b9263e4c6d31dea0c0aa76d946da775ab88`.

Most use a 24×24 viewBox; the intersecting-circle brand mark uses 26×24. Preserve the 1.6 stroke width, round caps/joins and semantic foreground color. Each file uses `currentColor`; supply the appropriate color when adapting to Flutter. Validate the chosen SVG rendering package against the target Flutter version, or recreate these simple vectors in native drawing code.

`mark.svg` is the brand symbol. The full rast wordmark in the source combines that symbol with styled Plus Jakarta Sans text and its coral dot. A standalone outlined wordmark was not created in this export. Phone/signal/battery icons include desktop-preview status-bar helpers; native apps should use the actual OS status bar.

