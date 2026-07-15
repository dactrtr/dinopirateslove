# Graph Report - .  (2026-07-15)

## Corpus Check
- 361 files · ~223,720 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1477 nodes · 1591 edges · 117 communities (112 shown, 5 thin omitted)
- Extraction: 96% EXTRACTED · 4% INFERRED · 0% AMBIGUOUS · INFERRED: 67 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_CrewMember AI|CrewMember AI]]
- [[_COMMUNITY_Player State & Effects|Player State & Effects]]
- [[_COMMUNITY_Enemy AI Core|Enemy AI Core]]
- [[_COMMUNITY_Cockpit UI|Cockpit UI]]
- [[_COMMUNITY_Maze Scene & Player Data|Maze Scene & Player Data]]
- [[_COMMUNITY_Achievement Toasts|Achievement Toasts]]
- [[_COMMUNITY_Dance Battle Concepts|Dance Battle Concepts]]
- [[_COMMUNITY_CrewMember Docs|CrewMember Docs]]
- [[_COMMUNITY_Brocorat Enemy|Brocorat Enemy]]
- [[_COMMUNITY_Room 23 LDtk Data|Room 23 LDtk Data]]
- [[_COMMUNITY_Room 2 LDtk Data|Room 2 LDtk Data]]
- [[_COMMUNITY_Room 3 LDtk Data|Room 3 LDtk Data]]
- [[_COMMUNITY_Room 8 LDtk Data|Room 8 LDtk Data]]
- [[_COMMUNITY_Achievements & Comics|Achievements & Comics]]
- [[_COMMUNITY_Room 12 LDtk Data|Room 12 LDtk Data]]
- [[_COMMUNITY_Room 22 LDtk Data|Room 22 LDtk Data]]
- [[_COMMUNITY_Room 10 LDtk Data|Room 10 LDtk Data]]
- [[_COMMUNITY_Room 4 LDtk Data|Room 4 LDtk Data]]
- [[_COMMUNITY_Room 7 LDtk Data|Room 7 LDtk Data]]
- [[_COMMUNITY_Room 11 LDtk Data|Room 11 LDtk Data]]
- [[_COMMUNITY_Room 14 LDtk Data|Room 14 LDtk Data]]
- [[_COMMUNITY_Room 6 LDtk Data|Room 6 LDtk Data]]
- [[_COMMUNITY_Room 13 LDtk Data|Room 13 LDtk Data]]
- [[_COMMUNITY_Room 15 LDtk Data|Room 15 LDtk Data]]
- [[_COMMUNITY_Room 16 LDtk Data|Room 16 LDtk Data]]
- [[_COMMUNITY_Room 17 LDtk Data|Room 17 LDtk Data]]
- [[_COMMUNITY_Room 18 LDtk Data|Room 18 LDtk Data]]
- [[_COMMUNITY_Room 19 LDtk Data|Room 19 LDtk Data]]
- [[_COMMUNITY_Room 1 LDtk Data|Room 1 LDtk Data]]
- [[_COMMUNITY_Room 20 LDtk Data|Room 20 LDtk Data]]
- [[_COMMUNITY_Room 21 LDtk Data|Room 21 LDtk Data]]
- [[_COMMUNITY_Room 5 LDtk Data|Room 5 LDtk Data]]
- [[_COMMUNITY_Room 81 LDtk Data|Room 81 LDtk Data]]
- [[_COMMUNITY_Room 82 LDtk Data|Room 82 LDtk Data]]
- [[_COMMUNITY_Map Generator & Doors|Map Generator & Doors]]
- [[_COMMUNITY_Achievements Internals|Achievements Internals]]
- [[_COMMUNITY_NPC & Conditional Scripts|NPC & Conditional Scripts]]
- [[_COMMUNITY_LDtk Export Tool|LDtk Export Tool]]
- [[_COMMUNITY_Player Abilities Concepts|Player Abilities Concepts]]
- [[_COMMUNITY_Credits Scene|Credits Scene]]
- [[_COMMUNITY_In-Game Menu|In-Game Menu]]
- [[_COMMUNITY_Save & Run State Concepts|Save & Run State Concepts]]
- [[_COMMUNITY_Run Graph Concepts|Run Graph Concepts]]
- [[_COMMUNITY_Room Loading Concepts|Room Loading Concepts]]
- [[_COMMUNITY_Playdate Simulator Tasks|Playdate Simulator Tasks]]
- [[_COMMUNITY_Engine Libraries|Engine Libraries]]
- [[_COMMUNITY_Items & Portals Concepts|Items & Portals Concepts]]
- [[_COMMUNITY_HUD Concepts|HUD Concepts]]
- [[_COMMUNITY_Microwave & Food Docs|Microwave & Food Docs]]
- [[_COMMUNITY_Space Scene Docs|Space Scene Docs]]
- [[_COMMUNITY_Nova Editor Config|Nova Editor Config]]
- [[_COMMUNITY_VSCode Settings|VSCode Settings]]
- [[_COMMUNITY_Tile Loading Docs|Tile Loading Docs]]
- [[_COMMUNITY_Trigger System Docs|Trigger System Docs]]
- [[_COMMUNITY_Claude Settings|Claude Settings]]
- [[_COMMUNITY_Card Highlight Animation|Card Highlight Animation]]
- [[_COMMUNITY_Launch Images|Launch Images]]
- [[_COMMUNITY_README|README]]
- [[_COMMUNITY_Utilities|Utilities]]

