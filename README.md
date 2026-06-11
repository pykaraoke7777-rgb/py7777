# P&Y 7777 Menu

Static menu site for Cloudflare Pages.

The PDF is rendered into lightweight JPEG pages. The site loads the first page immediately and lazy-loads the remaining pages as customers scroll.

This keeps first-load bandwidth much lower than opening the full PDF.

## Deploy On Cloudflare Pages

Cloudflare Pages serves the files inside `public/`.

1. Push this folder to a GitHub repository.
2. Open Cloudflare Dashboard -> Workers & Pages -> Create.
3. Choose `Pages` -> Connect to Git.
4. Select the repository.
5. Set:
   - Framework preset: `None`
   - Build command: leave empty
   - Build output directory: `public`
6. Deploy.

The `public/_headers` file keeps HTML fresh while caching menu page images for a long time.

## Regenerate Pages

```sh
swift scripts/render-pdf-pages.swift "/path/to/menu.pdf" public/pages 1100 0.72
```
