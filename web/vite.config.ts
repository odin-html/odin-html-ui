import { defineConfig } from 'vite'
import tailwindcss from '@tailwindcss/vite'
import devtools from 'vite-plugin-devtools-json';

// Paths Vite owns outright: its client and module graph (/@vite, /@id, /@fs),
// pre-bundled dependencies, and what a plugin mounts -- the devtools JSON
// below is served from under .well-known.
const VITE_OWNED = /^\/(?:@|node_modules\/|\.well-known\/)/

/* A file rather than a route, which here is the same question as which server
 * answers. The Odin application rendering the pages serves only routes it
 * renders, and anything with an extension can only be Vite's. That keeps this
 * from becoming a list of filenames to maintain as src/ grows.
 *
 * The assumption it rests on is that no application route has a dot in its
 * last segment; one that did would be proxied nowhere and 404 out of Vite
 * instead. */
const LOOKS_LIKE_A_FILE = /\.[^./]+$/

/* Which of the two servers answers a given request in development.
 *
 * Everything Vite cannot serve is forwarded to the Odin application server,
 * rather than the other way round, because only one side of this is
 * enumerable: Vite's namespaces and the files under src/ are, and an
 * application's routes are open-ended and grow. Listing them here would mean
 * editing this file every time a route is added; this way a new route just
 * works.
 *
 * Returning a string hands the request to Vite's own middlewares; returning
 * nothing lets it proxy. */
function servedByVite(url: string | undefined): string | undefined {
  const path = new URL(url ?? '/', 'http://localhost').pathname

  if (path === '/') return undefined // the application's index, not the Vite shell

  return VITE_OWNED.test(path) || LOOKS_LIKE_A_FILE.test(path) ? path : undefined
}

export default defineConfig({
  root: 'src',
  plugins: [
    tailwindcss(),
    devtools({ uuid: '0d524119-9ba4-42a8-99cb-cf4bf5b71bef' }),
  ],
  server: {
    proxy: {
      '/': {
        /* The Odin application server that renders the pages, on its default
         * port. 127.0.0.1 rather than localhost, and not interchangeable: an
         * Odin server bound to net.IP4_Loopback is not listening on ::1 --
         * which is what Node resolves localhost to first, and is where this
         * dev server itself binds. The mismatch shows up as ECONNREFUSED on
         * every proxied request. */
        target: 'http://127.0.0.1:8080',

        /* Deliberately no ws: true. Vite's HMR socket lives on this same
         * origin, and handing upgrades to the proxy takes it down with them.
         * An application that needs WebSockets wants its own narrower key
         * rather than this one. */

        // changeOrigin is left off so the backend sees Host: localhost:5173 --
        // which is the truthful origin once the browser is pointed here.

        bypass: (req) => servedByVite(req.url),
      },
    },
  },
  build: {
    /* Resolved against root, which is src -- so this is web/dist. The build
     * product is the assets/ directory this emits, which the application
     * serves at /assets (see ui/layout/document.odin). An index.html lands
     * beside it too, but that is the entry Vite builds from rather than
     * anything served -- the Odin side renders its own <head>. */
    outDir: '../dist',

    /* dist/ holds nothing but this build's output, so emptying it first is
     * what a rebuild means. Vite declines to empty an outDir outside the root
     * unless told to. */
    emptyOutDir: true,

    /* Vite's output names are content-hashed. The Odin side links them as
     * constants -- STYLESHEET and BUNDLE in ui/layout/document.odin -- and the
     * release build reads this manifest and passes the two names in as
     * -define, so the hash is knowable at compile time without anything being
     * knowable in advance.
     *
     * The hash is what makes the cache header honest. index-B7xK2m.css can be
     * immutable for a year because a rebuild that changes a byte changes the
     * name, and the page asking for it is rendered fresh every time. */
    manifest: true,
  },
})