## God Nodes (most connected - your core abstractions)
1. `customFields` - 15 edges
2. `customFields` - 15 edges
3. `customFields` - 15 edges
4. `customFields` - 15 edges
5. `customFields` - 15 edges
6. `customFields` - 15 edges
7. `customFields` - 15 edges
8. `customFields` - 15 edges
9. `customFields` - 15 edges
10. `customFields` - 15 edges

## Surprising Connections (you probably didn't know these)
- `DefaultPlayerData.skills table` --references--> `PlayerData.skills.canFight`  [EXTRACTED]
  source/assets/data/PlayerDataTables.lua → .superpowers/sdd/task-5-brief.md
- `PlayerDance:init(bpm, spritePath)` --implements--> `Full-screen 400x240 combat sprite sizing`  [EXTRACTED]
  source/entities/UI/battle/playerDance.lua → .superpowers/sdd/task-2-brief.md
- `PlayerDance:init(bpm, spritePath)` --conceptually_related_to--> `Optional spritePath parameter pattern`  [INFERRED]
  source/entities/UI/battle/playerDance.lua → .superpowers/sdd/task-4-brief.md
- `EnemyRatDance:init(bpm, evolveType, isEvolving, spritePath)` --implements--> `Full-screen 400x240 combat sprite sizing`  [EXTRACTED]
  source/entities/UI/battle/enemyRatDance.lua → .superpowers/sdd/task-2-brief.md
- `EnemyRatDance:init(bpm, evolveType, isEvolving, spritePath)` --conceptually_related_to--> `Optional spritePath parameter pattern`  [INFERRED]
  source/entities/UI/battle/enemyRatDance.lua → .superpowers/sdd/task-4-brief.md

## Import Cycles
- None detected.

## Communities (117 total, 5 thin omitted)

### Community 0 - "CrewMember AI"
Cohesion: 0.05
Nodes (25): CrewMember:taken(), CreateDoorsFromNode(), CreateWallPlugsFromNode(), Door:goTo(), Door:init(), plugBrickImage(), setRectValues(), WallPlug:init() (+17 more)

### Community 1 - "Player State & Effects"
Cohesion: 0.05
Nodes (5): Player:fallBelow(), Player:riseAbove(), scene:init(), scene:start(), RunState.startRun()

### Community 2 - "Enemy AI Core"
Cohesion: 0.05
Nodes (11): Enemy:moveCollision(), GrappleHook:update(), Player:checkHoleTile(), Player:checkTinyHoleTile(), Player:isOnHole(), Player:update(), GetTileUnderPlayer(), IsHoleAt() (+3 more)

### Community 3 - "Cockpit UI"
Cohesion: 0.05
Nodes (23): Accelerometer pointer control + calibration, Cockpit sequence/pattern system, Config.Cockpit, Config.CollideGroups, Config.Doors positions and spawnCoords, Config.Grapple, Config.ZIndex render layers, Key system (PlayerData.keys) (+15 more)

### Community 4 - "Maze Scene & Player Data"
Cohesion: 0.06
Nodes (22): deepcopy(), ResetPlayerData(), scene:exit(), captureResumePosition(), MazeScene.onDeviceSleep(), scene:finish(), scene:init(), scene:pause() (+14 more)

