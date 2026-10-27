# Role-Based Access Control (RBAC) in Alma Roots (CS261-Project)

> **Target Audience:** Technical Interviewers & Software Engineers (Microsoft / Tier-1 Tech Preparation)  
> **Repository:** `Alma_Roots / CS261-Project` (Flutter, Cloud Firestore, Firebase Auth, Cloud Functions)  
> **Core Principle:** In this project, **Role-Based Access Control (RBAC)** is not merely a UI rendering filter; it is an **end-to-end, multi-layered security architecture** enforced at the Database Engine level, the Serverless Backend level, the Routing Dispatcher level, and the Client Presentation level.

---

# Table of Contents
1. [What RBAC Means in the Context of This Project](#1-what-rbac-means-in-the-context-of-this-project)
2. [Implemented Roles & Permissions Matrix](#2-implemented-roles--permissions-matrix)
3. [Layer 1: Database Engine RBAC (`firestore.rules`)](#3-layer-1-database-engine-rbac-firestorerules)
4. [Layer 2: Serverless Backend & Auth Custom Claims (`functions/index.js`)](#4-layer-2-serverless-backend--auth-custom-claims-functionsindexjs)
5. [Layer 3: Dynamic Application Routing (`UserRoleDispatcher`)](#5-layer-3-dynamic-application-routing-userroledispatcher)
6. [Layer 4: UI Experience & Screen Workflows](#6-layer-4-ui-experience--screen-workflows)
7. [Automated Verification: RBAC Unit Tests (`firestore.test.js`)](#7-automated-verification-rbac-unit-tests-firestoretestjs)
8. [Why RBAC Was Essential in This Application](#8-why-rbac-was-essential-in-this-application)
9. [Interview Explanation: How to Explain RBAC in an Interview](#9-interview-explanation-how-to-explain-rbac-in-an-interview)
10. [Quick Codebase Reference Map](#10-quick-codebase-reference-map)

---

# 1. What RBAC Means in the Context of This Project

In the **Alma Roots** campus networking platform, users belong to specific collegiate institutions (`institutes/{instId}`) and are assigned distinct institutional responsibilities:

```
                          ┌──────────────────────────┐
                          │   Global Super Admin     │ (Platform Root)
                          └─────────────┬────────────┘
                                        │ (Manages Institutes)
                                        ▼
             ┌──────────────────────────────────────────────────────┐
             │            Tenant Institute Scope (instId)           │
             └───────┬──────────────────┬────────────────────┬──────┘
                     │                  │                    │
                     ▼                  ▼                    ▼
             ┌───────────────┐  ┌───────────────┐    ┌───────────────┐
             │     Admin     │  │    Alumni     │    │    Student    │
             └───────┬───────┘  └───────┬───────┘    └───────┬───────┘
                     │                  │                    │
                     └──────────────────┼────────────────────┘
                                        │
                                        ▼ (If Suspended / Deleted)
                                ┌───────────────┐
                                │  Deactivated  │
                                └───────────────┘
```

### The 4-Layer Defense-in-Depth Model

```
┌────────────────────────────────────────────────────────────────────────┐
│ 1. Database Gateway (firestore.rules)                                  │
│    Enforces RBAC invariants directly on storage reads/writes           │
├────────────────────────────────────────────────────────────────────────┤
│ 2. Backend Functions (functions/index.js)                              │
│    Verifies Firebase Auth Custom Claims (`auth.token.role === 'admin'`)│
├────────────────────────────────────────────────────────────────────────┤
│ 3. Navigation Dispatcher (UserRoleDispatcher)                          │
│    Routes authenticated session to role-specific root screen           │
├────────────────────────────────────────────────────────────────────────┤
│ 4. Client Presentation (Flutter Widgets)                               │
│    Conditionally renders forms, action tiles, tabs, and visibility     │
└────────────────────────────────────────────────────────────────────────┘
```

1. **Database Gateway Layer:** [firestore.rules](file:///c:/Flutter_projects/new_cs/CS261-Project/firestore.rules) rejects unauthorized reads, writes, and privilege escalation attempts at the database gateway, even if the client app is compromised or bypassed via cURL/Postman.
2. **Backend Execution Layer:** [functions/index.js](file:///c:/Flutter_projects/new_cs/CS261-Project/functions/index.js) cryptographically validates administrative privileges via Firebase Auth Custom Claims (`auth.token.role === 'admin'`) before provisioning accounts or triggering user purging.
3. **Application Routing Layer:** [UserRoleDispatcher](file:///c:/Flutter_projects/new_cs/CS261-Project/lib/service/user_role_dispatcher.dart) resolves the participant profile upon launch and branches the user into either the `AdminHomeScreen`, `UserHomeScreen`, or `AccountDeactivatedScreen`.
4. **Presentation Layer:** Screens dynamically adapt their tabs, form options, and data feeds based on whether the logged-in user is a Student, Alumni, or Administrator.

---

# 2. Implemented Roles & Permissions Matrix

The codebase explicitly defines and checks five distinct user states:

1. **`student`**: Current undergraduate/postgraduate students focusing on campus news, networking, peer interaction, job discovery, and event RSVPs.
2. **`alumni`**: Graduated alumni focusing on sharing industry experiences, offering mentorship, posting hiring opportunities, and networking.
3. **`admin`**: Institute-level administrators who manage students/alumni, approve reactivation requests, publish official campus news, pin critical notices, oversee deletion queues, and monitor bug reports.
4. **`deactivated` / `suspended`**: Accounts that have been soft-deleted (`isDeleted: true` or `status: 'deleted'`). Stripped of all data access; strictly confined to account recovery.
5. **`super_admin`**: Top-level platform administrators with write privileges on the root `/institutes` collection.

---

### Granular Permission Matrix

| Operation / Resource | Student | Alumni | Admin | Deactivated User | Code Verification |
| :--- | :---: | :---: | :---: | :---: | :--- |
| **Login / Read Own Profile** | ✅ | ✅ | ✅ | ❌ *(Redirected to Deactivated)* | [user_role_dispatcher.dart#L58-L63](file:///c:/Flutter_projects/new_cs/CS261-Project/lib/service/user_role_dispatcher.dart#L58-L63) |
| **Search Active Institute Members** | ✅ | ✅ | ✅ | ❌ | [firestore.rules#L44](file:///c:/Flutter_projects/new_cs/CS261-Project/firestore.rules#L44) |
| **Edit Own Profile Bio / Skills** | ✅ | ✅ | ✅ | ❌ | [firestore.rules#L46-L53](file:///c:/Flutter_projects/new_cs/CS261-Project/firestore.rules#L46-L53) |
| **Promote Self to Admin / Change Role** | ❌ | ❌ | ❌ *(Via Cloud Function only)* | ❌ | [firestore.rules#L49](file:///c:/Flutter_projects/new_cs/CS261-Project/firestore.rules#L49) |
| **Create Student / Alumni Accounts** | ❌ | ❌ | ✅ | ❌ | [functions/index.js#L15](file:///c:/Flutter_projects/new_cs/CS261-Project/functions/index.js#L15) |
| **Soft Delete / Restore Users** | ❌ | ❌ | ✅ | ❌ | [admin_service.dart#L27](file:///c:/Flutter_projects/new_cs/CS261-Project/lib/service/admin_service.dart#L27) |
| **Schedule Permanent User Purge** | ❌ | ❌ | ✅ | ❌ | [admin_service.dart#L222](file:///c:/Flutter_projects/new_cs/CS261-Project/lib/service/admin_service.dart#L222) |
| **Review Account Reactivation Requests** | ❌ | ❌ | ✅ | ❌ | [firestore.rules#L147-L149](file:///c:/Flutter_projects/new_cs/CS261-Project/firestore.rules#L147-L149) |
| **Submit Account Reactivation Request** | ❌ | ❌ | ❌ | ✅ | [firestore.rules#L146](file:///c:/Flutter_projects/new_cs/CS261-Project/firestore.rules#L146) |
| **Post "Experience" / "Achievement"** | ✅ | ✅ | ✅ | ❌ | [firestore.rules#L67](file:///c:/Flutter_projects/new_cs/CS261-Project/firestore.rules#L67) |
| **Post "Event" / "Hackathon"** | ✅ | ✅ | ✅ | ❌ | [firestore.rules#L67](file:///c:/Flutter_projects/new_cs/CS261-Project/firestore.rules#L67) |
| **Post Official "News" / "Announcement"** | ❌ | ❌ | ✅ | ❌ | [firestore.rules#L67](file:///c:/Flutter_projects/new_cs/CS261-Project/firestore.rules#L67) |
| **Pin Post to Top of Campus Feed** | ❌ | ❌ | ✅ | ❌ | [news_event_screen.dart#L719](file:///c:/Flutter_projects/new_cs/CS261-Project/lib/screen/events_and_news/news_event_screen.dart#L719) |
| **View `admins_only` Visibility Posts** | ❌ | ❌ | ✅ | ❌ | [news_event_screen.dart#L94](file:///c:/Flutter_projects/new_cs/CS261-Project/lib/screen/events_and_news/news_event_screen.dart#L94) |
| **View `alumni_only` Visibility Posts** | ❌ | ✅ | ✅ | ❌ | [news_event_screen.dart#L95](file:///c:/Flutter_projects/new_cs/CS261-Project/lib/screen/events_and_news/news_event_screen.dart#L95) |
| **View `students_only` Visibility Posts** | ✅ | ❌ | ✅ | ❌ | [news_event_screen.dart#L96](file:///c:/Flutter_projects/new_cs/CS261-Project/lib/screen/events_and_news/news_event_screen.dart#L96) |
| **RSVP / Waitlist for Events** | ✅ | ✅ | ✅ | ❌ | [news_event_service.dart#L102](file:///c:/Flutter_projects/new_cs/CS261-Project/lib/service/news_event_service.dart#L102) |
| **Send 1:1 Direct Messages** | ✅ | ✅ | ✅ | ❌ | [chat_service.dart#L70](file:///c:/Flutter_projects/new_cs/CS261-Project/lib/service/chat_service.dart#L70) |
| **Read Other Users' Direct Chats** | ❌ | ❌ | ❌ *(Strict Privacy)* | ❌ | [firestore.rules#L110](file:///c:/Flutter_projects/new_cs/CS261-Project/firestore.rules#L110) |
| **Read / View Audit Logs (`admin_actions`)** | ❌ | ❌ | ✅ | ❌ | [firestore.rules#L132](file:///c:/Flutter_projects/new_cs/CS261-Project/firestore.rules#L132) |
| **Modify / Delete Audit Logs** | ❌ | ❌ | ❌ *(Immutable)* | ❌ | [firestore.rules#L135](file:///c:/Flutter_projects/new_cs/CS261-Project/firestore.rules#L135) |

---

# 3. Layer 1: Database Engine RBAC (`firestore.rules`)

The primary gatekeeper is the declarative engine configured in [firestore.rules](file:///c:/Flutter_projects/new_cs/CS261-Project/firestore.rules).

### 1. Core RBAC Helper Functions ([firestore.rules#L8-L29](file:///c:/Flutter_projects/new_cs/CS261-Project/firestore.rules#L8-L29))
```javascript
function isAuthed() { 
  return request.auth != null; 
}

function getParticipant(instId) {
  let uid = request.auth != null ? request.auth.uid : 'null_uid';
  let pDoc = /databases/$(database)/documents/institutes/$(instId)/participants/$(uid);
  return exists(pDoc) ? get(pDoc).data : {};
}

function isInstituteMember(instId) {
  return isAuthed() && exists(/databases/$(database)/documents/institutes/$(instId)/participants/$(request.auth.uid));
}

function isActiveMember(instId) {
  let participant = getParticipant(instId);
  return isInstituteMember(instId) && participant.get('status', 'active') == 'active';
}

function isAdmin(instId) {
  let participant = getParticipant(instId);
  return isInstituteMember(instId) && participant.get('role', '') == 'admin';
}
```
* **Architectural Insight:** Every helper dynamically inspects the caller's participant document in their current institute tenant. If an admin from Institute A attempts an operation on Institute B, `isAdmin(instId)` evaluates to `false` because they do not have a participant record with `role == 'admin'` under Institute B.

---

### 2. Privilege Escalation Prevention ([firestore.rules#L46-L56](file:///c:/Flutter_projects/new_cs/CS261-Project/firestore.rules#L46-L56))
```javascript
match /participants/{userId} {
  allow read: if request.auth.uid == userId || isActiveMember(instId) || isAdmin(instId);
  
  allow update: if isAdmin(instId) || (
    request.auth.uid == userId && isActiveMember(instId) &&
    // PREVENT PRIVILEGE ESCALATION
    request.resource.data.get('role', resource.data.get('role', 'student')) == resource.data.get('role', 'student') &&
    request.resource.data.get('status', resource.data.get('status', 'active')) == resource.data.get('status', 'active') &&
    request.resource.data.get('isDeleted', resource.data.get('isDeleted', false)) == resource.data.get('isDeleted', false) &&
    request.resource.data.get('instituteId', resource.data.get('instituteId', instId)) == resource.data.get('instituteId', instId)
  );

  allow create, delete: if isAdmin(instId);
}
```
* **Anti-Tampering Rule:** A student updating their profile can change their `name`, `bio`, or `department`. However, if their update payload attempts to modify `role` (`student` $\to$ `admin`), `status` (`active` $\to$ anything else), `isDeleted`, or `instituteId`, the condition fails and Firestore terminates the write.

---

### 3. Role-Gated Post Creation ([firestore.rules#L64-L69](file:///c:/Flutter_projects/new_cs/CS261-Project/firestore.rules#L64-L69))
```javascript
match /posts/{postId} {
  allow create: if isActiveMember(instId) && 
    request.resource.data.get('authorUid', '') == request.auth.uid && (
      isAdmin(instId) ||
      (getParticipant(instId).get('role', '') in ['student', 'alumni'] && request.resource.data.get('type', '') in ['experience', 'event'])
    );
```
* **Differentiation:** Active Students and Alumni are strictly limited to posting `experience` or `event` types. Only accounts with `role == 'admin'` are permitted to publish official `news`.

---

### 4. Zero-Trust Chat Privacy: Admins Cannot Snoop ([firestore.rules#L109-L126](file:///c:/Flutter_projects/new_cs/CS261-Project/firestore.rules#L109-L126))
```javascript
match /chats/{chatId} {
  // Only the two participants in the array can read the chat
  allow read: if isActiveMember(instId) && request.auth.uid in resource.data.get('participants', []);
  
  // Direct chats require exactly 2 participants, and the caller must be one of them
  allow create: if isActiveMember(instId) && 
                request.resource.data.get('participants', []).size() == 2 &&
                request.auth.uid in request.resource.data.get('participants', []);
```
* **Privacy by Design:** Unlike posts and participant directories where `isAdmin(instId)` grants administrative visibility, the chat rules **deliberately omit `isAdmin(instId)`**. An admin cannot read direct messages between students unless the admin is an explicit party to the conversation.

---

### 5. Audit Log Immutability ([firestore.rules#L131-L136](file:///c:/Flutter_projects/new_cs/CS261-Project/firestore.rules#L131-L136))
```javascript
match /admin_actions/{docId} { 
  allow read: if isAdmin(instId);
  allow create: if isAdmin(instId) && request.resource.data.get('adminUid', '') == request.auth.uid;
  allow update, delete: if false; // Audit logs should be immutable
}
```
* **Compliance Assurance:** Audit trail records cannot be edited or deleted by anyone—not even administrators.

---

# 4. Layer 2: Serverless Backend & Auth Custom Claims (`functions/index.js`)

Certain administrative workflows require elevated system privileges that should never be executed from a mobile client. These are deployed as Cloud Functions v2 in [functions/index.js](file:///c:/Flutter_projects/new_cs/CS261-Project/functions/index.js).

### 1. Cryptographic Custom Claims Verification ([functions/index.js#L14-L16](file:///c:/Flutter_projects/new_cs/CS261-Project/functions/index.js#L14-L16))
```javascript
exports.createParticipantAccount = onCall(
  { region: "asia-south1" },
  async (request) => {
    const { data, auth } = request;
    if (!auth) throw new HttpsError("unauthenticated", "You must be logged in to create participants.");
    if (auth.token.role !== "admin") throw new HttpsError("permission-denied", "Only admins can create participants.");
```
* **How it Works:** The backend inspects the cryptographically signed JWT token (`auth.token.role`). If the token does not contain `{ role: "admin" }`, the request is aborted immediately before running any business logic.

---

### 2. Admin Claim Issuance ([functions/index.js#L121-L124](file:///c:/Flutter_projects/new_cs/CS261-Project/functions/index.js#L121-L124))
```javascript
// If admin role, assign admin claim
if (role === "admin") {
  await admin.auth().setCustomUserClaims(uid, { role: "admin" });
}
```
* When an administrator provisions a new administrative colleague, the backend embeds `{ role: "admin" }` directly inside Firebase Auth's JWT token, allowing both Cloud Functions and client-side SDKs to recognize the user's elevated role.

---

### 3. Server-Side Firestore Role Verification ([functions/index.js#L286-L291](file:///c:/Flutter_projects/new_cs/CS261-Project/functions/index.js#L286-L291))
```javascript
// Ensure caller is an admin by checking Firestore
const callerRef = db.collection("institutes").doc(instituteId).collection("participants").doc(auth.uid);
const callerSnap = await callerRef.get();
if (!callerSnap.exists || callerSnap.data().role !== "admin") {
  throw new HttpsError("permission-denied", "Only admins can process the deletion queue.");
}
```
* **Defense in Depth:** In `processDeletionQueueNow`, the function performs a second lookup directly against the caller's Firestore document to ensure an admin whose account was recently revoked cannot invoke background workers using an unexpired JWT.

---

# 5. Layer 3: Dynamic Application Routing (`UserRoleDispatcher`)

When a user opens the app, the session must resolve their role before rendering any UI. This routing switchboard is implemented in [lib/service/user_role_dispatcher.dart](file:///c:/Flutter_projects/new_cs/CS261-Project/lib/service/user_role_dispatcher.dart).

```
                        [ User Authenticates ]
                                   │
                                   ▼
                       [ UserRoleDispatcher ]
                                   │
                     Fetch `/participants/{uid}`
                                   │
        ┌──────────────────────────┼──────────────────────────┐
        │                          │                          │
        ▼                          ▼                          ▼
 [ isDeleted / deleted ]    [ role == 'admin' ]       [ student / alumni ]
        │                          │                          │
        ▼                          ▼                          ▼
┌───────────────────────┐  ┌───────────────────────┐  ┌───────────────────────┐
│AccountDeactivatedScreen│  │    AdminHomeScreen    │  │    UserHomeScreen     │
│(Submit Reactivation)  │  │ (Admin Mgmt Console)  │  │(5-Tab Campus Network) │
└───────────────────────┘  └───────────────────────┘  └───────────────────────┘
```

### The Core Dispatcher Code ([lib/service/user_role_dispatcher.dart#L43-L101](file:///c:/Flutter_projects/new_cs/CS261-Project/lib/service/user_role_dispatcher.dart#L43-L101))
```dart
final doc = await _firestore
    .collection('institutes')
    .doc(widget.instituteId)
    .collection('participants')
    .doc(user.uid)
    .get();

if (!doc.exists) {
  await _auth.signOut();
  return;
}

// 1. Check for account suspension / soft deletion
if (doc.data()?['isDeleted'] == true || doc.data()?['status'] == 'deleted') {
  _role = 'deactivated';
  _participantData = doc.data();
  return;
}

// 2. Resolve Role
_role = doc['role'] ?? 'student';

// 3. Render Role-Specific Root Screen
switch (_role) {
  case 'deactivated':
    return AccountDeactivatedScreen(
      instituteId: widget.instituteId,
      participantData: _participantData ?? {},
    );
  case 'admin':
    return AdminHomeScreen(instituteId: widget.instituteId);
  case 'student':
  case 'alumni':
  default:
    return UserHomeScreen(instituteId: widget.instituteId);
}
```

---

# 6. Layer 4: UI Experience & Screen Workflows

### 1. Root Screen Divergence: `AdminHomeScreen` vs `UserHomeScreen`

#### The Admin Experience ([lib/screen/admin/admin_home_screen.dart](file:///c:/Flutter_projects/new_cs/CS261-Project/lib/screen/admin/admin_home_screen.dart))
Admins do not see the standard social navigation bar. Instead, they are presented with an **Executive Management Console**:
* **Add User:** Provision new students, alumni, or fellow administrators ([admin_add_user_screen.dart](file:///c:/Flutter_projects/new_cs/CS261-Project/lib/screen/admin/admin_add_user_screen.dart)).
* **Manage Users:** Full participant directory with buttons to soft-delete, restore, or schedule permanent deletion ([admin_participant_list_screen.dart](file:///c:/Flutter_projects/new_cs/CS261-Project/lib/screen/admin/admin_participant_list_screen.dart)).
* **Reactivations:** Review pending requests submitted by suspended users and approve or reject them ([admin_reactivation_requests_screen.dart](file:///c:/Flutter_projects/new_cs/CS261-Project/lib/screen/admin/admin_reactivation_requests_screen.dart)).
* **Deletion Queue:** Monitor users scheduled for permanent purging and cancel or trigger immediate execution ([admin_deletion_queue_screen.dart](file:///c:/Flutter_projects/new_cs/CS261-Project/lib/screen/admin/admin_deletion_queue_screen.dart)).
* **Feedback Reports:** Read and resolve student bug reports ([admin_feedback_screen.dart](file:///c:/Flutter_projects/new_cs/CS261-Project/lib/screen/admin/admin_feedback_screen.dart)).
* **Fix Search Index:** Trigger batch re-indexing migration scripts ([SearchMigrationService](file:///c:/Flutter_projects/new_cs/CS261-Project/lib/service/search_migration_service.dart)).

#### The Student / Alumni Experience ([lib/screen/student/user_home_screen.dart](file:///c:/Flutter_projects/new_cs/CS261-Project/lib/screen/student/user_home_screen.dart))
Students and Alumni receive a social networking interface with a 5-destination bottom navigation bar:
1. **Home:** Main announcements and campus overview.
2. **Search:** Peer directory with role filters.
3. **News & Events:** Live news feed, workshop discovery, and RSVP ticketing.
4. **Profile:** Personal portfolio, resume information, and mentorship tags.
5. **Inbox:** Direct 1-on-1 real-time messaging.

---

### 2. Post Creation & Pinning Restrictions (`CreatePostModal`)

In [lib/screen/events_and_news/news_event_screen.dart#L683-L728](file:///c:/Flutter_projects/new_cs/CS261-Project/lib/screen/events_and_news/news_event_screen.dart#L683-L728), the modal dynamically renders post types and pinning controls based on role:

```dart
DropdownButtonFormField<String>(
  value: _uiPostType,
  items: [
    const DropdownMenuItem(value: 'Experience', child: Text('Experience')),
    const DropdownMenuItem(value: 'Achievement', child: Text('Achievement')),
    const DropdownMenuItem(value: 'Internship', child: Text('Internship')),
    const DropdownMenuItem(value: 'Job Opportunity', child: Text('Job Opportunity')),
    const DropdownMenuItem(value: 'Mentorship', child: Text('Mentorship')),
    const DropdownMenuItem(value: 'Research', child: Text('Research')),
    const DropdownMenuItem(value: 'Career Guidance', child: Text('Career Guidance')),
    const DropdownMenuItem(value: 'Event', child: Text('Event')),
    const DropdownMenuItem(value: 'Hackathon', child: Text('Hackathon')),
    const DropdownMenuItem(value: 'Workshop', child: Text('Workshop')),
    // RESTRICTED TO ADMINS ONLY
    if (isAdmin) const DropdownMenuItem(value: 'News', child: Text('News')),
    if (isAdmin) const DropdownMenuItem(value: 'Announcement', child: Text('Announcement')),
  ],
  onChanged: (val) => setState(() => _uiPostType = val!),
)

// PINNING CONTROL (RESTRICTED TO ADMINS)
if (isAdmin && _typeMapping[_uiPostType]!['type'] == 'news') ...[
  SwitchListTile(
    title: const Text('Pin to top'),
    subtitle: const Text('Show this post at the top of the feed'),
    value: _isPinned,
    onChanged: (val) => setState(() => _isPinned = val),
  ),
]
```

---

### 3. Feed Visibility Filtering

In [lib/screen/events_and_news/news_event_screen.dart#L92-L98](file:///c:/Flutter_projects/new_cs/CS261-Project/lib/screen/events_and_news/news_event_screen.dart#L92-L98), campus posts are filtered on the client before being displayed:

```dart
posts = posts.where((p) {
  if (p.visibility == 'public') return true;
  if (p.visibility == 'admins_only' && _userRole == 'admin') return true;
  if (p.visibility == 'alumni_only' && (_userRole == 'alumni' || _userRole == 'admin')) return true;
  if (p.visibility == 'students_only' && (_userRole == 'student' || _userRole == 'admin')) return true;
  return false;
}).toList();
```
* **Student View:** Sees `public` and `students_only` posts.
* **Alumni View:** Sees `public` and `alumni_only` posts (e.g., alumni reunion notices or senior hiring discussions).
* **Admin View:** Possesses superset visibility across all categories.

---

### 4. Profile Editing Differences (Student vs Alumni vs Admin)

In [lib/screen/profile/profile_edit_screen.dart#L113-L117](file:///c:/Flutter_projects/new_cs/CS261-Project/lib/screen/profile/profile_edit_screen.dart#L113-L117), fields adapt to the user's role:

```dart
// Student & Admin fields
if (_role == 'student' || _role == 'admin') 'rollNo': rollCtrl.text.trim(),

// Student & Alumni fields (Graduation Year)
if (_role != 'admin') 'year': yearCtrl.text.trim(),

// Alumni-Specific fields
if (_role == 'alumni') 'company': companyCtrl.text.trim(),
```
* **Labels:** Alumni are asked for **"Areas of Expertise"** while students are asked for **"Interests & Skills"** ([profile_edit_screen.dart#L336](file:///c:/Flutter_projects/new_cs/CS261-Project/lib/screen/profile/profile_edit_screen.dart#L336)).
* **Profile Display:** Alumni cards showcase their current corporate employer and mentorship flags (`isMentor`, `isHiring`), whereas students display their graduation year and department ([profile_screen.dart#L237-L242](file:///c:/Flutter_projects/new_cs/CS261-Project/lib/screen/profile/profile_screen.dart#L237-L242)).

---

### 5. Peer Search & Messaging Filters

In [lib/screen/message/start_conversation_screen.dart#L81-L89](file:///c:/Flutter_projects/new_cs/CS261-Project/lib/screen/message/start_conversation_screen.dart#L81-L89):
* Users can filter peers by quick chips: `Students`, `Alumni`, `Admins`, `Mentors`, `Hiring`, and `Networking`.
* Structured networking intros automatically format intro messages using the sender's role:
  ```dart
  "• Role: ${_myProfile.role.toUpperCase()}"
  ```

---

# 7. Automated Verification: RBAC Unit Tests (`firestore.test.js`)

The project includes an automated test suite ([firestore.test.js](file:///c:/Flutter_projects/new_cs/CS261-Project/firestore.test.js)) utilizing `@firebase/rules-unit-testing` to ensure that RBAC rules are regression-tested against a local Firestore emulator.

```javascript
describe("Firestore Security Rules", () => {
  // Test 1: Student can read their own profile
  it("Student Login (can read their own profile)", async () => {
    const db = testEnv.authenticatedContext('student_uid').firestore();
    await assertSucceeds(db.collection('institutes').doc('test_inst').collection('participants').doc('student_uid').get());
  });

  // Test 2: Student cannot read another user's private direct chats
  it("Student Messaging (cannot read others' chat)", async () => {
    const db = testEnv.authenticatedContext('student_uid').firestore();
    await assertFails(db.collection('institutes').doc('test_inst').collection('chats').doc('chat2').get());
  });

  // Test 3: Student CANNOT escalate role to admin
  it("Student Profile edit (cannot change role)", async () => {
    const db = testEnv.authenticatedContext('student_uid').firestore();
    await assertFails(db.collection('institutes').doc('test_inst').collection('participants').doc('student_uid').update({
      role: 'admin'
    }));
  });

  // Test 4: Student cannot access audit logs
  it("Student Cannot access admin screens (admin_actions)", async () => {
    const db = testEnv.authenticatedContext('student_uid').firestore();
    await assertFails(db.collection('institutes').doc('test_inst').collection('admin_actions').get());
  });

  // Test 5: Alumni CAN create an experience post
  it("Alumni Create experience", async () => {
    const db = testEnv.authenticatedContext('alumni_uid').firestore();
    await assertSucceeds(db.collection('institutes').doc('test_inst').collection('posts').doc('post1').set({
      authorUid: 'alumni_uid',
      type: 'experience'
    }));
  });

  // Test 6: Alumni CANNOT create official campus news
  it("Alumni Cannot create news", async () => {
    const db = testEnv.authenticatedContext('alumni_uid').firestore();
    await assertFails(db.collection('institutes').doc('test_inst').collection('posts').doc('post2').set({
      authorUid: 'alumni_uid',
      type: 'news'
    }));
  });

  // Test 7: Admin CAN create official campus news
  it("Admin News creation", async () => {
    const db = testEnv.authenticatedContext('admin_uid').firestore();
    await assertSucceeds(db.collection('institutes').doc('test_inst').collection('posts').doc('post4').set({
      authorUid: 'admin_uid',
      type: 'news'
    }));
  });

  // Test 8: Admin CAN soft-delete a student
  it("Admin Soft delete", async () => {
    const db = testEnv.authenticatedContext('admin_uid').firestore();
    await assertSucceeds(db.collection('institutes').doc('test_inst').collection('participants').doc('student_uid').update({
      isDeleted: true,
      status: 'deleted'
    }));
  });
});
```

---

# 8. Why RBAC Was Essential in This Application

1. **Institutional Integrity & Fake News Prevention:**  
   If students or alumni could post official campus news or pin posts to the top of the feed, malicious actors could announce false examination schedules, fake holidays, or unauthorized recruitment events. Restricting `news` and `isPinned` to administrators preserves campus authority.
2. **Student Privacy & Trust:**  
   Collegiate platforms contain sensitive communications (mentorship discussions, job inquiries, personal direct messages). By enforcing zero-trust chat rules, administrators are prevented from reading private 1-on-1 messages between students and alumni.
3. **Privilege Escalation Protection:**  
   In mobile apps, API endpoints can be inspected or called directly. Without database-level anti-escalation checks (`request.resource.data.role == resource.data.role`), any student with an HTTP client could change their own role to `admin` and seize control of the institute's user directory.
4. **Tailored User Experiences:**  
   Alumni require a platform to mentor and recruit; students need a platform to learn, discover hackathons, and connect with seniors; administrators require compliance tooling and audit logs. RBAC allows a single mobile codebase to deliver three tailored experiences without UI clutter.

---

# 9. Interview Explanation: How to Explain RBAC in an Interview

### 1. 60-Second Elevator Pitch
> *"In our Flutter campus application, Alma Roots, we implemented a 4-layer Role-Based Access Control architecture covering Students, Alumni, and Administrators across isolated tenant institutes.*
> 
> *At the presentation layer, our `UserRoleDispatcher` routes administrators to a dedicated Management Console while routing students and alumni to a 5-tab social networking interface. Form controls dynamically adapt: alumni can showcase their corporate employers and mentorship flags, students provide their academic years, and only administrators are given options to publish official campus news or pin announcements.*
> 
> *Critically, we treated client-side checks as pure UX convenience and enforced zero-trust authorization at the database gateway using Firestore Security Rules. Our rules prevent privilege escalation by rejecting any profile update where the proposed `role` does not match the existing document. We also enforced strict privacy boundaries: while admins manage user accounts and audit logs, our security rules explicitly forbid administrators from reading direct 1-on-1 student messages unless they are an active party in the chat.*
> 
> *Finally, sensitive operations like account creation and permanent purging are executed through Cloud Functions that cryptographically verify Firebase Auth Custom Claims."*

---

### 2. Likely Follow-Up Questions & Code-Backed Answers

#### Q: "What prevents a malicious student from intercepting the network traffic and sending `role: 'admin'` in their profile update?"
> *"Our database gateway rejects it. In `firestore.rules` under `/participants/{userId}`, we wrote an explicit anti-escalation condition:*
> ```javascript
> request.resource.data.get('role', resource.data.get('role', 'student')) == resource.data.get('role', 'student')
> ```
> *This ensures that `request.resource.data` (the proposed incoming data) must have the exact same role as `resource.data` (the existing data currently in the database). Even if the student modifies the Flutter APK or uses a tool like Postman, the database engine returns a `PERMISSION_DENIED` error and discards the write."*

#### Q: "Why use both Firestore Security Rules and Cloud Functions for RBAC?"
> *"They solve two different security challenges. Firestore Security Rules protect direct client database operations with zero latency overhead. However, certain workflows—such as creating a user with an email and password in Firebase Authentication, setting custom user claims, or executing cross-collection cascading deletions—require administrative SDK access that cannot and should not be granted directly to mobile clients. Cloud Functions act as our trusted serverless backend, verifying `auth.token.role === 'admin'` before running privileged administrative scripts."*

#### Q: "Can an institute administrator read private direct messages between two students?"
> *"No. In our `firestore.rules` for `/chats/{chatId}`, we intentionally did NOT include `isAdmin(instId)`. The read rule states:*
> ```javascript
> allow read: if isActiveMember(instId) && request.auth.uid in resource.data.get('participants', []);
> ```
> *An admin can only read a chat if their own Auth UID is one of the two elements in the `participants` array. This guarantees student privacy by design."*

#### Q: "How do you handle suspended or deactivated accounts?"
> *"When an admin soft-deletes a user, we set `isDeleted: true` and `status: 'deleted'`. When that user opens the app, `UserRoleDispatcher` detects this flag and routes them directly to `AccountDeactivatedScreen`, cutting off access to the feed, chats, and directory. At the database layer, our rules helper `isActiveMember(instId)` requires `participant.get('status', 'active') == 'active'`, meaning all subsequent read/write requests to posts, comments, and chats fail immediately at the gateway. The user can only write to `/reactivation_requests/{uid}` to petition the admin for recovery."*

---

# 10. Quick Codebase Reference Map

| Component / Layer | Source File Path | Key Functions / Classes / Lines |
| :--- | :--- | :--- |
| **Security Rules (DB Engine)** | [firestore.rules](file:///c:/Flutter_projects/new_cs/CS261-Project/firestore.rules) | `isAdmin()`, `isActiveMember()`, `allow update` anti-escalation ([L46-L53](file:///c:/Flutter_projects/new_cs/CS261-Project/firestore.rules#L46-L53)) |
| **Automated RBAC Tests** | [firestore.test.js](file:///c:/Flutter_projects/new_cs/CS261-Project/firestore.test.js) | Test suite asserting permissions and failures per role ([L48-L150](file:///c:/Flutter_projects/new_cs/CS261-Project/firestore.test.js#L48-L150)) |
| **Serverless Admin Functions** | [functions/index.js](file:///c:/Flutter_projects/new_cs/CS261-Project/functions/index.js) | `createParticipantAccount` ([L9](file:///c:/Flutter_projects/new_cs/CS261-Project/functions/index.js#L9)), `addAdminRole` ([L164](file:///c:/Flutter_projects/new_cs/CS261-Project/functions/index.js#L164)), `processDeletionQueueNow` ([L274](file:///c:/Flutter_projects/new_cs/CS261-Project/functions/index.js#L274)) |
| **Role Routing Switchboard** | [user_role_dispatcher.dart](file:///c:/Flutter_projects/new_cs/CS261-Project/lib/service/user_role_dispatcher.dart) | `UserRoleDispatcher` ([L9](file:///c:/Flutter_projects/new_cs/CS261-Project/lib/service/user_role_dispatcher.dart#L9)), role switch routing ([L88-L101](file:///c:/Flutter_projects/new_cs/CS261-Project/lib/service/user_role_dispatcher.dart#L88-L101)) |
| **Admin Service (CRUD)** | [admin_service.dart](file:///c:/Flutter_projects/new_cs/CS261-Project/lib/service/admin_service.dart) | `softDeleteUser` ([L9](file:///c:/Flutter_projects/new_cs/CS261-Project/lib/service/admin_service.dart#L9)), `restoreUser` ([L59](file:///c:/Flutter_projects/new_cs/CS261-Project/lib/service/admin_service.dart#L59)), `schedulePermanentDeletion` ([L205](file:///c:/Flutter_projects/new_cs/CS261-Project/lib/service/admin_service.dart#L205)) |
| **Admin Console UI** | [admin_home_screen.dart](file:///c:/Flutter_projects/new_cs/CS261-Project/lib/screen/admin/admin_home_screen.dart) | `AdminHomeScreen` ([L15](file:///c:/Flutter_projects/new_cs/CS261-Project/lib/screen/admin/admin_home_screen.dart#L15)), `_buildActionsGrid` ([L113](file:///c:/Flutter_projects/new_cs/CS261-Project/lib/screen/admin/admin_home_screen.dart#L113)) |
| **Student / Alumni UI** | [user_home_screen.dart](file:///c:/Flutter_projects/new_cs/CS261-Project/lib/screen/student/user_home_screen.dart) | `UserHomeScreen` ([L14](file:///c:/Flutter_projects/new_cs/CS261-Project/lib/screen/student/user_home_screen.dart#L14)), 5-tab navigation bar ([L81-L100](file:///c:/Flutter_projects/new_cs/CS261-Project/lib/screen/student/user_home_screen.dart#L81-L100)) |
| **Post Creation Modal** | [news_event_screen.dart](file:///c:/Flutter_projects/new_cs/CS261-Project/lib/screen/events_and_news/news_event_screen.dart) | `CreatePostModal` ([L497](file:///c:/Flutter_projects/new_cs/CS261-Project/lib/screen/events_and_news/news_event_screen.dart#L497)), role-gated news & pin switch ([L683-L728](file:///c:/Flutter_projects/new_cs/CS261-Project/lib/screen/events_and_news/news_event_screen.dart#L683-L728)) |
| **Feed Visibility Filter** | [news_event_screen.dart](file:///c:/Flutter_projects/new_cs/CS261-Project/lib/screen/events_and_news/news_event_screen.dart) | `_buildFeed` role visibility logic ([L92-L98](file:///c:/Flutter_projects/new_cs/CS261-Project/lib/screen/events_and_news/news_event_screen.dart#L92-L98)) |
| **Profile Editing Form** | [profile_edit_screen.dart](file:///c:/Flutter_projects/new_cs/CS261-Project/lib/screen/profile/profile_edit_screen.dart) | `ProfileEditScreen` ([L32](file:///c:/Flutter_projects/new_cs/CS261-Project/lib/screen/profile/profile_edit_screen.dart#L32)), role-specific company/rollNo inputs ([L113-L117](file:///c:/Flutter_projects/new_cs/CS261-Project/lib/screen/profile/profile_edit_screen.dart#L113-L117)) |
| **Peer Search & Filtering** | [start_conversation_screen.dart](file:///c:/Flutter_projects/new_cs/CS261-Project/lib/screen/message/start_conversation_screen.dart) | Role filter chips & intro generator ([L81-L89](file:///c:/Flutter_projects/new_cs/CS261-Project/lib/screen/message/start_conversation_screen.dart#L81-L89), [L240-L245](file:///c:/Flutter_projects/new_cs/CS261-Project/lib/screen/message/start_conversation_screen.dart#L240-L245)) |
| **Account Deactivation Screen** | [account_deactivated_screen.dart](file:///c:/Flutter_projects/new_cs/CS261-Project/lib/screen/auth/account_deactivated_screen.dart) | Suspended user recovery & reactivation submission |
