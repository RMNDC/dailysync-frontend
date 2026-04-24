# 📘 DailySync — Full Project Documentation & Demo Guide

---

## 🗂️ What is DailySync?

DailySync is a **personal life dashboard web app** built with:
- **Flutter Web** → the frontend (what users see)
- **Node.js + Express** → the backend (the server/API)
- **MongoDB** → the database (where data is stored)
- **Netlify** → hosts the Flutter web app
- **Render** → hosts the Node.js backend

---

## 🏗️ Project Structure

```
dailysync/
├── lib/
│   ├── main.dart              → Login screen + Dashboard screen
│   ├── signup_screen.dart     → Register new account
│   ├── verify_email_screen.dart → Email verification result page
│   ├── habits_screen.dart     → Daily habits tracker
│   ├── goals_screen.dart      → Personal goals tracker
│   ├── mood_screen.dart       → Mood logger + analytics
│   ├── profile_screen.dart    → User profile + settings
│   └── config.dart            → Backend URL config
├── web/
│   ├── index.html             → Flutter web entry point
│   ├── manifest.json          → PWA manifest
│   └── _redirects             → Netlify SPA routing fix
└── pubspec.yaml               → Flutter dependencies
```

---

## 🔄 How the App Works — Full Flow

### 1. User opens the app
```
Browser → Netlify → loads build/web/index.html → Flutter boots up → LoginScreen shows
```

### 2. User signs up
```
SignupScreen
  → generates random username (e.g. "nova3k9xp")
  → sends POST /register to Render backend
  → backend hashes password with bcrypt
  → saves user to MongoDB
  → Flutter shows snackbar "🎉 Account created!"
  → navigates to LoginScreen
```

### 3. User logs in
```
LoginScreen
  → sends POST /login to backend
  → backend checks email + compares bcrypt password
  → if match → returns JWT token + userId
  → Flutter saves token in memory
  → navigates to DashboardScreen
  → shows snackbar "👋 Welcome back!"
```

### 4. Dashboard loads
```
DashboardScreen (StatefulWidget)
  → on initState() → calls _loadProfile()
  → sends GET /profile with Authorization: Bearer <token>
  → backend verifies JWT → returns username + emoji
  → Flutter shows "Good day, nova3k9xp! 👋"
  → shows 3 cards: Habits, Mood, Goals
```

---

## 🔐 Authentication — How JWT Works

```
1. Login → backend creates a token:
   jwt.sign({ email, id }, SECRET_KEY, { expiresIn: '24h' })

2. Token looks like:
   eyJhbGciOiJIUzI1NiJ9.eyJlbWFpbCI6InRlc3QifQ.abc123

3. Flutter sends it in every request:
   headers: { 'Authorization': 'Bearer eyJhbGci...' }

4. Backend verifies it:
   jwt.verify(token, SECRET_KEY) → returns { email, id }
   → uses id to find the user's data in MongoDB
```

**Why JWT?**
- No need to store sessions on the server
- Token expires after 24 hours automatically
- If token is wrong/expired → backend returns 401 Unauthorized

---

## 💪 Habits — How It Works

### Data stored in MongoDB:
```js
{
  userId: "abc123",
  name: "Drink 8 glasses of water",
  done: false,
  streak: 5,
  lastCompleted: "2024-01-15T10:00:00Z",
  createdAt: "2024-01-01T00:00:00Z"
}
```

### Flutter flow:
```
HabitsScreen loads
  → GET /habits → returns all habits for this user
  → displays list with animated circle checkboxes
  → streak shown as "🔥 5 day streak" subtitle

User taps circle checkbox
  → PUT /habits/:id with { done: true }
  → backend calculates new streak (see below)
  → returns updated habit with new streak value
  → Flutter updates the list item with new data
```

### 🔥 Streak Calculation (Backend):
```js
if (newDone === true) {
  const today = new Date();
  const diffDays = Math.floor((today - lastCompleted) / (1000 * 60 * 60 * 24));

  if (diffDays === 1)      → streak + 1  (completed yesterday, keep going!)
  else if (diffDays > 1)   → streak = 1  (missed days, reset to 1)
  else (diffDays === 0)    → streak stays (already done today, no change)
  
  // First time ever completing:
  if (!lastCompleted)      → streak = 1
}
```

**Example:**
```
Monday:   mark done → streak = 1, lastCompleted = Monday
Tuesday:  mark done → diffDays = 1 → streak = 2
Wednesday: mark done → diffDays = 1 → streak = 3
Friday:   mark done → diffDays = 2 → streak RESETS to 1 ❌
```

---

## 🎯 Goals — How It Works