### Community 5 - "Achievement Toasts"
Cohesion: 0.10
Nodes (34): advanceByWithToast(), advanceToWithToast(), advanceWithToast(), at.clearCaches(), at.destroy(), at.drawCard(), at.formatDate(), at.initialize() (+26 more)

### Community 6 - "Dance Battle Concepts"
Cohesion: 0.08
Nodes (24): BackgroundDance:init(spritePath), Fight spritesheet swap with dev-time probe, Full-screen 400x240 combat sprite sizing, Optional spritePath parameter pattern, PlayerData.skills.canFight, Config.Dance rhythm combat difficulties, Fight variant spritesheets, getPatternKey(profile) (+16 more)

### Community 7 - "CrewMember Docs"
Cohesion: 0.07
Nodes (33): CrewMember AI States, CrewMember Capture (taken), CrewMember Entity, exitHiding Group Bug, Hiding State & hidingTokens, Turn-Based Sync via movementFrames, Balance Bar System, ButtonPress System (+25 more)

### Community 8 - "Brocorat Enemy"
Cohesion: 0.06
Nodes (27): bgColor, customFields, comic_name, comic_wasPlayed, DoorsConnection, level, light, play (+19 more)

### Community 9 - "Room 23 LDtk Data"
Cohesion: 0.06
Nodes (30): bgColor, customFields, comic_name, comic_wasPlayed, DoorsConnection, level, light, play (+22 more)

### Community 10 - "Room 2 LDtk Data"
Cohesion: 0.06
Nodes (30): bgColor, customFields, comic_name, comic_wasPlayed, DoorsConnection, level, light, play (+22 more)

### Community 11 - "Room 3 LDtk Data"
Cohesion: 0.06
Nodes (30): bgColor, customFields, comic_name, comic_wasPlayed, DoorsConnection, level, light, play (+22 more)

### Community 12 - "Room 8 LDtk Data"
Cohesion: 0.06
Nodes (30): bgColor, customFields, comic_name, comic_wasPlayed, DoorsConnection, level, light, play (+22 more)

### Community 13 - "Achievements & Comics"
Cohesion: 0.07
Nodes (22): achievements.grant, achievements.crossgame, achievements.toasts, achievements.viewer, comics registry, PlayerData.isCutscene flag, PlayerData.isGaming flag, Panels cutscene library (+14 more)

### Community 14 - "Room 12 LDtk Data"
Cohesion: 0.07
Nodes (29): bgColor, customFields, comic_name, comic_wasPlayed, DoorsConnection, level, light, play (+21 more)

### Community 15 - "Room 22 LDtk Data"
Cohesion: 0.07
Nodes (29): bgColor, customFields, comic_name, comic_wasPlayed, DoorsConnection, level, light, play (+21 more)

### Community 16 - "Room 10 LDtk Data"
Cohesion: 0.07
Nodes (28): bgColor, customFields, comic_name, comic_wasPlayed, DoorsConnection, level, light, play (+20 more)

### Community 17 - "Room 4 LDtk Data"
Cohesion: 0.07
Nodes (28): bgColor, customFields, comic_name, comic_wasPlayed, DoorsConnection, level, light, play (+20 more)

### Community 18 - "Room 7 LDtk Data"
Cohesion: 0.07
Nodes (28): bgColor, customFields, comic_name, comic_wasPlayed, DoorsConnection, level, light, play (+20 more)

### Community 19 - "Room 11 LDtk Data"
Cohesion: 0.07
Nodes (27): bgColor, customFields, comic_name, comic_wasPlayed, DoorsConnection, level, light, play (+19 more)

### Community 20 - "Room 14 LDtk Data"
Cohesion: 0.07
Nodes (27): bgColor, customFields, comic_name, comic_wasPlayed, DoorsConnection, level, light, play (+19 more)

### Community 21 - "Room 6 LDtk Data"
Cohesion: 0.07
Nodes (27): bgColor, customFields, comic_name, comic_wasPlayed, DoorsConnection, level, light, play (+19 more)

### Community 22 - "Room 13 LDtk Data"
Cohesion: 0.07
Nodes (26): bgColor, customFields, comic_name, comic_wasPlayed, DoorsConnection, level, light, play (+18 more)

### Community 23 - "Room 15 LDtk Data"
Cohesion: 0.07
Nodes (26): bgColor, customFields, comic_name, comic_wasPlayed, DoorsConnection, level, light, play (+18 more)

