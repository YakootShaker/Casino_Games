# Quiz Buzzer — Offline Multiplayer Quiz Game

An offline multiplayer quiz competition system built with Flutter. Two physical phones are used:

1. **Judge Device** — Controls the game, displays questions and scores, evaluates answers
2. **Player Display** — Shows three colored buzzer areas (Red/Blue/Green) for three players on a single phone

Communication happens over a local Wi-Fi network using WebSockets. **No internet connection required.**

## Screenshots

The app uses a dark theme with strong player colors:
- **Home Screen** — Choose Judge Mode or Player Display mode
- **Judge Lobby** — Start server, display QR code, rename players
- **Judge Dashboard** — See scores, current question, countdown, evaluate answers
- **Player Display** — Three colored buzzer areas → full-screen answering → results

## Architecture

```
┌──────────────────┐                    ┌──────────────────┐
│   Judge Device   │  ◄──WebSocket──►   │  Player Display  │
│                  │                    │                  │
│  GameEngine      │                    │  SocketClient    │
│  LocalServer     │                    │  BuzzerUI        │
│  SQLite DB       │                    │  Countdown       │
│  Judge Dashboard │                    │  3-Color Layout  │
└──────────────────┘                    └──────────────────┘
```

### Key Components

| Component | File | Purpose |
|---|---|---|
| Game Engine | `lib/features/game/domain/game_engine.dart` | Pure Dart state machine — authoritative game logic |
| Game State | `lib/features/game/domain/game_state.dart` | Immutable state snapshots |
| Models | `lib/features/game/domain/game_models.dart` | Player, Question, ScoreEvent, GameAttempt, GameSession |
| Round Timer | `lib/features/game/domain/round_timer.dart` | Server-side 10-second countdown |
| Local Server | `lib/features/connection/data/local_server.dart` | Shelf HTTP + WebSocket server |
| Socket Client | `lib/features/connection/data/socket_client.dart` | Client-side WS with reconnection |
| Database | `lib/services/database_service.dart` | SQLite schema, migrations, CRUD |
| Feedback | `lib/services/feedback_service.dart` | Sound effects + vibration |

### State Machine

```
disconnected → lobby → ready → answering → correctResult (2s) → ready / finished
                                    ↓ wrong    → ready (same question)
                                    ↓ timeout  → ready (same question)
                          ready → paused → ready
                          ready → finished
```

## Prerequisites

- **Flutter SDK** 3.47+ (Dart 3.13+)
- **Two Android phones** on the same Wi-Fi network
- Android Studio or `flutter` CLI

## Quick Start

### 1. Install Dependencies

```bash
cd <project_directory>
flutter pub get
```

### 2. Build & Install on Two Phones

```bash
# Connect first phone (Judge)
flutter install

# Connect second phone (Player Display)
flutter install
```

Or build an APK:

```bash
flutter build apk --release
```

### 3. Connect and Play

**On Phone 1 (Judge):**
1. Open the app → tap **Judge Mode**
2. Review/rename players
3. Tap **Start Game Server**
4. A QR code and IP address appear

**On Phone 2 (Player Display):**
1. Open the app → tap **Player Display**
2. Scan the QR code shown on the Judge's phone  
   *(or tap Manual Entry and type the IP, port, and token)*
3. The display connects and shows three colored buzzer areas

**On Phone 1 (Judge):**
4. The dashboard activates automatically once the display connects
5. Read the question aloud
6. Wait for a player to buzz in
7. Evaluate: tap **Correct (+1)** or **Wrong (-1)**

## Game Rules

### Buzzer Press
- The player display shows **3 equal colored zones** (Red, Blue, Green)
- When a player touches their zone, the **entire screen** fills with their color
- A **10-second countdown** begins
- All other touches are locked until the attempt resolves

### Scoring
| Event | Score Change |
|---|---|
| Correct answer | **+1** |
| Wrong answer | **-1** |
| Timeout (10s) | **-1** |

### After Wrong Answer / Timeout
- **Same question stays active** — all buzzers re-enable
- The player who got it wrong **can try again**
- The question only advances after a correct answer or judge skip

