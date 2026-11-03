# Dungeon Brawler Garl

A pantsless alien, a diva show skunk, and a dungeon broadcast live to the galaxy. Punch your way down collapsing floors, open loot boxes, and earn sarcastic achievements.

An open-source, low-poly 3D roguelike built with [Godot 4](https://godotengine.org/). It's a learning-and-fun project.

> **Status:** early prototype. Punch goblins, open loot boxes, and find the stairs before the floor collapses.

## Play it

- **In your browser:** https://sinachavoshi.github.io/dungeon-brawler-garl/ (rebuilt on every merge to `main`).
- **On Windows:** open the latest [Build run](https://github.com/SinaChavoshi/dungeon-brawler-garl/actions/workflows/build.yml), download the `DungeonBrawlerGarl-windows` artifact, unzip it and run the `.exe`.

## Run it from source

1. Install **Godot 4.3** or newer (the standard build; you don't need the .NET build).
2. Clone this repo and open `project.godot` from the Godot project manager.
3. Press **F5** to play.

**Controls:** WASD or arrow keys to move, Space / J / right click to punch, left-drag to rotate the camera, mouse wheel to zoom, R to restart after dying.

## Project layout

```
project.godot      Godot project settings (GL Compatibility renderer, so web export works)
scenes/            .tscn scenes: main.tscn is the test room, player.tscn is Garl
scripts/           GDScript
assets/            models, textures, audio (CC0 or original only)
docs/              design notes. Start with docs/GAME_DESIGN.md
```

## Roadmap

1. **Repo and skeleton**: done.
2. **One-floor prototype**: an enemy, punching, stairs down, a Bronze loot box, the collapse timer.
3. **Flavor pass**: H.O.S.T. achievement pop-ups, Duchess as a companion, viewer meter, safe room.
4. **Polish and publish**: three floors, a title screen, web and desktop builds on itch.io.

See [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md) for the full pitch and cast.

## A note on inspiration

This is a fan homage inspired by dungeon-crawl LitRPG books. Every character, name, line of text and asset in this repo is original or CC0. Please don't contribute text, art or characters copied from any existing book or game.

## License

Code is licensed under the [Apache License 2.0](LICENSE). Third-party assets keep their own licenses, which are listed next to them in `assets/`.

## Credits

- Dungeon and skeleton models: [KayKit](https://www.kaylousberg.com) by Kay Lousberg (CC0).