### Community 24 - "Room 16 LDtk Data"
Cohesion: 0.07
Nodes (26): bgColor, customFields, comic_name, comic_wasPlayed, DoorsConnection, level, light, play (+18 more)

### Community 25 - "Room 17 LDtk Data"
Cohesion: 0.07
Nodes (26): bgColor, customFields, comic_name, comic_wasPlayed, DoorsConnection, level, light, play (+18 more)

### Community 26 - "Room 18 LDtk Data"
Cohesion: 0.07
Nodes (26): bgColor, customFields, comic_name, comic_wasPlayed, DoorsConnection, level, light, play (+18 more)

### Community 27 - "Room 19 LDtk Data"
Cohesion: 0.07
Nodes (26): bgColor, customFields, comic_name, comic_wasPlayed, DoorsConnection, level, light, play (+18 more)

### Community 28 - "Room 1 LDtk Data"
Cohesion: 0.07
Nodes (26): bgColor, customFields, comic_name, comic_wasPlayed, DoorsConnection, level, light, play (+18 more)

### Community 29 - "Room 20 LDtk Data"
Cohesion: 0.07
Nodes (26): bgColor, customFields, comic_name, comic_wasPlayed, DoorsConnection, level, light, play (+18 more)

### Community 30 - "Room 21 LDtk Data"
Cohesion: 0.07
Nodes (26): bgColor, customFields, comic_name, comic_wasPlayed, DoorsConnection, level, light, play (+18 more)

### Community 31 - "Room 5 LDtk Data"
Cohesion: 0.07
Nodes (26): bgColor, customFields, comic_name, comic_wasPlayed, DoorsConnection, level, light, play (+18 more)

### Community 32 - "Room 81 LDtk Data"
Cohesion: 0.07
Nodes (26): bgColor, customFields, comic_name, comic_wasPlayed, DoorsConnection, level, light, play (+18 more)

### Community 33 - "Room 82 LDtk Data"
Cohesion: 0.08
Nodes (25): bgColor, customFields, comic_name, comic_wasPlayed, DoorsConnection, level, light, play (+17 more)

### Community 34 - "Map Generator & Doors"
Cohesion: 0.17
Nodes (20): DoorsConnection customField, connect(), doorCountsOf(), doorSidesOf(), doorSlotsSig(), hasHolesTemplate(), isDarkTemplate(), makeNode() (+12 more)

### Community 35 - "Achievements Internals"
Cohesion: 0.23
Nodes (15): achievements.initialize(), achievements.paths.get_achievement_data_file_path(), achievements.paths.get_achievement_folder_root_path(), achievements.paths.get_shared_images_path(), achievements.paths.get_shared_images_updated_file_path(), copy_file(), crawlImagePaths(), dirname() (+7 more)

### Community 36 - "NPC & Conditional Scripts"
Cohesion: 0.23
Nodes (16): conditionalScripts evaluator, Conditions.lua evaluator, Config (tunable constants), Crew roster & endgame (final room), NPC entity, NPC grant system (hasGranted one-shot), NPCCollider (wall blocker), PlayerData (global mutable state) (+8 more)

### Community 37 - "LDtk Export Tool"
Cohesion: 0.18
Nodes (12): BUILD_DIR, copyImages(), ensureDir(), fs, generateLevels(), generateTilemap(), hasDoors(), loadRooms() (+4 more)

### Community 38 - "Player Abilities Concepts"
Cohesion: 0.22
Nodes (13): Battery drain/charge system, Calories and pedometer, DanceScene (rhythm combat), Dark-charge / dark reveal overcharge, FXshadow (darkness/lighting), LightBurst (lamp flash cone), Player movement, Plungerang boomerang projectile (+5 more)

### Community 40 - "Credits Scene"
Cohesion: 0.24
Nodes (5): Image Preload Strategy, Credits Scroll System, itemHeight(), scene:drawBackground(), scene:enter()

### Community 42 - "In-Game Menu"
Cohesion: 0.22
Nodes (3): inGameMenu:drawMapOnMenu(), buildLayout(), MapDrawer.drawMap()

### Community 44 - "Save & Run State Concepts"
Cohesion: 0.33
Nodes (9): DeadScene (game over), Player dead state (deathCause), RunState (active run), Save version 3.0-PROCGEN, SaveSystem (persistence), TitleScene (main menu), Vertical navigation = new run, Save System (doc) (+1 more)

