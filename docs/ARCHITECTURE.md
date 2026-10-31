# Architecture

## Folder layout

```
autoload/
  game_state.gd      Local profile (name, avatar, pet, house, catalog favorites and recents) saved to
                     user://profile.json; input map
  net.gd             ENet host/join (solo in the browser), connection status, return-to-menu
  thumbs.gd          Renders small pictures of models for buttons and catalog cards (see "UI")
assets/ui/
  fonts/             Fredoka (headings) and Nunito (text), variable fonts, SIL Open Font License
  icons/             Fluent Emoji pictures as 128 px PNGs (MIT)
scenes/
  main_menu.tscn     Character creator + play buttons (scripts/ui/main_menu.gd)
  world.tscn         The neighborhood (scripts/world/world.gd)
itHappy/             Licensed models, cloned from the private madison-game-art repo (git-ignored; see "Art")
scripts/
  avatar/avatar_builder.gd    Avatar config → 3D model (all styling options live here)
  pets/pet_builder.gd         Pet config → 3D model (coats use the licensed animal models)
  pets/pet.gd                 Follow behavior, needs, emotes, walk/run/idle animations
  house/furniture_catalog.gd  Buildable items: footprints, styles (licensed models) and shape fallbacks
  house/house.gd              A plot: grid layout, place/remove, validation
  house/build_controller.gd   Mouse-driven build mode with ghost preview
  player/player.gd            Movement, camera, animation, network sync
  ui/ui_theme.gd              The shared look: palette, fonts, Theme, and button/card/label helpers
  ui/item_grid.gd             Paged grid of picture cards with favorite stars
  ui/catalog_browser.gd       Category rail + group chips + search + Favorites/Recent around an ItemGrid
  ui/swatch_row.gd            Color swatches plus a rainbow button for any color
  ui/main_menu.gd             Character creator, pet picker, name picker and play buttons
  ui/hud.gd                   In-world UI: player and pet cards, dock, chat, dialogs, build drawer
  world/scenery.gd            Ground, roads, plaza, trees, bushes and flowers
  util/safe_names.gd          Word lists for names, pet names and chat phrases
  util/mesh_util.gd           Primitive-mesh helpers
  util/lighting.gd            Shared sky, sunlight and color grading (world and menu preview)
  util/art.gd                 Loads licensed models from itHappy/, or returns null when they're missing
  dev/                        Smoke test, screenshot helpers, and prune_art.gd for the web build
```

## Data model

Everything a player owns is a small JSON-friendly Dictionary of option indices and hex colors:

- `avatar`: e.g. `{"hair": 5, "hair_color": "e26fb0", "eyes": 3, "top": 2, ...}`
- `pet`: `{"species": 1, "coat": 2, "name": "Mochi", "color": "...", "accent": "...", "collar": "..."}`
- `house`: list of `{"id": "sofa", "x": 4, "z": 6, "r": 1, "c": "e07a5f", "s": 3}` on a 12×12 grid
  (`r` quarter turns, `c` paint color for shape-built items, `s` style for items with models; big
  items like beds and sofas cover two cells)
- `name_parts`: `{"adjective": 3, "noun": 7, "number": 42}` → "CozyKoala42"

Adding a new hat, hairstyle or furniture piece is one entry in an options list plus a few lines that
build its shape. Builders also have a `sanitize()` that clamps any config to valid values.

## UI

All screens are built in code from the helpers in `scripts/ui/ui_theme.gd`, so they share one look.
`UiTheme.theme()` returns one Theme with named type variations (`PrimaryButton`, `TabButton`,
`CardButton`, `ChipButton`, `Card`, `Heading`, `Hint`, `KeyBadge` and so on); a control picks one with
`theme_type_variation`, and helpers like `UiTheme.button(text, icon, variation)` or
`UiTheme.icon_button(icon, tooltip, size, key)` set it for you. Colors live in the palette constants
at the top of that file. Rules of thumb for a kids' game: buttons at least about 48 px tall, a picture
on every button, short words, and a key badge on any button that also has a keyboard key.

**Icons** are named after their Fluent Emoji file, for example `UiTheme.icon("house")`
(`assets/ui/icons/house.png`); an unknown name falls back to a sparkle. To add one, drop in a 128 px PNG
of the "Color" style (the SVGs use filters Godot can't draw, so they're rasterized first), then run
`godot --headless --path . --import` once, because `*.import` files are not committed.

**Thumbnails.** `Thumbs.texture(key, build, view)` returns a Texture2D at once and fills it in a
frame or two later: `build` is a Callable that returns a fresh Node3D, which is rendered in a small
off-screen SubViewport with an orthographic camera fitted to its bounds. `view` picks the angle
(`item`, `face`, `head`, `torso`, `legs`, `feet`, `back`, `pet`, `portrait`). Newest requests render
first, so flipping pages quickly never waits on pages already gone. Pass `disk = true` for the licensed
models; those pictures are cached in `user://thumbs/` (bump `DISK_VERSION` when the renders change).
Keys must change whenever what they show changes, so avatar pictures include a hash of the config.

