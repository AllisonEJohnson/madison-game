# Architecture

## Folder layout

```
autoload/
  game_state.gd      Local profile (name, avatar, pet, house, catalog favorites and recents, wallet,
                     things bought and membership) saved to user://profile.json; input map
  net.gd             ENet host/join (solo in the browser), connection status, return-to-menu
  thumbs.gd          Renders small pictures of models for buttons and catalog cards (see "UI")
assets/
  kaykit_forest/     Trees, bushes, rocks and grass from the free KayKit Forest pack (CC0; see "Art")
  ui/fonts/          Fredoka (headings) and Nunito (text), variable fonts, SIL Open Font License
  ui/icons/          Fluent Emoji pictures as 128 px PNGs (MIT)
scenes/
  main_menu.tscn     Character creator + play buttons (scripts/ui/main_menu.gd)
  world.tscn         The neighborhood (scripts/world/world.gd)
itHappy/             Licensed models, cloned from the private madison-game-art repo (git-ignored; see "Art")
scripts/
  avatar/avatar_builder.gd    Avatar config → 3D model; the creator's tabs and options; shape avatar
  avatar/character_parts.gd   The licensed Cute Characters parts, costumes and animations
  avatar/part_colors.gd       Generated main color of each recolorable part (dev/part_colors.gd)
  avatar/tint.gdshader        Recolors one color of a part, for hair, clothes and skin colors
  pets/pet_builder.gd         Pet config → 3D model (coats use the licensed animal models)
  pets/pet.gd                 Follow behavior, needs, emotes, walk/run/idle animations
  house/furniture_catalog.gd  Buildable items: footprints, styles (licensed models) and shape fallbacks
  house/house.gd              A plot: grid layout, place/remove, validation
  house/build_controller.gd   Mouse-driven build mode with ghost preview
  player/player.gd            Movement, camera, animation, network sync
  ui/ui_theme.gd              The shared look: palette, fonts, Theme, and button/card/label helpers
  shop/shop_catalog.gd        Prices: what each look of furniture and each piece of clothing costs, and in which currency
  ui/item_grid.gd             Paged grid of picture cards with favorite stars and price tags
  ui/catalog_browser.gd       Category rail + group chips + search + Favorites/Recent around an ItemGrid
  ui/swatch_row.gd            Color swatches plus a rainbow button for any color
  ui/main_menu.gd             Character creator, pet picker, name picker and play buttons
  ui/hud.gd                   In-world UI: player and pet cards (with wallet), dock, chat, dialogs, build drawer,
                              shop, the "press E" prompt and Star Chase's banner and result
  ui/shop_panel.gd            The shop window: Home and Clothes sections around a CatalogBrowser
  ui/buy_card.gd              One item up close with its price and a Buy button (shop and creator)
  ui/admin_console.gd         Maker-only command box (` key) that grants currency and membership
  world/scenery.gd            Town ground, roads, plaza, trees, bushes, rocks, grass and flowers
  world/fantasy_land.gd       Starfall Glade, the fantasy land
  world/portal.gd             Walk-in portal between lands
  world/acorn_pickups.gd      Acorns to pick up around a land, the simplest way to earn
  world/star_chase.gd         Star Chase, the catch-the-falling-stars game in Starfall Glade
  world/interact_zone.gd      A spot that offers something to do ("Press E") when you stand in it
  world/shop_stall.gd         The town's shop stall
  util/safe_names.gd          Word lists for names, pet names and chat phrases
  util/mesh_util.gd           Primitive-mesh helpers
  util/lighting.gd            Shared sky, sunlight and color grading (world and menu preview)
  util/art.gd                 Loads licensed models from itHappy/, or returns null when they're missing
  dev/                        Smoke test, screenshot helpers, and prune_art.gd for the web build
```

## Data model

Everything a player owns is a small JSON-friendly Dictionary of option indices and hex colors:

- `avatar`: e.g. `{"hair": 5, "hair_color": "e26fb0", "face": 3, "top": 2, "top_color": "", ...}`
  (`""` keeps a part's own colors). Art and shape avatars have different choices, so the creator
  builds its tabs from `AvatarBuilder.tabs()` and `options(key)`.
- `pet`: `{"species": 1, "coat": 2, "name": "Mochi", "color": "...", "accent": "...", "collar": "..."}`
- `house`: list of `{"id": "sofa", "x": 4, "z": 6, "r": 1, "c": "e07a5f", "s": 3}` on a 12×12 grid
  (`r` quarter turns, `c` paint color for shape-built items, `s` style for items with models; big
  items like beds and sofas cover two cells)
- `name_parts`: `{"adjective": 3, "noun": 7, "number": 42}` → "CozyKoala42"
- `owned`: shop keys of everything bought, like `"furniture:sofa:3"` and `"avatar:hat:20"`

Adding a hat or hairstyle from the character pack is one entry in a `CharacterParts` list; a new
furniture piece is one `FurnitureCatalog` entry. Builders also have a `sanitize()` that clamps any config to valid values.

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
`{title, icon, view, rows: [{label, key, icon?, view?, colors?, original?}]}`. A row whose key has options
becomes a picture grid (`AvatarBuilder.options(key)`), a row with `colors` becomes a swatch row (with an
"Original" chip that picks `""` when `original` is set), and `height` is a slider. `view` (a row's own,
else its tab's) sets both the thumbnail angle and where the preview camera zooms.
`AvatarBuilder.face_height(config)` tells the camera where the face is, and `view_zoom(view)` backs it off
for the art avatar's bigger head. Half of an art avatar's height is its head, so the general framing
rules in `Thumbs` would miss; instead the avatar carries a `thumb_boxes` meta (view to AABB) that says
where its face, head, torso, legs and feet are, and any model can do the same.

## Art

The grass comes from the free KayKit Forest Nature Pack (CC0), so those models are committed in
`assets/kaykit_forest` with the pack's license; its trees, bushes and rocks stand in when the licensed
art is missing. Only the files the game uses are kept. `Scenery` draws the grass as one
`MultiMeshInstance3D` per tuft shape, so 1,500 tufts cost eight draw calls.

The avatars, furniture, pets, flowers, the town's trees, bushes and stones, and all of Starfall Glade come
from four paid ithappy packs (Cute Characters, Bright Furniture, Animals, Fantasy). Their license forbids sharing the raw files, and this repo is public, so they live in the
private `AllisonEJohnson/madison-game-art` repo and are cloned into `itHappy/`, which git ignores:

```sh
git clone https://github.com/AllisonEJohnson/madison-game-art.git itHappy
```

The pack scenes refer to `res://itHappy/...`, so the folder name matters. Code asks `Art.instance()`
for a model and falls back to its simple shape version when that returns null, so the game still runs
without the art (for example in a fork). Every model the game uses is listed in an `art_paths()`
function (avatar builder, furniture catalog, pet builder, scenery, fantasy land). The web build checks out the art
with the `ART_REPO_TOKEN` Actions secret, and `scripts/dev/prune_art.gd` deletes everything those lists
don't need before export, which keeps the download small. It also drops the character animations the
game doesn't play. A wrong path in a list fails that step.