### Community 45 - "Run Graph Concepts"
Cohesion: 0.39
Nodes (9): Door signature matching, inGameMenu (map + crew hats), MapDrawer (run-graph map render), MapGenerator (graph builder), Room pool (procGen/roomRole), Procedural run graph, Closed-door wall plugs, In-Game Menu (doc) (+1 more)

### Community 46 - "Room Loading Concepts"
Cohesion: 0.36
Nodes (8): CreateTileColliders (segment merge), Legacy fixed-grid door path (removed), levelsLDTK (room templates), MazeScene:enter room load flow, RoomID = level*100 + room, roomsByIid hash, Level Loading (doc), main.lua entry point

### Community 49 - "Playdate Simulator Tasks"
Cohesion: 0.25
Nodes (7): extension, identifier, name, extensionTemplate, extensionValues, playdate.base-path, playdate.main-path

### Community 50 - "Engine Libraries"
Cohesion: 0.38
Nodes (7): anim8 (Love2D animations), bump.lua (Love2D collisions), CollideGroups (collision groups), Crank -> Q/E key mapping, Noble Engine (Playdate framework), Custom Scene Manager (Love2D), Love2D Port Guide (doc)

### Community 51 - "Items & Portals Concepts"
Cohesion: 0.38
Nodes (7): Items (collectibles/grants), Microwave (cook food to heal), Minifier (shrink/grow crank prop), PortalDoor (secret-room entrance), PropItem system, Secret rooms via PortalDoors, Props and Items (doc)

### Community 55 - "HUD Concepts"
Cohesion: 0.47
Nodes (6): Battery bar (HUD), HealthIndicator (HUD), playerHud (HUD container), sanityHud (HUD), UIHud (interaction indicator), HUD System (doc)

### Community 56 - "Microwave & Food Docs"
Cohesion: 0.33
Nodes (6): Calorie-Burn-Skip While Cooking, Config.Microwave Tunables, Cooking Flow, Emergent Difficulty Tension, Food Resource (PlayerData.food), Microwave + Food Healing System

### Community 61 - "Space Scene Docs"
Cohesion: 0.40
Nodes (5): Accelerometer Crosshair Control, Danger Bar System, Fighter/Travel Modes, Meteorite Parallax System, SpaceScene

### Community 62 - "Nova Editor Config"
Cohesion: 0.40
Nodes (4): editor.default_syntax, workspace.art_style, workspace.color, workspace.name

### Community 68 - "VSCode Settings"
Cohesion: 0.40
Nodes (4): Lua.diagnostics.globals, Lua.workspace.library, playdate.output, playdate.source

### Community 71 - "Tile Loading Docs"
Cohesion: 0.83
Nodes (4): Box Collider Class, CreateTileColliders Algorithm, Tile Loading, tileMapData / IntGrid Values

### Community 72 - "Trigger System Docs"
Cohesion: 0.50
Nodes (4): returnScript Logic, Trigger System, Trigger Types, usedTrigger Persistence

## Knowledge Gaps
- **702 isolated node(s):** `allow`, `editor.default_syntax`, `workspace.art_style`, `workspace.color`, `workspace.name` (+697 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **5 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `RunState.startRun()` connect `Player State & Effects` to `CrewMember AI`, `Map Generator & Doors`, `Maze Scene & Player Data`?**
  _High betweenness centrality (0.034) - this node is a cross-community bridge._
- **Why does `DoorsConnection customField` connect `Map Generator & Doors` to `Cockpit UI`, `Run Graph Concepts`?**
  _High betweenness centrality (0.033) - this node is a cross-community bridge._
- **What connects `allow`, `editor.default_syntax`, `workspace.art_style` to the rest of the system?**
  _710 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `CrewMember AI` be split into smaller, more focused modules?**
  _Cohesion score 0.05061224489795919 - nodes in this community are weakly interconnected._
- **Should `Player State & Effects` be split into smaller, more focused modules?**
  _Cohesion score 0.045454545454545456 - nodes in this community are weakly interconnected._
- **Should `Enemy AI Core` be split into smaller, more focused modules?**
  _Cohesion score 0.052854122621564484 - nodes in this community are weakly interconnected._
- **Should `Cockpit UI` be split into smaller, more focused modules?**
  _Cohesion score 0.04994192799070848 - nodes in this community are weakly interconnected._