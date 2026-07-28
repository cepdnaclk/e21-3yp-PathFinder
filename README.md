# PathFinder Project Website

This folder contains the static GitHub Pages website for the PathFinder third-year engineering project. It is a single-page showcase built with HTML5, CSS3, vanilla JavaScript, and local SVG placeholders.

## Folder Structure

```text
docs/
|-- index.html
|-- css/
|   `-- style.css
|-- js/
|   `-- script.js
|-- images/
|   |-- placeholders/
|   `-- README.md
|-- assets/
|   `-- documents/
|       `-- README.md
`-- README.md
```

## Preview Locally

From the repository root:

```bash
python -m http.server 8000 --directory docs
```

Alternative:

```bash
cd docs
python -m http.server 8000
```

Then open:

```text
http://localhost:8000
```

## Replace Placeholders

All temporary images are in `docs/images/placeholders/`. Replace them with final project images when available. For example:

1. Replace `hero-device.svg` with `hero-device.webp`.
2. Update the matching `src` in `index.html`.
3. Keep image files inside `docs/images`.
4. Compress photographs before committing.
5. Prefer WebP for photographs and SVG or PNG for diagrams.

See `docs/images/README.md` for the full placeholder replacement table.

## Edit Content

Most editable areas are marked in `index.html` with comments beginning with `REPLACE:`. Update these after final verification:

- Device images and gallery photos
- Architecture and data-flow diagrams
- Team member and supervisor details
- Budget values
- Testing results
- Final timeline dates
- Application screenshots

## Deploy With GitHub Pages

1. Push the `docs` folder to the repository.
2. Open repository Settings.
3. Open Pages.
4. Select "Deploy from a branch".
5. Select `main`.
6. Select `/docs`.
7. Save.
8. Visit:

```text
https://cepdnaclk.github.io/e21-3yp-PathFinder/
```

## Troubleshooting

- If styles do not load, confirm `css/style.css` exists and the site is served from the `docs` folder.
- If images do not load, confirm the relative path in `index.html` matches the image filename.
- If GitHub Pages shows a 404, confirm the repository Pages source is set to `main` and `/docs`.
- If the mobile menu does not open, confirm `js/script.js` is present and browser JavaScript is enabled.
- If placeholders are replaced with large photos, compress them to avoid slow loading.
- The page remains readable without JavaScript, but the mobile menu, section reveal effects, lightbox, and back-to-top button require JavaScript.