### After Correct Answer
- Winner's color fills the screen for **2 seconds**
- Next question automatically activates
- If no questions remain, the game ends

### Negative Scores
Scores can go negative. There is no floor.

### Judge Controls
- **Correct (+1)** / **Wrong (-1)** — only active during an answering turn
- **Skip Question** — advances without penalty (even if someone is answering)
- **Pause / Resume** — only when no one is answering
- **End Game** — finishes immediately
- **Reset** — with confirmation; tournament history is preserved

## Database Structure

SQLite on the judge device:

```sql
players         (id, name, color_hex, created_at)
questions       (id, text, answer, explanation, category, difficulty, is_active, created_at)
game_sessions   (id, started_at, ended_at, status, winner_id)
session_players (id, session_id, player_id, final_score)
session_questions (id, session_id, question_id, order_index, answered_correctly, answered_by)
score_events    (id, session_id, question_id, player_id, event_type, delta, attempt_id, created_at)
                 UNIQUE(attempt_id, event_type) — prevents duplicate scoring
settings        (key, value)
```

## WebSocket Protocol (v1)

Every message:
```json
{
  "type": "MESSAGE_TYPE",
  "protocolVersion": "1",
  "messageId": "<uuid>",
  "sessionId": "<uuid>",
  "timestamp": 1234567890123,
  "payload": { ... }
}
```

### Message Types
| Type | Direction | Purpose |
|---|---|---|
| `JOIN_REQUEST` | Display → Server | Connect with session token |
| `JOIN_ACCEPTED` / `JOIN_REJECTED` | Server → Display | Connection result |
| `STATE_SNAPSHOT` | Server → Display | Full authoritative state |
| `BUZZER_PRESS` | Display → Server | Player presses buzzer |
| `BUZZER_ACCEPTED` / `BUZZER_REJECTED` | Server → Display | Buzzer result |
| `ANSWERING_STARTED` | Server → Display | Turn has begun |
| `CORRECT_ANSWER` / `WRONG_ANSWER` / `TIMEOUT` | Server → Display | Turn result |
| `SCORE_UPDATE` | Server → Display | Updated scores |
| `QUESTION_UPDATE` | Server → Display | Next question |
| `GAME_PAUSED` / `GAME_RESUMED` | Server → Display | Pause state |
| `GAME_FINISHED` | Server → Display | Game over |
| `SKIP_QUESTION` | Server → Display | Question skipped |
| `ERROR` | Server → Display | Error message |

### State Snapshot

On connect/reconnect, the server sends a full state containing:
- Current phase, question, active player, answering deadline
- All scores, question index, state version, session ID
- Player list with colors

The display discards stale updates using `stateVersion`.

## Reconnection

The player display implements automatic WebSocket reconnection with exponential backoff:
- Starts at 500ms, doubles up to 30s max
- Shows a clear "Reconnecting..." indicator
- On reconnect, requests a fresh state snapshot
- Buzzers are disabled during disconnection
- No competing local game state — the judge is always authoritative

## Sound & Vibration

Configurable in **Settings**:
- Sound effects for: buzzer, correct, wrong, timeout, countdown warning, game finished
- Vibration on buzzer press and result feedback
- Falls back gracefully if audio assets are missing or vibration is unsupported

To add custom sounds, place `.mp3` files in `assets/audio/`:
- `buzzer_accepted.mp3`, `correct_answer.mp3`, `wrong_answer.mp3`
- `timeout.mp3`, `countdown_warning.mp3`, `game_finished.mp3`

## Security Notes

- This app is designed for a **trusted local Wi-Fi network**
- A session token authorizes the display connection
- All scoring authority resides on the judge device
- The display cannot independently award or deduct points
- Incoming messages are validated; malformed data is rejected
- Duplicate score events are prevented by the `UNIQUE(attempt_id, event_type)` constraint

## Testing

### Run All Tests
```bash
flutter test
```

### Test Coverage
The test suite includes 43 tests:

