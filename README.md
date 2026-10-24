# Wild Grace Kill Ledger

A World of Warcraft addon that keeps a permanent log of your **Ahead of the Curve** raid boss kills: when each kill happened and how many players earned AOTC on it. Built for streamers who help large numbers of players get their AOTC every season.

## Features

- **Choose your bosses.** Every raid boss comes from the in-game Adventure Guide, so new raids show up automatically. Track only the bosses you care about, and stop tracking at any time without losing past kills.
- **Automatic logging.** Each Heroic kill of a tracked boss is saved with its date, time, boss and raid.
- **AOTC counting.** After a kill, the addon listens briefly for achievement announcements in chat and counts each new AOTC once, keeping the names of who earned it.
- **Manual adjust.** Fix the count with +/- if someone was out of range, and add a note or tag (for example a stream number).
- **Searchable log.** Search by boss, raid, player or note, filter by raid and boss, and show only kills that granted AOTCs.
- **Delete with undo.** Remove a kill that was not part of your stream, with a confirmation and a short undo.
- **Stats.** Kills, total AOTCs, best day, average per kill, AOTCs per day and a breakdown by boss.
- **Export and import.** Copy the log as CSV or plain text for a spreadsheet, and paste a previous export back in to restore it. Duplicates are skipped.
- **Minimap button.** Click to open, drag to move.

## Installation

1. Download the latest `WildGraceKillLedger-x.y.z.zip` from the [Releases](../../releases) page.
2. Unzip it into your addons folder:
   `World of Warcraft/_retail_/Interface/AddOns/`
3. Make sure the result is `AddOns/WildGraceKillLedger/WildGraceKillLedger.toc`. The folder name must match the `.toc` file name.
4. Start the game and enable the addon in the AddOns list.

## Getting started

1. Open the addon with the minimap button or `/kl`.
2. On the **Bosses** tab, pick the raid and press **+ Track** on each boss you want to log (or **Track all shown**).
3. Kill the boss on Heroic. The kill popup appears and the kill is added to the log.

## Slash commands

| Command | What it does |
| --- | --- |
| `/kl` | Open or close the window |
| `/kl minimap` | Show or hide the minimap button |
| `/kl undo` | Restore the last deleted kill |
| `/kl test` | Create a fake kill to preview the interface (delete it afterwards) |
| `/kl findach <text>` | List achievement IDs whose name contains the text |
| `/kl ach <bossKey> <id>` | Force which achievement counts for a boss |
| `/kl aotcword <text>` | Add a word used to recognise the AOTC achievement name in non-English clients |

## How AOTC counting works

When a tracked Heroic boss dies, the addon listens for 5 seconds for achievement announcements in chat. Each announcement whose achievement name contains the boss name and "ahead of the curve" adds that player once. Your own achievement is read directly.

Limits to be aware of:

- Players who already had the AOTC do not announce it again, so they are not counted. This is intended.
- Players you do not receive announcements from (out of range, or with announcements turned off) are missed. Use the +/- buttons to correct the count.
- The listening time can be changed with `KL.WINDOW` at the top of `Core.lua`.
- The addon reads chat messages, which Blizzard may restrict in some situations. If the count stays at 0 on a real kill, please open an issue.

## Your data

Everything is stored in the account-wide saved variable `KillLedgerDB`:

`World of Warcraft/_retail_/WTF/Account/<ACCOUNT NAME>/SavedVariables/KillLedgerDB.lua`

Use the **Export** tab to back up your log regularly. To remove the addon completely, close the game and delete both the addon folder and that file (and `KillLedgerDB.lua.bak` if present).

## Known limitations

- Only Heroic difficulty is logged. To log Mythic as well, add `[16] = true` to `KL.ALLOWED_DIFFICULTY` in `Core.lua`.
- Addons cannot write files or use the clipboard, so export works through a text box you copy from with Ctrl+A, Ctrl+C.
- This is an early version and has had limited testing in game. Bug reports are welcome.
