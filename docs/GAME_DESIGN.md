# Dungeon Brawler Garl: One-Page Design

*This is a fan homage and open-source learning project. All names, characters and text here are original. No text, art or characters are taken from the source books.*

## Pitch
Earth has been "acquired" by a galactic media company. Everyone who's left is pushed into a giant dungeon that's broadcast live to bored aliens across the galaxy. You play **Garl**, an unlucky alien tourist who got stuck in the dungeon. He's wearing polka-dot boxers, one sock, and a borrowed bomber jacket. His partner is **Duchess Pumpernickel III**, a pampered prize-winning show skunk who expects to be worshipped. You go down floor by floor, try to stay alive, and play to the cameras.

## Cast (stand-in names)
| Role | Character | Notes |
|---|---|---|
| Hero | **Garl** | Short, blue, three-fingered alien. Brawler who fights with his bare hands and kicks. Refuses to wear pants on principle. |
| Companion | **Duchess Pumpernickel III** | Show skunk with a tiara. Uses ranged "Royal Spray" magic and gives dramatic commentary. |
| Announcer | **H.O.S.T.** (Hostile Operations & Spectator Television) | The dungeon AI. Passive-aggressive, cheerful and petty. Announces achievements with sarcasm. |
| Guide | **Mortimer** | Grumpy ex-contestant toad who runs the safe-room bar between floors. |
| Pet | **Nugget** | A baby fire-salamander that hatches from a loot box and grows each floor. |
| Villain | **Glorbcorp Entertainment** | The network running the show. Shown through ads, sponsor messages and "terms of service" pop-ups. |
| Show | **Delve Live!** | The broadcast. The viewer count is a game mechanic. |

## Core loop
1. **Drop into a floor**: a procedurally generated 3D dungeon seen from an angled top-down camera with a **collapse timer** counting down.
2. **Explore and fight**: real-time combat. Garl punches and Duchess casts spells.
3. **Open loot boxes**: Bronze, Silver, Gold and "Legendary (Allegedly)". They hold gear, consumables and joke items.
4. **Earn achievements**: H.O.S.T. narrates them ("Achievement: Stepped On It. You found the trap by being the trap.").
5. **Play to the audience**: flashy kills raise **Viewers**. High viewership brings **sponsor drops** (offers you can take, with strings attached).
6. **Find the stairs before the timer ends**, rest in the safe room (shop, Mortimer, upgrade skills), then go down again.

## Tech
- **Engine:** Godot 4 (GDScript), low-poly 3D with a fixed isometric-style camera.
- **License:** Apache 2.0 for code. Placeholder art from CC0 3D packs (e.g. KayKit Dungeon, Kenney, Quaternius) until we have our own.
- **Builds:** Web (HTML5) and desktop, published on itch.io.

## Milestones
1. **Repo and skeleton**: Godot project, README, license, folder layout, a walkable test room.
2. **One-floor prototype**: movement, one enemy, combat, stairs, a Bronze loot box, the collapse timer.
3. **Flavor pass**: H.O.S.T. achievement pop-ups, Duchess as an AI companion, viewer meter, safe room.
4. **Polish and publish**: three floors, a title screen, an itch.io page.

## Out of scope for now
Multiplayer, story cutscenes, voice acting, and anything copied from the books.
