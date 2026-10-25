# Phase 0 test protocol

Each run is one lab session. Settings are the interval and accuracy chips on the home screen. Export every session right after Stop and name the export folder `<device>-<run>-<YYYYMMDD>` (for example `pixel9a-R2-20261025`). Analyse with the commands under each run.

Before the first run on a phone: grant all three permissions (Precise, Always, Notifications) and check the lab's notification is visible after Start. Keep the phone's clock on automatic network time so the NTP offset stays small.

## Single-phone runs

| Run | Phone | Settings | What you do | Duration |
| --- | --- | --- | --- | --- |
| R1 | each | 30 s · High | Walk outdoors with the app open and the screen on. | 20 min |
| R2 | each | 30 s · High | Start, lock the screen, put the phone in a pocket, walk outdoors. | 20 min |
| R3 | each | 15 s · High | Same as R2. | 20 min |
| R4 | each | 120 s · High | Same as R2. | 20 min |
| R5 | each | 30 s · High | Turn battery saver on. Same as R2. | 20 min |
| R6 | each | 30 s · High | Sit indoors, phone on a table, screen locked. | 20 min |
| R7 | each | 30 s · High | Start, lock the screen, wait 2 min, force-stop the app from system settings, wait 3 min, open the app again. | 10 min |
| R8 | each | 30 s · High | Start, lock the screen, wait 2 min, revoke the app's location permission in system settings (Android kills the process), wait 3 min, open the app again and look at the permission chips and the event feed. | 10 min |

Analysis for each run:

```bash
python3 labs/location_lab/tools/analyze.py single <export_dir>
```

Record in the results table: interval median and p90, outages, accuracy median, battery drain. For R7 check that the report lists a process restart (`app_start`) and that samples resume after it. For R8 expect the process to die on revocation: samples stop at that moment, the reopen writes `app_start`, and the permission chips show the missing grant. The finding is whether the lab resumes sampling or sits silently; either way note it.

## Two-phone runs

Both phones use 30 s · High and are started within a minute of each other. One tester holds each phone. Press **Together** the moment you are within arm's reach and **Apart** when you have clearly separated (more than 30 m). Pressing on one phone is enough; pressing on both is fine.

| Run | What you do | Duration |
| --- | --- | --- |
| P1 | Walk towards each other on an open path, pass at 1 to 2 m without stopping, keep walking 50 m, turn and repeat. Five passes. Together/Apart around each pass. | 20 min |
| P2 | Stand or sit 5 m apart outdoors. Together at start, Apart at end. | 10 min |
| P3 | Stand 50 m apart outdoors with a clear line of sight. No markers. | 10 min |
| P4 | Same as P1 but on a busy street with buildings on both sides. | 20 min |
| P5 | Same as P1 with both screens locked and phones in pockets. | 20 min |

Analysis for each run:

```bash
python3 labs/location_lab/tools/analyze.py pair <export_dir_phone1> <export_dir_phone2>
```

Record: recall and false detections for radius 20 m at window 60 s, plus the minimum distance and optimistic distance for each pass. P3 should produce zero detections at every radius; any detection there is a false positive worth understanding.

## Results table (one per phone)

| Run | samples | interval median / p90 (s) | outages | accuracy median (m) | drain (%/h) | notes |
| --- | --- | --- | --- | --- | --- | --- |
| R1 | | | | | | |
| R2 | | | | | | |
| R3 | | | | | | |
| R4 | | | | | | |
| R5 | | | | | | |
| R6 | | | | | | |
| R7 | | | | | | restart seen? |
| R8 | | | | | | event seen? |

| Pair run | recall @20 m / 60 s | false @20 m | min distance per pass (m) | optimistic (m) |
| --- | --- | --- | --- | --- |
| P1 | | | | |
| P2 | | | | |
| P3 | | | | |
| P4 | | | | |
| P5 | | | | |

## Decision (owner fills in, then copies to docs/superpowers/plans/decision-log.md)

- Background sampling at 30 s is / is not sustained on: …
- Crossings at 1 to 2 m are detected with recall … at radius … m and window … s.
- False detections at 5 m apart: … ; at 50 m apart: …
- Accepted operating modes: …
- Changes to radius, cadence or detection semantics: none / …