**Big catalogs.** `ItemGrid` only builds cards for the page on screen and asks for their pictures when
the page is shown, so 20 items or 2,000 cost the same. `CatalogBrowser` wraps it with category tabs
(`{id, name, icon}`), group chips and search over entries `{key, name, category, group, thumb, tags}`.
Build mode lists every furniture style as its own entry (`FurnitureCatalog.entries()`, key `"id:style"`),
and new furniture just needs a `category` from `FurnitureCatalog.CATEGORIES`. Walls, floors and fences
have no category: they belong to the ready-built house, so players can't place or remove them. Favorites and recents are
stored in the profile by key, are local only, and skip keys that no longer exist. As a stress test,
`--shot-ui=stress` loads all 818 Bright Furniture prefabs into the build catalog: setup takes about
30 ms and a page of pictures about 2 seconds the first time.

**Character creator.** The tabs come from `AvatarBuilder.tabs()`: a list of
`{title, icon, view, rows: [{label, key, icon?, view?, colors?}]}`. A row whose key has options becomes
a picture grid (`AvatarBuilder.options(key)`), a row with `colors` becomes a swatch row, and `height` is
a slider. `view` (a row's own, else its tab's) sets both the thumbnail angle and where the preview
camera zooms.
`AvatarBuilder.face_height(config)` tells the camera where the face is.

## Art

The furniture, pets and trees come from three paid ithappy packs (Bright Furniture, Animals, Cute
Characters). Their license forbids sharing the raw files, and this repo is public, so they live in the
private `AllisonEJohnson/madison-game-art` repo and are cloned into `itHappy/`, which git ignores:

```sh
git clone https://github.com/AllisonEJohnson/madison-game-art.git itHappy
```

The pack scenes refer to `res://itHappy/...`, so the folder name matters. Code asks `Art.instance()`
for a model and falls back to its simple shape version when that returns null, so the game still runs
without the art (for example in a fork). Every model the game uses is listed in an `art_paths()`
function (furniture catalog, pet builder, scenery). The web build checks out the art with the
`ART_REPO_TOKEN` Actions secret, and `scripts/dev/prune_art.gd` deletes everything those lists don't
need before export, which keeps the download small. A wrong path in a list fails that step.

## Networking

Listen-server model with Godot's high-level multiplayer API:

1. The menu picks Host or Join and loads the world scene first; the world then calls `Net.start()`.
   This guarantees the scene tree exists before any replication arrives.
2. A client sends its public profile to the host with an RPC. The host sanitizes it, assigns a free plot,
   and spawns the player through a `MultiplayerSpawner` with a custom spawn function, so every peer
   builds the same avatar, pet and house from the same data.
3. Each player node has authority set to its owner. A `MultiplayerSynchronizer` replicates position and
   facing (20 times a second) and other peers smooth toward it.
4. Pets are not networked: each peer runs the same follow logic from the owner's synced position.
   Feeding and playing are sent as small "reaction" RPCs so everyone sees the emote.
5. House edits are applied locally right away, then sent to the host (debounced), which validates and
   broadcasts the layout. Late joiners receive the latest layouts on arrival.

The host is the only authority for anything shared, and it re-validates every message.

### Browser build

The web export (single-threaded, so GitHub Pages needs no special headers) can't use ENet, because
browsers can't open UDP sockets. `Net.online_available` is false there: the menu hides host/join, and
`Net.start()` runs the world on an `OfflineMultiplayerPeer`, which acts as a server with no peers, so the
same spawn and RPC code runs solo. Online play in the browser would need `WebSocketMultiplayerPeer` or
`WebRTCMultiplayerPeer` plus a hosted server, which fits the dedicated-server roadmap item below.

## Kid safety

- **No free text between players.** Display names are built from two word lists plus a number.
  Pet names come from a list. Chat is a menu of friendly preset phrases.
- **Only indices travel over the network** for names and chat, and the host checks each index is valid,
  so a modified client cannot inject text.
- **Chat is rate limited** on the host (one phrase per second per player).
- **No personal data** is collected or shared. Profiles live only on the player's own device.
- **Next steps before a public launch**: a parent/guardian gate for online play, private worlds
  (friend codes) as the default, block/mute and report buttons, a dedicated server run by you rather than
  player hosting (players hosting exposes IP addresses to each other), and a review against
  COPPA (US) / GDPR-K (EU) requirements.

## Roadmap ideas

1. Dedicated headless server + account system + cloud saves.
2. Change outfits in-world (wardrobe in your house), and visiting other homes with permissions.
3. Pet tricks, pet beds that pets actually use, more species.
4. Real art: swap the primitive builders for imported `.glb` models, keeping the same config format.
5. Furniture catalog with unlockable items earned from mini-games.