**Unit Tests (`test/unit/game_engine_test.dart`):**
- Initial state, startGame validation
- Buzzer press (valid, duplicate, invalid phase)
- Correct answer (+1, state transition, attempt ID mismatch)
- Wrong answer (-1, same question, retry allowed)
- Timeout (-1, same question, stale timeout ignored)
- Race conditions (correct then timeout, timeout then correct)
- Negative scores
- Question progression and game completion
- Skip question (with/without active attempt)
- Pause/resume
- End game, reset game
- `canEvaluate` accuracy
- Display connect/disconnect

**Model Tests (`test/unit/game_models_test.dart`):**
- Serialization/deserialization for Player, Question, ScoreEvent
- GameAttempt expiry
- Leader/winner resolution
- State snapshots

**Timer Tests (`test/unit/round_timer_test.dart`):**
- Timer fires on expiry, cancel safety, stream emissions

**Widget Tests (`test/widget_test.dart`):**
- App smoke test

### Static Analysis
```bash
dart analyze
```

## Project Structure

```
lib/
  main.dart
  app/
    app.dart                    # MaterialApp with Riverpod
    router.dart                 # Navigator routes + HomeScreen
    theme.dart                  # Dark theme with player colors
  core/
    constants/
      game_constants.dart       # Scoring, timing, colors
      ws_message_types.dart     # WebSocket message type strings
    errors/
      app_exception.dart        # Custom exceptions
  features/
    connection/
      data/
        local_server.dart       # Judge HTTP+WS server (shelf)
        socket_client.dart      # Player WS client with reconnect
      domain/
        ws_message.dart         # Protocol message model
      presentation/
        judge_lobby_screen.dart # Server setup + QR code
        player_join_screen.dart # QR scan + manual entry
    game/
      data/
        game_repository.dart    # Session/score persistence
      domain/
        game_engine.dart        # Authoritative state machine
        game_models.dart        # Player, Question, ScoreEvent, etc.
        game_state.dart         # Immutable state + GamePhase enum
        round_timer.dart        # Server-side countdown
      presentation/
        judge_dashboard.dart    # Judge controls + scoreboard
        player_display_screen.dart # 3-color buzzers + answering
    players/
      data/
        players_repository.dart
      presentation/
        player_management_screen.dart
    questions/
      data/
        questions_repository.dart
      presentation/
        question_bank_screen.dart
    settings/
      presentation/
        settings_screen.dart
    tournaments/
      presentation/
        tournament_history_screen.dart
  services/
    database_service.dart       # SQLite schema + CRUD
    feedback_service.dart       # Audio + vibration
    providers.dart              # Riverpod providers
test/
  unit/
    game_engine_test.dart       # 32 game engine tests
    game_models_test.dart       # 6 model tests
    round_timer_test.dart       # 4 timer tests
  widget_test.dart              # Smoke test
```

## Platform Notes

### Android
- The judge server binds to `0.0.0.0` on port 8765
- `network_info_plus` is used to detect the local Wi-Fi IP
- Camera permission is requested for QR scanning (player display only)
- Both phones must be on the **same Wi-Fi network**
- The judge app must remain in the **foreground** during gameplay

### Known Limitations
- **Single display:** Only one player display can connect at a time
- **Foreground only:** The judge server does not run reliably in the background
- **No real two-device testing in this build environment:** The WebSocket protocol and reconnection logic have been verified through unit and integration tests, but physical two-phone networking has not been tested
- **Audio assets not bundled:** The app handles missing audio gracefully; add your own `.mp3` files to `assets/audio/` for sound effects
- **Process restart during answering:** If the judge app is killed mid-countdown, the active attempt is lost. Historical scores are preserved. The turn is not double-penalized.

## Sample Questions

10 general knowledge questions are pre-loaded:
1. What is the capital of France? → Paris
2. How many sides does a hexagon have? → 6
3. What is the chemical symbol for water? → H₂O
4. Who painted the Mona Lisa? → Leonardo da Vinci
5. What year did World War II end? → 1945
6. What is the largest planet in our solar system? → Jupiter
7. What is the speed of light approximately? → 299,792 km/s
8. Who wrote Romeo and Juliet? → William Shakespeare
9. What is the square root of 144? → 12
10. In which country is the Great Wall located? → China

Add more questions via the **Question Bank** screen or import JSON.

## License

Private project — not published to pub.dev.
