# Architecture

## Folder layout

```
autoload/
  game_state.gd      Local profile (name, avatar, pet, homes, catalog favorites and recents, wallet,
                     things bought, membership and level) saved to user://profile.json; input map
  progress.gd        The player's level: XP from playing, level-up rewards, locked places, Star Boost
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
  pets/pet_builder.gd         Every kind of pet (where it lives, its price, coats) and config → 3D model
  pets/pet.gd                 Follow behavior, needs, emotes, walk/run/idle animations
  pets/pet_collection.gd      Your pets: which kinds you have, the one with you, finding and buying more
  pets/wild_pets.gd           The wild pets of one land: who turns up where, and when
  pets/wild_pet.gd            One wild pet: wanders, looks at you, says hi, hops away after making friends
  pets/pet_keeper.gd          The world's side of pets: wild pets, making friends, switching pets online
  house/furniture_catalog.gd  Buildable items: footprints, styles (licensed models) and shape fallbacks
  house/home_catalog.gd       Every home and its rooms as data: plans, prices, capacity, save format
  house/home_shell.gd         Draws a home from its plan: the inside (no roofs) or the outside (roofs, shut doors)
  house/home_plot.gd          A lot in town with the outside of its player's home, the signpost and front doors
  house/homes.gd              The local player's homes: which they own, live in, and their furniture
  house/house.gd              A home's inside, built only while you're in it: furniture, place/remove, validation
  house/build_controller.gd   Mouse-driven build mode with ghost preview
  player/player.gd            Movement, camera, animation, network sync
  ui/ui_theme.gd              The shared look: palette, fonts, Theme, and button/card/label helpers
  shop/shop_catalog.gd        Prices: what each look of furniture and each piece of clothing costs, and in which currency
  progress/levels.gd          Level rules: the XP curve, what playing is worth, and what each level brings
  ui/item_grid.gd             Paged grid of picture cards with favorite stars and price tags
  ui/catalog_browser.gd       Category rail + group chips + search + Favorites/Recent around an ItemGrid
  ui/swatch_row.gd            Color swatches plus a rainbow button for any color
  ui/main_menu.gd             Character creator, pet picker, name picker and play buttons
  ui/hud.gd                   In-world UI: player and pet cards (with wallet), dock, chat, dialogs, build drawer,
                              shop, the "press E" prompt and Star Chase's banner and result
  ui/shop_panel.gd            The shop window: Home and Clothes sections around a CatalogBrowser
  ui/homes_panel.gd           The Homes window: homes to buy or move into, and rooms to add
  ui/buy_card.gd              One item up close with its price and a Buy button (shop and creator)
  ui/level_badge.gd           The star and XP bar on the player card
  ui/level_card.gd            Your level up close: progress, what's coming, ways to earn XP, Star Boost
  ui/level_up_card.gd         The level-up celebration, with confetti
  ui/admin_console.gd         Maker-only command box (` key) that grants currency, membership and XP
  ui/pets_panel.gd            My pets: every kind, yours and the wild ones, with Bring along and Get now
  ui/adopt_card.gd            Meeting a wild pet: name it, make friends, bring it along
  world/scenery.gd            Town ground, roads, plaza, trees, bushes, rocks, grass and flowers
  world/surfaces.gd           Materials for grass with worn paths, paved plazas and pools (see "The look")
  world/ground.gdshader       Painted grass with ragged dirt paths, all from position (no textures)
  world/paving.gdshader       Rings of paving stones for round plazas
  world/water.gdshader        Rippling water for the fountain and the glade's pond
  world/fantasy_land.gd       Starfall Glade, the fantasy land
  world/portal.gd             Walk-in portal between lands (locked until a level when its place needs one)
  world/sky_garden.gd         The Sky Garden, a floating island above Starfall Glade that opens at level 5
  world/acorn_pickups.gd      Acorns to pick up around a land, the simplest way to earn
  world/star_chase.gd         Star Chase, the catch-the-falling-stars game in Starfall Glade
  world/interact_zone.gd      A spot that offers something to do ("Press E") when you stand in it
  world/shop_stall.gd         The town's shop stall
  util/safe_names.gd          Word lists for names, pet names and chat phrases
  util/mesh_util.gd           Primitive-mesh helpers
  util/lighting.gd            Shared sky, sunlight and color grading (world, menu preview, item pictures)
  util/art.gd                 Loads licensed models from itHappy/, or returns null when they're missing
  dev/                        Smoke test, screenshot helpers (look_tour.gd for lighting work), and prune_art.gd
                              for the web build