An art avatar is the pack's skeleton with one skinned mesh per part (body, face, hair, clothes...).
The pack paints every part from one palette texture, so colors work by recoloring: `part_colors.gd`
records each part's main color (generate it with `scripts/dev/part_colors.gd`), and `tint.gdshader`
swaps that color for the player's pick while leaving stripes and buttons alone. Skin works the same
way on a single body model, so any skin color is possible.

## Lands

The town and Starfall Glade are two parts of the one world scene: the glade sits 600 m east of the town
(`World.GLADE_ORIGIN`), out of sight. A portal in each land moves the local player to the other one's
arrival spot, and everyone else sees the move through normal position syncing, so lands need no extra
networking. The world watches which land the local player is in, switches the sky and sunlight to that
land's look (`Lighting.LANDS`) and hides the other land so it costs nothing to draw. Its colliders stay,
so remote players and pets there still stand on solid ground. More lands can be added the same way at
other offsets.

The Fantasy pack's own water shader reads the depth buffer, which browsers handle poorly, so the glade's
pond uses a small shader of its own.

## Wallet and membership

`GameState` keeps two currencies, **Acorns** (earned by playing) and **Stardust** (premium, bought with
real money once payments exist), plus `member_until`, the Unix time a membership runs out. `grant()`,
`spend()`, `grant_membership()` and `is_member()` are the only ways in, and every change emits
`wallet_changed`, which the HUD listens to. For now the wallet lives in the device's save, and only the
admin console (debug builds or `--admin`) grants Stardust and membership. Before real purchases go live,
wallets must move to the game server, which would grant Stardust only after a verified payment receipt;
a saved file on a player's device can be edited, so it can't be trusted with anything bought.

## Earning and the shop

**Prices.** `ShopCatalog` holds every price as a few rules rather than a list of hundreds of items. Each
furniture piece and each kind of clothing has an Acorn price, a `free` count (the first looks of a piece,
or the first choices of a kind, cost nothing) and a short `stardust` list of special looks that cost
Stardust instead. Everything else in the creator (faces, body, skin, eyes and every color) is free. An
item is named by a shop key, `"furniture:<id>:<style>"` or `"avatar:<option>:<index>"`, and
`ShopCatalog.price(key)` returns `{currency, amount}`, or nothing when it's free. Looks used by the starter
home and the default character are always free.

**Owning.** `GameState.profile["owned"]` lists the keys bought. `GameState.buy(key)` checks the price,
spends it and adds the key; `owns(key)` is true for free things too. A save from before the shop keeps
whatever it already had placed or was wearing (`ShopCatalog.priced_keys_in`), so no one loses anything.
Build mode only places owned looks (others show a Buy button), and the creator lets you try on anything
but only keep what you own, with a "Get this?" card for the rest.

**Earning.** Acorns come from playing:

- `AcornPickups` keeps about ten acorns floating at open spots in a land (5 Acorns, or 25 for the odd
  golden one) and regrows each one somewhere else after 15 to 35 seconds. The town and the glade each
  have their own.
- `StarChase` is a 45-second game on the ring by the glade's portal: catch falling stars for 3 Acorns
  each, plus 15 more for catching ten. An arrow over your head points to the next star, and the best
  score is kept in the profile.

Both run only on the player's own device and pay through `GameState.earn()`, like the rest of the wallet,
and the HUD shows a "+5" by the wallet. Once wallets move to a server, the server should place acorns and
check catches before paying.

**The shop.** The shop stall in town and its twin in the glade's market are `InteractZone`s: standing
there shows "Press E" and opens `ShopPanel`, which also opens from the dock's Shop button or a click on
the wallet. Bought clothes are worn through `World.submit_avatar`, so everyone sees the new look. Things
that cost Stardust ask "Spend N Stardust?" before buying, so a stray tap can't spend real money.

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
6. A changed outfit is sent to the host the same way (`submit_avatar`), which sanitizes it, limits how
   often it changes, and rebuilds that player's avatar on every peer. Late joiners spawn with it.

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
5. More ways to earn: more mini-games, daily tasks and levels.