### Data stored in MongoDB:
```js
{
  userId: "abc123",
  name: "Read 10 books this year",
  done: false,
  createdAt: "2024-01-01T00:00:00Z"
}
```

### Flutter flow:
```
GoalsScreen loads
  → GET /goals → returns all goals
  → calculates: completed = goals where done == true
  → calculates: progress = completed / total
  → shows bar chart (completed vs remaining)
  → shows stat chips: Total, Done, Left, %

User taps circle checkbox
  → PUT /goals/:id with { done: true/false }
  → Flutter updates local state
  → if completed → shows "Goal completed! 🎉" snackbar
  → progress bar and chart update automatically
```

### Progress calculation in Flutter:
```dart
final completed = _goals.where((g) => g['done'] == true).length;
final total = _goals.length;
final progress = total == 0 ? 0.0 : completed / total;
// progress is 0.0 to 1.0 (e.g. 0.75 = 75%)
```

---

## 😊 Mood — How It Works

### Data stored in MongoDB:
```js
{
  userId: "abc123",
  mood: "😊",
  note: "Had a great day at work!",
  date: "2024-01-15T14:30:00Z",
  createdAt: "2024-01-15T14:30:00Z"
}
```

### Flutter flow:
```
MoodScreen loads
  → GET /moods → returns all mood logs (newest first)
  → GET /daily-quote → returns today's motivational quote
  → shows quote banner at top
  → shows mood picker (7 emojis)
  → shows analytics pie chart
  → shows mood history list

User selects emoji + writes note + taps "Log Mood"
  → POST /moods with { mood, note, date }
  → backend saves to MongoDB
  → Flutter inserts new log at top of history list
  → pie chart updates automatically
  → shows "Mood logged! 😊" snackbar
```

### Pie chart calculation:
```dart
// Count how many times each mood was used
Map<String, int> get _moodCounts {
  final counts = <String, int>{};
  for (final mood in _moodLogs) {
    final key = mood['mood'];
    counts[key] = (counts[key] ?? 0) + 1;
  }
  return counts;
  // Example: { '😊': 5, '😐': 2, '😢': 1 }
}

// Each slice = (count / total) * 100 %
// '😊' → 5/8 = 62%
// '😐' → 2/8 = 25%
// '😢' → 1/8 = 13%
```

---

## 👤 Profile — How It Works

### Data stored in MongoDB (User):
```js
{
  email: "user@example.com",
  password: "$2b$12$hashedpassword...",  // bcrypt hash
  username: "nova3k9xp",
  emoji: "😎",
  isVerified: true
}
```

### Flutter flow:
```
ProfileScreen loads
  → GET /profile → returns { email, username, emoji }
  → shows emoji avatar (tappable to change)
  → shows username field (editable)
  → shows settings tiles with "coming soon" snackbars

User taps emoji avatar
  → shows emoji picker dialog (10 options)
  → user picks one → updates local state immediately

User types new username + taps "Save Changes"
  → PUT /profile with { username, emoji }
  → backend updates MongoDB
  → shows "Profile updated." message
  → when user goes back to Dashboard
  → Dashboard calls _loadProfile() again
  → greeting updates to new username
  → AppBar avatar updates to new emoji
```

---

## 🔑 Password Reset — How It Works

```
1. User clicks "Forgot password?" on login screen
2. Flutter sends POST /forgot-password with { email }
3. Backend:
   → finds user by email
   → generates random token: crypto.randomBytes(32)
   → saves token + expiry (1 hour) to user in MongoDB
   → (email sending is optional/silent fail)
4. Flutter shows "Reset link sent! Check your email."

5. User visits: https://dailysync-backend.onrender.com/reset-password?token=abc123
6. Backend shows HTML form (new password + confirm)
7. User submits → backend:
   → finds user with matching token that hasn't expired
   → hashes new password with bcrypt
   → clears token from MongoDB
   → shows success page with link back to app
```

---

## 📊 Responsive Layout — How It Works

```dart
final isMobile = MediaQuery.of(context).size.width < 700;

// Mobile: stack everything vertically
if (isMobile) Column(children: [...])

// Desktop: side by side
else Row(children: [
  Expanded(flex: 6, child: leftPanel),
  Expanded(flex: 4, child: rightPanel),
])
```

**Breakpoints used:**
```
< 700px  → Mobile layout (stacked)
≥ 700px  → Desktop layout (2 columns)
≤ 1100px → Max content width (centered)
```

---

## 🚀 Rate Limiting — How It Works

```js
// Login: max 5 attempts per 15 minutes per IP
const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,  // 15 minutes
  max: 5,
  message: { success: false, message: 'Too many login attempts...' }
});

// Register: max 5 accounts per hour per IP
const registerLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,  // 1 hour
  max: 5,
});
```

