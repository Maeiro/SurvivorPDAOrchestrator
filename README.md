# Survivor PDA Orchestrator

An independent adaptive event director for Project Zomboid Build 42.21 and Survivor PDA (`ProjectRPGExpanded`). Runs in single player and on the multiplayer server. Extraction Mode is optional; Extraction Mode PDA Integration is not required.

## Enable and configure

Enable **Survivor PDA Orchestrator** in the game's mod list together with ProjectRPGExpanded and ZombieBuddy 2.3.4+. The director itself is **disabled by default**. Open the **Orchestrator** section in PDA Admin to configure and diagnose it, or use the **Survivor PDA Orchestrator** sandbox page. The Diagnostics tab includes a button to request a decision immediately. It bypasses only the scheduled wait; event locks and survivor protections still apply. PDA actions use the existing ProjectRPG admin permissions. English and Brazilian Portuguese follow the PDA's own language selection.

The Orchestrator category has Diagnostics, General, Protection, Events and Night Events tabs. Settings edited in the PDA use ProjectRPG's existing world overrides and synchronization. Custom interval fields apply only to the Custom preset. Reversed interval and duration bounds are ordered automatically. Changing the effective interval starts a new countdown; other changes apply to the next decision. Presets affect frequency only.

Night Events are independent of the director's event schedule and can run at the same time as XP, drops, boxes or a horde. They are disabled by default and have a 50% chance to occur on each night when enabled. On a successful night, the configured level weights choose the loot chance bonus and sprinter chance. The active event appears in the PDA event HUD with its icon and current bonuses. The server rolls and synchronizes the event and level once per night. Defaults remain weights 50/35/10/5, loot chance bonuses 50/100/150/200%, and sprinter chances 10/20/33/50%.

## Decisions and timing

The default Rare preset waits 60–120 real played minutes after an event ends, including before the first event. Moderate uses 30–60 minutes and Frequent uses 15–30. Evaluations occur every 30 played seconds when a decision is due; blocked or failed starts retry after five played minutes. The clock stops while disabled, paused, offline or without living players. Time acceleration does not accelerate it, and long stalls do not produce catch-up events. Progress and the last 20 decisions persist with the world. Survivor observation windows and join protection rebuild after loading or reconnecting.

Native events retain **ProjectRPG's real wall-clock durations**, including paused/offline time. Hordes retain their native in-game duration and cooldown. Only scheduling and protective observation windows use the director's active-play clock.

Threat chances default to 10/15/20/25/30% for Danger stages 1–5. A configurable night factor applies between 20:00 and 06:00 (default 1, unchanged chance). Targets are chosen by oldest director attack; ties favor higher RPG level, then username. Missing essential physical data or unknown Extraction Mode state prevents attacks. The default protections cover health below 80%, endurance below 60%, fatigue above 60%, bleeding, sleep, vehicles, damage in the last 10 minutes, entry/spawn within 15 minutes, and 20 kills in five minutes. A vulnerable survivor within 100 tiles also protects the target; radius zero disables the proximity check. Deaths and horde endings grant 20 minutes of rest.

Extraction Mode is read through its authoritative raid data and existing hideout checks. Hideouts, deploy, boarding, insertion, rescue and other transitions are protected. The integration never routes commands or repairs Extraction Mode state.

## Events

The director reuses native XP, Mystery Box Hunt, money, Evil Blood, Evil Souls, Evil Marrow, Evil Bile and horde implementations. It never creates its own rewards or spawner. Bonuses apply globally; hordes target one eligible survivor. Default bonuses last 10–15 real minutes: XP/money x1.5, boxes 2%, materials 10%. Opportunity weights are XP 25, money 20, boxes 10, blood 15, souls 10, marrow 10 and bile 10. It avoids repeating the last opportunity when alternatives exist; weight zero excludes an event.

The director waits for existing events before starting its own, never overwrites or ends admin/ticket events, and respects native horde size, duration, cooldown and the HordesEnabled switch. **Native kill-triggered hordes remain independent and may still occur during director protection/rest periods.** Events started externally after a director event may overlap it. Switching the director off lets already running events end normally.

Unavailable native APIs disable only affected event adapters until a Lua reload/restart and appear in diagnostics and console logs. No external AI service, inventory scans, world population scans or player-issued event-start commands are used.

## Development and installation

The package is under `Contents/mods/SurvivorPDAOrchestrator`, with matching root and `42` metadata. The Java hooks use ZombieBuddy's patch loader. Build the JAR before local installation:

```powershell
.\build.ps1 -ZombieBuddyJar 'C:\Path\to\ZombieBuddy\libs\ZombieBuddy.jar'
```

```powershell
python tools/generate_metadata.py
python tests/run.py
.\install.ps1
```

Development checks require Python with `lupa` (Lua 5.1 backend) and `luac` 5.1 on PATH. Metadata and translation assets are generated by `tools/generate_metadata.py`; regenerate them after editing settings or translation text. Tests simulate policy, timers, native adapters, permissions and PDA integration. If the installed ProjectRPG source exists at the development machine's Workshop path, they also exercise its real settings registry, validator, layout and persistence code. These checks do not replace an in-game SP or dedicated-server test.

The installation script copies and hashes only this mod's package into `%USERPROFILE%\Zomboid\Workshop\Survivor PDA Orchestrator` by default. It does not enable the mod, change existing mod lists, stop the game or publish to Steam. Multiplayer servers and clients need the mod enabled in their session configuration.
