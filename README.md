# Hometown Pals

An original online 3D neighborhood game for kids, built with **Godot 4.7+** (GDScript).
Style your character, build and decorate your own home, and bring your pet everywhere.

![Character creator](docs/menu.png)
![Build mode catalog](docs/home.png)
![In the neighborhood](docs/world.png)

## Play in your browser

**https://allisonejohnson.github.io/madison-game/**

The browser version is rebuilt and published automatically every time `main` changes
(see [.github/workflows/web.yml](.github/workflows/web.yml)). It needs a keyboard and mouse, and it plays solo:
browsers can't use the network connection that online play needs, so playing with friends needs the
downloaded game below. Your character, pet and home are saved in the browser.

## Run it

1. Install [Godot 4.7 or newer](https://godotengine.org/download) (standard build, not .NET).
2. Open Godot, click **Import**, and pick this folder's `project.godot`.
3. Press **F5**. Style your character, then click **Play!** to start your own neighborhood.

To play together on one computer: in the editor use **Debug > Customize Run Instances**, enable 2 instances, and run.
Have one window click **Play!**, and in the other click **Play with friends** and Join `127.0.0.1`.
To play across a home network, the host shares their local IP address and allows UDP port 24680 through the firewall.

## Controls

Everything has a big on-screen button too, with its key shown in a small badge, and **Help** lists them all.

| Key | Action |
| --- | --- |
| WASD / arrows | Move |
| Space | Jump |
| Right mouse drag / wheel | Look around / zoom |
| F / G | Feed / play with your pet |
| T | Quick chat (preset phrases) |
| B | Build mode (left click place, right click or the wastebasket removes, R turn, E next look) |
| H | Go to your home |
| Esc | Close a window, then leave build mode, then ask before leaving the world |

## What's in the prototype

- **Kid-friendly UI**: one shared look (rounded cards, chunky buttons, color icons, two friendly fonts)
  with big tap targets and pictures instead of words wherever possible. Every option in the creator and
  every catalog item shows a rendered 3D picture of itself.
- **Build catalog made for big art packs**: category tabs, "All / Sofas / Lamps" chips, search,
  a Favorites tab (tap the star) and a Recently used tab, with paged picture cards. Only the visible page
  is built and its pictures render in the background (and are cached on disk), so it stays quick with
  the whole 800+ model furniture pack loaded.
- **Character creator** with live 3D preview: skin tone, height, body shape; 6 eye styles, eye color,
  5 eyebrow styles, 4 noses, 6 mouths, blush and freckles, 4 glasses styles; 10 hair styles with any color;
  5 tops, 4 bottoms, 3 shoes, each with its own colors; 9 hats and hair clips; backpacks, capes and wings.
  Every color has kid-friendly swatches plus a full color picker. "Surprise me" randomizes everything.
- **Pets**: cats and kittens, dogs and birds in 19 animated coats, plus a bunny and a dragon in any colors,
  each with a name. Pets follow you, walk and run, wander when you stand still, react when fed or played
  with, and have fullness and happiness that slowly drop.
- **Houses**: each player gets a 12×12 plot with a furnished starter house. Build mode places floors,
  walls, windows, doorways and fences in any color, and 18 kinds of furniture (beds, sofas, a fridge, a
  bathtub, an arcade machine and more), most in several styles. Homes save automatically.
- **Online play**: up to 8 players in one neighborhood using Godot's high-level multiplayer (ENet).
- **Kid safety**: no free-text chat or typed names. See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md#kid-safety).

Fonts are [Fredoka](https://fonts.google.com/specimen/Fredoka) and [Nunito](https://fonts.google.com/specimen/Nunito)
(SIL Open Font License) and icons are [Fluent Emoji](https://github.com/microsoft/fluentui-emoji) (MIT); their
licenses are next to them in `assets/ui/`.

Furniture, pets and trees use licensed models from a private repo (see
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md#art)). Without them the game still runs, using simple shapes.
To get them, clone that repo into an `itHappy` folder here before opening the project:

```sh
git clone https://github.com/AllisonEJohnson/madison-game-art.git itHappy
```

## Developer helpers

To build the browser version yourself, install the 4.7.2 export templates (Editor > Manage Export Templates),
then use **Project > Export > Web**, or from a terminal:

```sh
godot --headless --export-release "Web" build/web/index.html
python3 -m http.server -d build/web 8000   # then open http://localhost:8000
```

```sh
# Two-process multiplayer smoke test (prints what each peer sees)
godot --headless --path . -- --host --smoke-test &
godot --headless --path . -- --join=127.0.0.1 --smoke-test

# Screenshots of the menu, or of your home in build mode
godot --path . -- --screenshot=/tmp/menu.png
godot --path . -- --host --shot-build --screenshot=/tmp/home.png

# --shot-ui runs UI steps before the screenshot, for example a creator tab, a catalog
# category or search, or the whole furniture pack as a stress test (see scripts/dev/screenshot.gd)
godot --path . -- --shot-ui=tab:3 --screenshot=/tmp/clothes.png
godot --path . -- --host --shot-build --shot-ui=category:living --screenshot=/tmp/living.png
godot --path . -- --host --shot-build --shot-ui=stress --screenshot=/tmp/stress.png
```