**Why?** Prevents brute force attacks (someone trying thousands of passwords).

---

## 🔒 Password Hashing — How bcrypt Works

```js
// On register: hash the password
const hashedPassword = await bcrypt.hash(password, 12);
// 12 = salt rounds (higher = more secure but slower)
// "mypassword123" → "$2b$12$abc...xyz" (60 char hash)

// On login: compare
const isMatch = await bcrypt.compare(password, user.password);
// bcrypt re-hashes and compares → true or false
// Original password is NEVER stored
```

---

## 📦 Dependencies

### Flutter (pubspec.yaml):
```yaml
http: ^1.6.0        # Makes HTTP requests to backend
fl_chart: ^0.69.0   # Pie charts and bar charts
cupertino_icons     # iOS style icons
```

### Node.js (package.json):
```json
express        # Web server framework
mongoose       # MongoDB connection + models
jsonwebtoken   # JWT creation + verification
bcryptjs       # Password hashing
cors           # Allow Flutter to call the API
express-rate-limit  # Prevent brute force
crypto         # Generate random tokens (built-in Node.js)
```

---

## 🌐 API Endpoints Summary

| Method | Endpoint | Auth | What it does |
|--------|----------|------|--------------|
| POST | /register | ❌ | Create account |
| POST | /login | ❌ | Login, get token |
| POST | /forgot-password | ❌ | Request password reset |
| GET | /reset-password | ❌ | Show reset form |
| POST | /reset-password | ❌ | Submit new password |
| GET | /profile | ✅ | Get username + emoji |
| PUT | /profile | ✅ | Update username + emoji |
| GET | /habits | ✅ | Get all habits |
| POST | /habits | ✅ | Add new habit |
| PUT | /habits/:id | ✅ | Toggle done + update streak |
| DELETE | /habits/:id | ✅ | Delete habit |
| GET | /goals | ✅ | Get all goals |
| POST | /goals | ✅ | Add new goal |
| PUT | /goals/:id | ✅ | Toggle done |
| DELETE | /goals/:id | ✅ | Delete goal |
| GET | /moods | ✅ | Get all mood logs |
| POST | /moods | ✅ | Log a mood |
| GET | /daily-quote | ❌ | Get today's quote |

✅ = requires JWT token in Authorization header

---

## 🧠 Key Flutter Concepts Used

### StatefulWidget vs StatelessWidget
```dart
// StatelessWidget = no changing data, just displays
class _DashboardCard extends StatelessWidget { ... }

// StatefulWidget = has data that changes (setState)
class _HabitsScreenState extends State<HabitsScreen> {
  List _habits = [];  // this changes
  
  void _addHabit() {
    setState(() => _habits.add(...)); // triggers UI rebuild
  }
}
```

### initState — runs once when screen opens
```dart
@override
void initState() {
  super.initState();
  _loadHabits(); // fetch data from backend when screen opens
}
```

### Navigator — moving between screens
```dart
// Go to new screen (can go back)
Navigator.push(context, MaterialPageRoute(builder: (_) => HabitsScreen()));

// Replace current screen (can't go back)
Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginScreen()));

// Go to screen and clear all history
Navigator.pushAndRemoveUntil(context, route, (route) => false);
```

### async/await — waiting for backend response
```dart
Future<void> _loadHabits() async {
  final response = await http.get(...); // wait for response
  final data = jsonDecode(response.body); // parse JSON
  setState(() => _habits = data['habits']); // update UI
}
```

---

## 🎨 Design System

| Color | Used for |
|-------|----------|
| `Colors.teal` | Habits, AppBar, Login |
| `Colors.orange` | Mood |
| `Colors.purple` | Goals |
| `Colors.blue` | Profile (old card) |
| `Color(0xFFF5F7FA)` | Background (light grey) |

---

## ✅ Features Completed

| # | Feature | Status |
|---|---------|--------|
| 1 | Email verification | ✅ |
| 1 | Forgot password | ✅ |
| 2 | Password hashing (bcrypt) | ✅ |
| 3 | Habit streak counter | ✅ |
| 4 | Rate limiting | ✅ |
| 5 | Mood analytics chart | ✅ |
| 6 | Goal progress percentage | ✅ |
| 7 | Profile page with username | ✅ |
| 8 | Daily quote API | ✅ |
| 9 | Responsive layout | ✅ |
| 10 | Emoji avatar | ✅ |
| 11 | Random username on signup | ✅ |
| 12 | Login/signup notifications | ✅ |

---

*DailySync — Built with Flutter + Node.js + MongoDB*