```

## Data model

Everything a player owns is a small JSON-friendly Dictionary of option indices and hex colors:

- `avatar`: e.g. `{"hair": 5, "hair_color": "e26fb0", "face": 3, "top": 2, "top_color": "", ...}`
  (`""` keeps a part's own colors). Art and shape avatars have different choices, so the creator
  builds its tabs from `AvatarBuilder.tabs()` and `options(key)`.
- `pet`: the pet with you, `{"species": "fox", "coat": 0, "name": "Mochi", "color": "...", "accent": "...",
  "collar": "...", "fullness": 80.0, "happiness": 80.0}` (old saves stored a number for the species)
- `pets`: your other pets, waiting at home, by kind: `{"cat": {...same as pet...}}`
- `homes`: each home owned and its furniture, `{"sprout_cottage": [items], "oak_lookout": [items]}`, where an
  item is `{"id": "sofa", "x": 4, "z": 6, "r": 1, "c": "e07a5f", "s": 3}` on the plot's 12×12 grid
  (`r` quarter turns, `c` paint color for shape-built items, `s` style for items with models; big
  items like beds and sofas cover two cells). `home` is the one lived in. Rooms added are shop keys in
  `owned`. An old save's `house` list moves into the Sprout Cottage on load.
- `name_parts`: `{"adjective": 3, "noun": 7, "number": 42}` → "CozyKoala42"
- `owned`: shop keys of everything bought, like `"furniture:sofa:3"`, `"avatar:hat:20"`,
  `"home:oak_lookout:0"` and `"room:sprout_cottage:1"`

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

The **Sky Garden** is a flower-covered island floating 36 m above the glade's east side
(`World.SKY_GARDEN`), part of the glade's scene so it shows and hides with it. Its portal stands at the
castle door, where the glade's north path ends, and opens at level 5. Golden acorns grow there four times
as often as elsewhere. A fence and an invisible wall around the edge keep players from falling off.

The Fantasy pack's own water shader reads the depth buffer, which browsers handle poorly, so the glade's
pond (and the town fountain) use a small shader of their own, `world/water.gdshader`.

## The look

`Lighting` sets up every 3D view the same way, following the ithappy packs' own preview scenes:
filmic tone mapping, a warm sun, a fixed sky-blue ambient color for soft blue shade, light glow, and
the Fantasy pack's painted cloud sky (a plain gradient sky without the art). Each land picks its own
colors from `Lighting.LANDS`.

Browsers use the **Compatibility** renderer. For the same values it matches Forward+, except for one
engine bug (Godot issue 90259): a shadow-casting sun's light is added to the rest of the lighting after
both are converted to screen colors, which washes sunlit places out to almost white. `Lighting.sun()`
scales the sun by `COMPAT_SUN_SCALE` there, found by comparing the same views in both renderers.
Light taken from the sky (ambient source "sky") also differs between the renderers, so ambient light
is a fixed color.

The big flat surfaces use `Surfaces`: `ground.gdshader` paints grass with soft patches and fine
mottle, and wears paths into it from a list of strips and circles (they merge where they cross, with
ragged grassy edges); `paving.gdshader` lays rings of stones on round plazas. Both work from position,
so they cost nothing to download.

`prune_art.gd` also adjusts a few import settings for the web build (`IMPORT_SETTINGS`): the packs'
palette textures are kept lossless (compression added grain to their gradients, and lossless is
smaller), and the 4096 x 2048 sky is imported at 2048 x 1024, lossy.

To compare lighting changes, `scripts/dev/look_tour.gd` takes the same five views in one run, with
optional overrides (`--tour-set=env.tonemap_mode=2;sun.light_energy=1.2`). Run it once per renderer:

```sh
godot --path . -s scripts/dev/look_tour.gd -- --host --tour=/tmp/look --tour-tag=-desktop
godot --rendering-method gl_compatibility --path . -s scripts/dev/look_tour.gd -- --host --tour=/tmp/look --tour-tag=-web
```

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

## Levels and XP

There is one player level (no skill tracks). `Levels` (scripts/progress/levels.gd) holds the rules as
data, and the `Progress` autoload keeps the player's XP in `GameState.profile` and hands out rewards.

**XP.** Level 2 takes 50 XP and each level after that 25 more than the last (level 10 is 1,350 XP in all;
the top level is 50). Playing pays XP through `Progress.award(source)`, called from the same spots that pay
Acorns: an acorn 3 (golden 10), a Star Chase star 2, feeding or playing with your pet 4 (once a minute
each), making friends with a wild pet 40, putting something in your home 2 (20 times a day), the first visit
to a new place 40, and the first visit each day 25. Each source is one line in `Levels.SOURCES`, with an optional `cooldown` (seconds) or
`daily` cap; daily counts are saved with the date, cooldowns are not.

**Rewards.** Every new level pays `20 + 5 × level` Acorns, and many also bring something
(`Levels.rewards(level)`): a place (`Levels.AREAS`: Starfall Glade at 2, the Sky Garden at 5), new kinds of
things in the shop, or a gift from the shop (`Levels.GIFTS`, such as the Bunny costume at 5). Rewards are
given once: `rewarded_level` remembers the highest level paid, so going down a level (admin console) and
back up pays nothing twice. Reaching several levels at once shows one card with everything.

**Gated shop items.** A rule in `ShopCatalog.FURNITURE` or `CLOTHES` can have a `level`: its Acorn looks
can't be bought before then (sofas and hats at 2, costumes at 8, arcade machines at 9).
`ShopCatalog.level_needed(key)` returns it, `GameState.buy()` refuses earlier purchases, and price tags,
`BuyCard` and build mode show a padlock with the level instead of Buy. Stardust looks never need a level,
because premium is for getting ahead faster; it never buys levels or random prizes.

**Places.** A portal to a place that needs a higher level shows a padlock and "Opens at level N", and a
thin wall in its ring stops you; walking into it explains how to level up. Locks depend on the local
player's level, so each player sees their own.

**Star Boost.** 30 Stardust doubles XP for 30 minutes (buying more adds time, up to 4 hours). It's sold
from the level card with the same "tap again to be sure" as other Stardust purchases.

**On screen.** The player card shows a star with the level and an XP bar that fills as you play, with a
"+3 XP" over it. Tapping it opens the level card: progress, the next three levels that bring something,
the ways to earn XP and the Star Boost. A level-up shows a celebration card with confetti, as soon as no
other window is open and no Star Chase game is running.

Like the wallet, XP lives in the device's save for now; a game server should award XP and level rewards
before levels unlock anything bought with real money.

## Homes

Homes are ready-built: players never build walls, they pick a home, add rooms to it and fill it with
furniture. Everyone starts in the free **Sprout Cottage**, can own as many homes as they like, and lives in
one at a time; their plot shows that one, and each home keeps its own furniture, so moving back finds it
as it was left.

**Outside and inside.** Town only shows homes from outside. Each of the eight plots is a 22 × 22 m lot
(`HomePlot`) with the home toward the back, a front yard and a path to the street; it draws the home with
`HomeShell.exterior()`: closed walls, a gable roof over every room (canvas for tents, spotted for Toadstool
Hollow), shut doors and windows, and empty decks. No furniture or inside is ever built in town. A home's
**entrances** are its front doors (a room's door that opens onto the yard) and its deck gates
(`HomeCatalog.entrances()`). Walking into one builds that home's inside (`House`) out at
`World.HOMES_ORIGIN`, 1.5 km from town, one spot per plot 300 m apart, and moves you there through the
matching door; walking into an entrance from inside takes you back out to that door in town and frees the
inside again. While you're inside, both lands are hidden and only players in the same home are shown
(`World.place_at()`), so each home works like its own instance without any extra networking: everyone's
position still syncs as usual, and each peer builds only the inside it's in. Anyone can walk into anyone's
home and see it as its owner left it (live, as they decorate); only the owner can decorate. **Go home**,
**Decorate** and the Homes window's Move in all take you inside your own home.

**Homes as data.** `HomeCatalog.HOMES` describes each home: colors, wall height, how many things it holds,
decor (a tree, a campfire, giant mushrooms) and its rooms. A room is a rectangle on the 12×12 plot grid
with a `door` (an opening to the yard), `windows`, or a `link` (a doorway into the room next to it); a
`deck` room has railings instead of walls, and a `tent` room a canvas roof. Rooms with a `price` are
add-ons: `HomeCatalog.plan(type, rooms_built)` turns the rooms built into floors and wall edges (a wall
between two rooms gets a doorway, and a wall to a room not yet built stays a plain outside wall), and
`HomeShell.build()` draws its inside. A new home is one `HOMES` entry (with a `roof` color); `homes_test.gd`
checks every room is on the plot, nothing overlaps, there's a front door, every room can be walked to from
one, and the starter furniture fits inside the rooms.

| Home | Price | Rooms to add |
| --- | --- | --- |
| Sprout Cottage | free | Garden Room (300 Acorns, level 3), Bedroom (450, level 4), Playroom (30 Stardust) |
| Oak Lookout | 1,500 Acorns, level 6 | Lookout Deck (500, level 6), Loft Bedroom (700, level 7), Reading Nook (35 Stardust) |
| Sunpatch Safari Camp | 2,500 Acorns, level 9 | Sleeping Tent (600, level 9), Explorer Tent (800, level 10), Lookout Platform (40 Stardust) |
| Toadstool Hollow | 120 Stardust | Glow Garden (400, level 3), Spore Loft (40 Stardust) |

**Buying.** Homes and rooms are shop keys (`"home:<type>:0"`, `"room:<type>:<n>"`), so `ShopCatalog.price()`,
`level_needed()`, `GameState.buy()`, price tags and `BuyCard` work for them like for anything else. A room
can only be bought for a home you own. New homes and rooms show up on the level-up card of the level that
opens them.

**Room for things.** Furniture goes inside rooms (decks count), never on the lawn. A home holds `capacity`
things, and each room added holds more. Build mode shows "12 / 40 things" in its banner and says "Your home
is full! Add a room to fit more." when it is; swapping one piece for another still works. While
decorating, rooms you could add are drawn around the home as dashed outlines with their name and price, and
tall decor (the oak) hides so you can see in.

**On screen.** The **Homes** window (`HomesPanel`) opens from the dock, the decorating banner's Rooms
button, or the signpost by your own plot. Its Homes tab lists every home with a picture of it (yours as
you have it), and its Rooms tab the rooms of homes you own, each lit up in place. A home you own has
"Move in" (or "Go home" for the one you live in).

`Homes` (scripts/house/homes.gd) is the only code that reads or changes the saved homes; `HomeCatalog`,
`HomeShell`, `HomePlot` and `House` don't use autoloads, so the web build's art pruning can load them.

## Pets

`PetBuilder.SPECIES` lists every kind of pet as data: its name, coats (licensed models with a scale each),
sounds, a shape to build without the art, and for wild kinds the land it lives in (`land`), its Stardust
price (`stardust`, left out for kinds that can only be found) and whether it's `rare`. Configs and saves
name kinds by id (`"fox"`); saves from before used numbers, and the bunny and dragon (which had no models)
became a koala and a pegasus, so no one lost a pet.

**Having pets.** Cats, dogs and birds are everyone's from the start. The other 13 kinds live in the wild:
3 in town, 6 in Starfall Glade and 4 in the Sky Garden, so the glade's and the garden's open at levels 2 and
5 with their lands (the level-up card lists them). You have one pet of each kind; `PetCollection` keeps the
one with you in `profile["pet"]` and the rest in `profile["pets"]`, each with its own name, coat and needs,
and `switch_to()` swaps them.

**Wild pets.** `WildPets` keeps a few pets out in each land (2 in town, 3 in the glade, 2 in the garden) at
open spots, choosing kinds that live there; kinds you don't have turn up three times as often, rare ones a
third as often. A pet wanders near its spot, stops to look at you when you come close, and wears a "New!"
sparkle if you don't have its kind yet. Standing next to one offers "Say hi" (an `InteractZone`), which
opens `AdoptCard`: it suggests a name from the safe list (with a dice for another), and "Make friends!" adds
it to your pets, pays 40 XP and offers to bring it along. The wild pet then hops away, and another turns up
somewhere else a little later; pets nobody is near also wander off now and then so lands don't go stale.
Like acorns, wild pets exist only on the player's own device; a game server should check adoptions.

**My pets** (`PetsPanel`, the paw button on the pet card) shows every kind with filters for each land:
yours with Bring along, the rest with where they live (and the level their land opens at). 10 of the 13
wild kinds can also be had at once for Stardust (25 in town, 40 to 50 in the glade, 60 in the garden), with
the same second tap as other Stardust buys and, like other premium things, no level needed. The glimmer
cub, the honey bear and the pegasus can only be found. The character creator's Pet tab lists the same
kinds, so you can pick which pet comes along before you play.

Admin console: `pets all` and `pets reset`. Test: `--host --pets-test`.

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
   Feeding and playing are sent as small "reaction" RPCs so everyone sees the emote. Bringing a different
   pet along goes to the host like an outfit (`PetKeeper.submit_pet`), which sanitizes it and swaps that
   player's pet on every peer; late joiners get the latest pets when they connect.
5. House edits are applied locally right away, then sent to the host (debounced), which validates and
   broadcasts the home lived in: `{type, rooms, items}`. Moving home or adding a room sends it again. Late
   joiners receive everyone's homes on arrival. The host trusts the rooms a player says they have, like
   everything else bought, until wallets move to a server. Going inside a home needs no messages at all:
   it's a move to that home's spot far from town (see "Homes"), and far moves snap instead of gliding.
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
2. Change outfits in-world (wardrobe in your house); home visit settings (open to all, friends only or
   locked) and inviting friends into homes other than the one on your plot.
3. Pet tricks, pet beds that pets actually use, more wild pets (and lands for them), more than one pet of a kind.
4. Real art: swap the primitive builders for imported `.glb` models, keeping the same config format.
5. More ways to earn: more mini-games and daily tasks.
