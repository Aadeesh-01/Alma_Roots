# Backend Architecture, Scalability & Viva/Interview Guide — Alumni Connect

> **Application Name:** Alumni Connect (`CS261-Project`)  
> **Client Framework:** Flutter (Dart)  
> **Backend Infrastructure:** Google Cloud Platform (GCP) & Firebase Serverless Architecture  
> **Primary Region:** `asia-south1` (Mumbai, India)  
> **Document Objective:** Comprehensive, code-backed analysis of the backend architecture, scalability, capacity limits, performance bottlenecks, cost models, reliability mechanisms, and college viva/technical interview preparation.

---

# Table of Contents
1. [Backend Architecture & Cloud Services](#1-backend-architecture--cloud-services)
2. [Database Architecture & Data Modeling](#2-database-architecture--data-modeling)
3. [Security Architecture & Threat Modeling](#3-security-architecture--threat-modeling)
4. [Scalability & Concurrency Analysis](#4-scalability--concurrency-analysis)
5. [Data Capacity & Storage Estimation](#5-data-capacity--storage-estimation)
6. [Performance Bottlenecks & Optimization Strategies](#6-performance-bottlenecks--optimization-strategies)
7. [Cost & Billing Estimation Models](#7-cost--billing-estimation-models)
8. [Reliability, Fault Tolerance & Failure Handling](#8-reliability-fault-tolerance--failure-handling)
9. [Deployment & Environment Lifecycle](#9-deployment--environment-lifecycle)
10. [College Viva & Technical Interview Questions (With Code References)](#10-college-viva--technical-interview-questions-with-code-references)
11. [One-Page Final Interview Cheat Sheet](#11-one-page-final-interview-cheat-sheet)

---

# 1. Backend Architecture & Cloud Services

### 1.1 Architecture Flow Diagram

```
                             [ Flutter Mobile App (Android / iOS) ]
                                                │
          ┌─────────────────────────────────────┼──────────────────────────────────┐
          │                                     │                                  │
          ▼                                     ▼                                  ▼
┌──────────────────┐                  ┌──────────────────┐               ┌──────────────────┐
│  Firebase Auth   │                  │  Cloud Storage   │               │   FCM Service    │
│  (Auth & Claims) │                  │  (User Avatars)  │               │ (Push Messages)  │
└─────────┬────────┘                  └──────────────────┘               └──────────────────┘
          │                                     │                                  │
          │ User UID / JWT                      │ Download URLs                    │ Push Payload
          ▼                                     ▼                                  │
┌────────────────────────────────────────────────────────────────────────┐         │
│                     Cloud Firestore (Database)                         │         │
│  • Multi-tenant Subcollections: `/institutes/{instId}/...`             │         │
│  • Enforced by Declarative Gateway: `firestore.rules`                  │         │
└───────────────────────────────────┬────────────────────────────────────┘         │
                                    │                                              │
                      Callable APIs │ DB Triggers / Cron Scheduler                 │
                                    ▼                                              │
┌────────────────────────────────────────────────────────────────────────┐         │
│                   Cloud Functions v2 (Node.js 20)                      │         │
│                      Region: `asia-south1` (Mumbai)                    │         │
│  • `createParticipantAccount` (Provisioning & Custom Claims)           │         │
│  • `addAdminRole` (Privilege Elevation)                                │         │
│  • `processDeletionQueueNow` (Batch Purge Worker)                      │         │
│  • `processPermanentDeletionQueue` (5-Minute Background Cron)          │─────────┘
└────────────────────────────────────────────────────────────────────────┘
```

---

### 1.2 Component-by-Component Overview

| Component | Technology | Primary Role in Project | Controlling Code Files |
| :--- | :--- | :--- | :--- |
| **Client Application** | Flutter 3.x (Dart) | User interface, state management, local SQLite caching. | `lib/main.dart`, `lib/screen/*` |
| **Authentication** | Firebase Auth | Secure user sign-in, token issuance (JWT), custom role claims. | `lib/screen/auth.dart`, `lib/service/auth_service.dart` |
| **Database** | Cloud Firestore | Real-time multi-tenant document store; reactive stream subscriptions. | `lib/service/*.dart`, `firestore.rules` |
| **Serverless Logic** | Cloud Functions v2 (Node.js 20) | Privileged administrative operations, transactional rollback, scheduled cron purges. | `functions/index.js`, `functions/package.json` |
| **Media Storage** | Cloud Storage | Binary storage of profile avatars; CDN image URL resolution. | `lib/screen/profile/profile_edit_screen.dart` |
| **Messaging** | Firebase Cloud Messaging | Remote push notification delivery to Android and iOS devices. | `lib/service/notification_service.dart` |
| **Security Gateway** | Firestore Security Rules | Granular RBAC evaluation prior to database read/write execution. | `firestore.rules`, `firestore.test.js` |
| **App Attestation** | Firebase App Check | Device attestation preventing unauthorized API/curl script scraping. | *Not yet configured* |

---

### 1.3 Communication Protocols & Infrastructure
* **Flutter $\longleftrightarrow$ Firebase Auth:** HTTPS REST / JSON-RPC. Returns an ID Token (JWT) refreshed hourly.
* **Flutter $\longleftrightarrow$ Cloud Firestore:** Persistent, multiplexed bidirectional **gRPC over HTTP/2** using TLS encryption. Enables real-time document listeners (`.snapshots()`) over a single persistent TCP socket.
* **Flutter $\longleftrightarrow$ Cloud Functions:** HTTPS POST request formatted as a callable function (`httpsCallable`), automatically passing authentication context (`context.auth`).
* **Flutter $\longleftrightarrow$ Cloud Storage:** HTTPS multi-part file upload with resumable upload support.
* **Cloud Functions $\longleftrightarrow$ Firestore / Auth:** Internal Google Cloud backbone network using `firebase-admin` with privileged Service Account credentials (bypassing security rules).
* **Backend Regions:** 
  - Firestore Database: `asia-south1` (Mumbai).
  - Cloud Functions: `asia-south1` (Mumbai).
  - *Advantage:* Placing compute and database in the same geographic region eliminates cross-region network egress charges and keeps internal API round-trip latency under 15ms.

---

# 2. Database Architecture & Data Modeling

### 2.1 Multi-Tenant Hierarchical Schema

The database utilizes **Hierarchical Multi-Tenancy**. Rather than storing all university users in a flat global table with an `instituteId` column, data is physically scoped beneath each university document: `/institutes/{instId}/...`.

```
/institutes/{instId}
    │
    ├── /participants/{userId}           (Profile, Credentials, Role, Keywords)
    │
    ├── /posts/{postId}                  (Announcements, Events, Experiences)
    │       ├── /comments/{commentId}    (Threaded Discussions)
    │       ├── /likes/{userId}          (Like Junction Documents)
    │       └── /attendees/{userId}      (RSVP / Waitlist Capacity Records)
    │
    ├── /chats/{chatId}                  (1:1 Direct Chat Threads: uid1_uid2)
    │       └── /messages/{messageId}    (Real-time Chat Messages)
    │
    ├── /admin_actions/{actionId}        (Immutable Compliance Audit Trail)
    │
    ├── /deletion_queue/{userId}         (24-Hour Permanent Purge Queue)
    │
    ├── /reactivation_requests/{userId}  (Account Recovery Petitions)
    │
    ├── /feedback/{feedbackId}           (Bug Reports & Feedback)
    │
    └── /archived_users/{userId}         (Pre-purge User Snapshots)

/super_admins/{userId}                   (Global Platform Administrators)
```

---

### 2.2 Storage of Students, Alumni, and Admins

All three roles share the unified collection `/institutes/{instId}/participants/{uid}`, with role-specific attributes:
* **Primary Key:** Firebase Authentication `uid` (prevents duplicate accounts, ensures $O(1)$ lookup).
* **Common Fields:** `uid`, `name`, `email`, `role`, `instituteId`, `status`, `isDeleted`, `customId`, `searchKeywords`, `createdAt`, `updatedAt`.
* **Student-Specific Fields:** `rollNo`, `department`, `year` (graduation year).
* **Alumni-Specific Fields:** `company`, `interest` (areas of expertise), `isMentor` (boolean), `isHiring` (boolean), `openToNetworking` (boolean).
* **Admin-Specific Fields:** Elevated role claim in Auth (`auth.token.role == "admin"`) and `role: "admin"` in Firestore.

---

### 2.3 Read/Write Mechanics & Database Patterns

1. **Reactive Streams (`snapshots()`):**  
   Used in `NewsEventService.getPosts` and `ChatService.streamMessages`. Flutter keeps a live gRPC stream open; when a document is created or modified, Firestore pushes delta changes to the client in real time.
2. **Atomic Multi-Document Transactions (`runTransaction`):**  
   Used in `NewsEventService.toggleRsvp` and `toggleLike`. Reads execute before writes. If another user alters the document concurrently, Firestore aborts and retries the transaction.
3. **Atomic Batched Writes (`WriteBatch`):**  
   Used in `ChatService.sendDirectMessage` and `AdminService.softDeleteUser`. Up to 500 write operations succeed or fail as an all-or-nothing atomic unit.
4. **Atomic Delta Increments:**  
   Counters (`likeCount`, `commentCount`, `attendeeCount`) use `FieldValue.increment(1)` or `-1` to update counts directly on the server without document-level locks.
5. **Deterministic Composite Primary Keys:**  
   In `ChatService.getDirectChatId(uid1, uid2)`, participant IDs are sorted alphabetically (`uidA_uidB`). This eliminates redundant conversation lookups.

---

### 2.4 Indexing Registry (`firestore.indexes.json`)

Firestore mandates an index for every compound query. The project declares 7 composite B-Tree indexes:
1. `chats`: `participants` (`CONTAINS`) + `lastMessageTimestamp` (`DESC`) $\longrightarrow$ Inbox streaming.
2. `posts`: `isPinned` (`DESC`) + `createdAt` (`DESC`) $\longrightarrow$ Campus feed rendering.
3. `posts`: `type` (`ASC`) + `createdAt` (`DESC`) $\longrightarrow$ Post type filtering.
4. `posts`: `category` (`ASC`) + `createdAt` (`DESC`) $\longrightarrow$ Category filtering.
5. `posts`: `visibility` (`ASC`) + `createdAt` (`DESC`) $\longrightarrow$ Role-based audience filtering.
6. `reactivation_requests`: `status` (`ASC`) + `requestedAt` (`DESC`) $\longrightarrow$ Admin review queue.
7. `deletion_queue`: `status` (`ASC`) + `scheduledFor` (`ASC`) $\longrightarrow$ Scheduled deletion purging.

---

# 3. Security Architecture & Threat Modeling

### 3.1 Security Rules Enforcement Matrix

```
Client Read/Write Request
       │
       ▼
[ Is Authenticated? (request.auth != null) ] ──No──> ❌ REJECT (401)
       │
       ▼
[ Belongs to Institute? (/institutes/{instId}/participants/{uid} exists) ] ──No──> ❌ REJECT (403)
       │
       ▼
[ Is Account Active? (status == 'active' && !isDeleted) ] ──No──> ❌ REJECT (403)
       │
       ▼
[ Check Granular Resource Rules (Role, Authorship, Immutability) ] ──Pass──> ✅ ALLOW
```

* **Anti-Privilege Escalation (`firestore.rules`):**
  ```javascript
  request.resource.data.get('role', resource.data.get('role', 'student')) == resource.data.get('role', 'student')
  ```
  A student can edit their name or bio, but attempting to change their `role` to `admin` or their `status` to `active` results in an immediate `PERMISSION_DENIED` rejection at the database engine level.
* **Strict 1:1 Chat Privacy:**
  ```javascript
  allow read: if isActiveMember(instId) && request.auth.uid in resource.data.get('participants', []);
  ```
  Admins **cannot** read direct student chats unless they are an active party in the conversation.

---

### 3.2 Threat Model: What an Attacker Could Access If Rules Fail

| Vulnerability Scenario | Attacker Action | Potential Impact | How Current Project Protects Against It |
| :--- | :--- | :--- | :--- |
| **Missing Privilege Escalation Rule** | User sends `role: 'admin'` in profile update payload. | Attacker becomes institute admin, accesses user lists, and purges accounts. | Enforced in `firestore.rules` by comparing `request.resource.data.role` with `resource.data.role`. |
| **Open Chat Collection Read** | Attacker queries `/institutes/{instId}/chats` without participant filter. | Private student messages, mentorship conversations, and personal communications are exposed. | Rule enforces `request.auth.uid in resource.data.participants`. |
| **Missing Storage Rules** | Attacker calls Cloud Storage API with random user UIDs. | Attacker overwrites or deletes other users' profile avatars. | **Vulnerability in current codebase:** `storage.rules` is missing from source control. Needs deployment. |
| **No App Check** | Attacker extracts Firebase API key from APK and writes a bot script. | Floods database with automated spam posts or triggers Cloud Function invocations. | **Vulnerability in current codebase:** App Check is not installed. |

---

# 4. Scalability & Concurrency Analysis

To evaluate scalability accurately, we distinguish between **Google Cloud platform maximums**, **current project architecture limits**, and **practical recommended operational capacity**.

```
Scale Tiers:
┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  100 Users   │ ──> │ 10,000 Users │ ──> │ 100,000 Users│ ──> │ 1M Users     │
│ Zero Latency │     │ Optimum Tier │     │ High Traffic │     │ Architecture │
│ Spark Plan OK│     │ Blaze Plan   │     │ Sharding Req.│     │ Redesign     │
└──────────────┘     └──────────────┘     └──────────────┘     └──────────────┘
```

---

### 4.1 System Limits Breakdown

| Dimension | 1. Official Firebase Platform Limits | 2. Current Project Implementation Limits | 3. Practical Recommended Production Limit |
| :--- | :--- | :--- | :--- |
| **Max Database Size** | Practically unlimited (scales horizontally across Petabytes). | Multi-tenant subcollection layout scales automatically. | Up to 10 TB before query indexing costs dominate. |
| **Single Document Size** | Exactly **1 MiB** ($1,048,576$ bytes). | Participant docs ~1.5 KB; Post docs ~2 KB. | Keep documents under **100 KB** for fast mobile deserialization. |
| **Writes per Single Document** | **1 write per second** (sustained). | `FieldValue.increment` on post `likeCount`. | High contention if >50 users like the same post simultaneously. |
| **Max Concurrent DB Connections** | **1,000,000** concurrent connections per DB. | Managed via persistent gRPC channels in client SDK. | 250,000 simultaneous active mobile users. |
| **Batch Write Max Operations** | **500 operations** per atomic batch. | `SearchMigrationService` chunks writes at 400. | Chunk at 300–400 operations to allow headroom. |
| **Cloud Functions Concurrency** | 1,000 concurrent container instances (default). | Standard Node.js 20 single-threaded event loop. | 5,000 requests/second on Cloud Functions v2. |
| **FCM Multicast Limit** | **500 registration tokens** per API call. | Service unwired; theoretical limit 500 devices/payload. | Batch notifications in chunks of 500 via Cloud Tasks. |

---

### 4.2 Behavior Across User Scale Milestones

#### Phase 1: 100 to 1,000 Users (Development / Single College Pilot)
* **Performance:** Sub-100ms query latency.
* **Bottlenecks:** None. Fits comfortably within the Firebase Spark (free) plan quota (50k reads/day, 20k writes/day).
* **Infrastructure:** Zero server maintenance required.

#### Phase 2: 10,000 Users (Medium Multi-College Deployment)
* **Performance:** Real-time listeners operate smoothly.
* **Cost:** Exceeds free tier; requires the Blaze (Pay-as-you-go) plan.
* **Bottlenecks:** Client-side prefix token generation (`searchKeywords`) starts increasing document write sizes as user directory grows.
* **Recommended Action:** Enable Firebase App Check to block automated bot traffic.

#### Phase 3: 100,000 Users (State-Wide Academic Network)
* **Performance & Bottlenecks:**
  1. **Hotspotting on Viral Posts:** If an official exam cancellation notice receives 500 likes/comments per minute, the post document will hit Firestore’s **1 write/second per document** limitation, causing write contention errors.
  2. **Chat Inbox Fetch Overhead:** Streaming 20 inboxes resolves multiple participant profiles. N+1 lookups must be strictly cached locally.
* **Architectural Adjustment:** Implement **Counter Sharding** for post engagement metrics (split `likeCount` into 10 subdocuments and compute the sum).

#### Phase 4: 1,000,000 Users (Enterprise / National Platform)
* **Bottlenecks:**
  1. **In-Engine Search Limits:** Firestore `array-contains` prefix searching cannot handle typo-tolerance, fuzzy searching, or sorting by relevance across millions of records.
  2. **Large Tenancy Index Scans:** Running `collectionGroup` queries across thousands of universities requires complex composite index maintenance.
* **Architectural Adjustment:** Offload user search to a dedicated search cluster (e.g., **Google Cloud Vertex AI Search** or **Elasticsearch**) synchronized via Cloud Functions change streams.

---

# 5. Data Capacity & Storage Estimation

### 5.1 Average Document Size Breakdown

```
Estimated Participant Document Size:
┌────────────────────────────────────────────────────────┐
│ Core Attributes (uid, email, name, role):    ~150 bytes│
│ Bio, Department, Roll No, Company:           ~350 bytes│
│ Search Keywords Array (15–30 tokens):        ~600 bytes│
│ Timestamps, Metadata, Flags:                 ~100 bytes│
│ Firestore Document Overhead:                  ~32 bytes│
├────────────────────────────────────────────────────────┤
│ Total Expected Size per User:               ~1.23 KB   │
└────────────────────────────────────────────────────────┘
```

* **Max Document Size Limit:** 1,048,576 bytes ($1\text{ MiB}$).
* **Margin:** A 1.23 KB participant document uses only **0.12%** of the maximum document capacity.

---

### 5.2 Scale Projections Table

| Scale Tier | Database Size (Firestore) | Profile Images (Cloud Storage @ 250 KB/avatar) | Daily Reads (Estimate: 35 reads/DAU) | Daily Writes (Estimate: 5 writes/DAU) |
| :--- | :--- | :--- | :--- | :--- |
| **1,000 Users** | ~1.5 MB | ~250 MB | 35,000 *(Within Free Tier)* | 5,000 *(Within Free Tier)* |
| **10,000 Users** | ~15 MB | ~2.5 GB | 350,000 | 50,000 |
| **100,000 Users**| ~150 MB | ~25 GB | 3,500,000 | 500,000 |
| **1,000,000 Users**| ~1.5 GB | ~250 GB | 35,000,000 | 5,000,000 |

*Takeaway:* Firestore database storage is negligible (even 1 million user records take less than 2 GB of text data). The primary storage footprint comes from **Cloud Storage images** ($250\text{ GB}$ per million users).

---

# 6. Performance Bottlenecks & Optimization Strategies

### 6.1 Identified Codebase Bottlenecks

1. **Client-Side Keyword Token Generation:**  
   In `SearchService.generateSearchKeywords`, generating all string and word prefixes increases document write sizes and CPU usage on older mobile devices during registration.
2. **Missing Storage Cache Headers:**  
   When profile pictures are uploaded in `profile_edit_screen.dart`, custom cache headers (`cacheControl: 'public, max-age=86400'`) are not set. The mobile app re-downloads the avatar image repeatedly instead of reading from device cache.
3. **Region Call Default in `AdminService`:**  
   `admin_service.dart` line 339 calls `FirebaseFunctions.instance` without specifying `region: 'asia-south1'`, routing calls through US defaults and adding latency.

---

### 6.2 Recommended Performance Improvements (Without Code Changes)

* **Implement Counter Sharding:** Distribute high-frequency counters (`likeCount`) across 10 sub-shards to bypass the 1 write/sec single-document ceiling.
* **Client Keyset Pagination:** Use `startAfterDocument()` instead of `limit(20)` alone for smooth infinite scrolling.
* **Cached Network Image Optimization:** Enforce `maxHeightDiskCache` and `maxWidthDiskCache` in `CachedNetworkImage` widgets to reduce mobile GPU memory usage.

---

# 7. Cost & Billing Estimation Models

*Note: Pricing figures are based on official Google Cloud / Firebase Blaze plan pricing and should be verified against the official Firebase pricing calculator.*

### 7.1 Unit Costs Reference (Blaze Plan)
* **Firestore Document Reads:** $\$0.06$ per 100,000 reads (first 50,000/day free).
* **Firestore Document Writes:** $\$0.18$ per 100,000 writes (first 20,000/day free).
* **Firestore Storage:** $\$0.18$ per GB / month (first 1 GB free).
* **Cloud Storage:** $\$0.026$ per GB / month storage; $\$0.12$ per GB download transfer.
* **Cloud Functions:** 2,000,000 invocations free per month; then $\$0.40$ per million calls.
* **Firebase Authentication:** Free for up to 50,000 Monthly Active Users (MAU).
* **Firebase Cloud Messaging:** 100% Free.

---

### 7.2 Estimated Monthly Operational Costs

| Active User Scale | Firestore Costs | Cloud Storage Costs | Cloud Functions Costs | Total Estimated Monthly Cost |
| :--- | :--- | :--- | :--- | :--- |
| **1,000 Active Users** | **$0.00** *(Free Tier)* | **$0.00** *(Free Tier)* | **$0.00** *(Free Tier)* | **$0.00 / month** |
| **10,000 Active Users** | ~$5.40 / mo | ~$1.20 / mo | ~$0.40 / mo | **~$7.00 / month** |
| **100,000 Active Users**| ~$58.00 / mo | ~$18.00 / mo | ~$6.00 / mo | **~$82.00 / month** |

*Takeaway:* The architecture is exceptionally cost-effective. Serving 10,000 active collegiate users costs approximately $\$7$ per month due to the high free tier allocations and lightweight document schema.

---

# 8. Reliability, Fault Tolerance & Failure Handling

| Failure Scenario | System Impact | Current Architectural Behavior | Recommended Best Practice |
| :--- | :--- | :--- | :--- |
| **Device Internet Disconnects** | Network drops during operation. | Firestore local cache allows offline reads. Writes are queued in local SQLite journal and synced on reconnect. | Display an offline badge in UI using connectivity listeners. |
| **Cloud Function Fails During User Creation** | Firestore write fails after Auth user is created. | `createParticipantAccount` catches exception and executes **compensating rollback**: `admin.auth().deleteUser(uid)`. | Implemented correctly via Saga pattern. |
| **Firestore Outage (Regional)** | Cloud service unavailable. | App displays connection retry indicators. Firestore SLA guarantees 99.999% availability for multi-region. | Configure multi-region replication for enterprise tier. |
| **FCM Service Fails** | Push notifications delayed. | Chat messages and posts are still saved in Firestore; users receive data via in-app streams. | Messages are not lost; notification is simply an out-of-band trigger. |
| **Admin Device Clock Fast** | Admin schedules permanent purge. | Local device timestamp sets `scheduledFor` in the past. | Compute timestamps exclusively on server using `serverTimestamp()`. |

---

# 9. Deployment & Environment Lifecycle

```
[ Local Development ] ──> [ Emulator Suite Testing ] ──> [ Staging Project ] ──> [ Production (project-cs261) ]
```

### 9.1 Step-by-Step Deployment Commands

1. **Deploy Firestore Security Rules & Indexes:**
   ```bash
   firebase deploy --only firestore:rules,firestore:indexes
   ```
2. **Deploy Cloud Functions to Mumbai (`asia-south1`):**
   ```bash
   cd functions
   npm install
   firebase deploy --only functions
   ```
3. **Deploy Storage Rules:**
   ```bash
   firebase deploy --only storage
   ```
4. **Build Production Flutter Android Bundle (AAB):**
   ```bash
   flutter build appbundle --release
   ```

---

# 10. College Viva & Technical Interview Questions

---

### Q1: Why did you choose Firebase instead of a traditional relational database like MySQL or PostgreSQL?
* **Short Answer:**  
  We chose Firebase because our campus application requires real-time data synchronization (live messaging, news feeds, and RSVP capacity updates) and offline caching for mobile devices, which Firestore provides natively out of the box without complex WebSocket infrastructure.
* **Technical Depth:**  
  A traditional SQL database requires deploying a dedicated server, connection pooling management, and building a custom WebSocket layer for real-time updates. Firestore provides horizontal auto-scaling backed by Google Cloud Spanner, real-time push streams via gRPC, and built-in mobile SQLite offline persistence.
* **Where It Applies in Code:**  
  Used in `NewsEventService.getPosts` and `ChatService.streamInbox`, where streams update the Flutter UI reactively without manual polling.

---

### Q2: How are Admin, Alumni, and Student roles implemented and secured?
* **Short Answer:**  
  Roles are stored inside each user's participant document in Firestore and embedded into their Firebase Auth JWT token as a custom user claim. Security rules enforce that students cannot escalate their privileges.
* **Technical Depth:**  
  Role identification operates across three tiers:
  1. *Presentation Tier:* `UserRoleDispatcher` inspects the user's role and renders either `AdminHomeScreen` or `UserHomeScreen`.
  2. *Gateway Tier:* `firestore.rules` compares incoming update payloads against the existing document (`request.resource.data.role == resource.data.role`) to reject privilege escalation attempts.
  3. *Backend Tier:* Cloud Functions check `auth.token.role === 'admin'` before running privileged code.
* **Where It Applies in Code:**  
  Implemented in `lib/service/user_role_dispatcher.dart` and `firestore.rules` (lines 46–53).

---

### Q3: What is the difference between `runTransaction` and `WriteBatch` in your project?
* **Short Answer:**  
  `runTransaction` is used when we must read existing data before writing (like checking event seat capacity), while `WriteBatch` is used for blind atomic multi-document writes where no prior read is needed.
* **Technical Depth:**  
  `runTransaction` uses Optimistic Concurrency Control (OCC). It reads the document version; if another user writes to it before commit, Firestore retries the entire closure. `WriteBatch` allows up to 500 atomic writes without reading, committing as an all-or-nothing operation.
* **Where It Applies in Code:**  
  `runTransaction` is used in `NewsEventService.toggleRsvp` to prevent overbooking; `WriteBatch` is used in `AdminService.softDeleteUser` to update the user doc and append an audit log simultaneously.

---

### Q4: How do you prevent event overbooking if two users RSVP at the exact same millisecond?
* **Short Answer:**  
  We wrap the RSVP check and attendee count increment inside a Firestore transaction (`_firestore.runTransaction`).
* **Technical Depth:**  
  When User A and User B read `attendeeCount = 99` simultaneously on a 100-seat event, User A's transaction reaches the server first and commits, updating the count to 100. When User B's transaction attempts to commit, Firestore detects a document version mismatch, rejects the commit, and re-executes User B's transaction. On retry, User B reads `100 >= 100` and is safely redirected to the waitlist.
* **Where It Applies in Code:**  
  Implemented in `lib/service/news_event_service.dart` lines 106–152 (`toggleRsvp`).

---

### Q5: What is the maximum document size in Firestore and what happens if you exceed it?
* **Short Answer:**  
  The maximum size is exactly 1 MiB (1,048,576 bytes). If a document exceeds this, Firestore rejects the write with an `INVALID_ARGUMENT` error.
* **Technical Depth:**  
  Storing unbounded arrays (like all comments or all likes inside a post document) will eventually breach the 1 MiB threshold. To prevent this, our architecture stores comments, likes, and messages inside **subcollections**, where each comment is an independent document.
* **Where It Applies in Code:**  
  `posts/{id}/comments/{commentId}` and `chats/{id}/messages/{messageId}` are organized as subcollections rather than arrays.

---

### Q6: Can an institute administrator read private direct messages between students?
* **Short Answer:**  
  No. Our database security rules enforce zero-trust privacy for direct chats.
* **Technical Depth:**  
  In `firestore.rules`, the read condition for `/chats/{chatId}` requires that the caller's Auth UID must be present in the `participants` array:
  ```javascript
  allow read: if isActiveMember(instId) && request.auth.uid in resource.data.get('participants', []);
  ```
  The rule intentionally omits `isAdmin(instId)`, ensuring that administrators cannot inspect private student communications unless they are an explicit participant.
* **Where It Applies in Code:**  
  `firestore.rules` lines 109–126.

---

### Q7: Why are your Cloud Functions deployed in the `asia-south1` region?
* **Short Answer:**  
  To colocated backend compute with our users and our database in Mumbai, India, minimizing latency and eliminating cross-region network egress costs.
* **Technical Depth:**  
  Default Cloud Functions deploy to `us-central1` (Iowa, USA). Sending requests from mobile devices in India to the US adds 250–350ms of network latency per hop. Deploying to `asia-south1` reduces latency to 30–60ms.
* **Where It Applies in Code:**  
  `functions/index.js` lines 10, 165, and 275 (`{ region: "asia-south1" }`).

---

### Q8: What is a Compensating Transaction (Saga Pattern) in your project?
* **Short Answer:**  
  An explicit rollback mechanism used when an operation spans multiple systems that cannot share a single ACID database lock.
* **Technical Depth:**  
  Creating a user requires writing to both Firebase Authentication and Cloud Firestore. If creating the Auth user succeeds but the Firestore document write fails, the account would become an orphaned "ghost user". Our Cloud Function catches the failure and calls `admin.auth().deleteUser(uid)` to delete the auth account, restoring cross-system consistency.
* **Where It Applies in Code:**  
  `functions/index.js` lines 132–140 (`createParticipantAccount`).

---

### Q9: How does the application implement user search without an external search engine?
* **Short Answer:**  
  By generating character prefix tokens (an inverted index) in an array called `searchKeywords` and querying it with Firestore's `array-contains` operator.
* **Technical Depth:**  
  When a profile is saved, `SearchService.generateSearchKeywords` tokenizes strings into prefix n-grams (e.g., "John" becomes `["j", "jo", "joh", "john"]`). Firestore maintains an internal B-Tree index on array elements, allowing $O(\log N)$ lookups without full table scans.
* **Where It Applies in Code:**  
  `lib/service/search_service.dart` lines 8–33.

---

### Q10: What is the N+1 query problem and where could it occur in your app?
* **Short Answer:**  
  It occurs when an application executes 1 query to fetch a parent list and then executes N subsequent queries to fetch details for each item.
* **Technical Depth:**  
  When displaying 20 chats in the inbox, fetching the chat documents is 1 query. If the app then issued 20 individual queries to fetch each partner's avatar, it would cause 21 network round-trips. In `ChatService.streamInbox`, we batch participant lookups together to resolve profiles in a single operation.
* **Where It Applies in Code:**  
  Documented and handled in `lib/service/chat_service.dart` lines 16–20.

---

### Q11: How do you handle soft deletes vs permanent hard deletes?
* **Short Answer:**  
  Soft deletes flag an account as `isDeleted: true` immediately revoking access; permanent deletes stage the account in a queue with a 24-hour grace period before automated purging.
* **Technical Depth:**  
  Soft deletion preserves historical auditability. For permanent removal, `AdminService.schedulePermanentDeletion` places the user into `/deletion_queue/{uid}` with a timestamp 24 hours in the future. A Cloud Scheduler cron function running every 5 minutes scans the queue and executes a batch purge only after the grace period expires.
* **Where It Applies in Code:**  
  `lib/service/admin_service.dart` and `functions/index.js` lines 346–365.

---

### Q12: What would you change before launching this application to 100,000 real users?
* **Short Answer:**  
  1. Fix the Cloud Function region mismatch in `AdminService`.  
  2. Create and deploy `storage.rules`.  
  3. Wire up FCM token saving in `main.dart`.  
  4. Enable Firebase App Check.  
  5. Implement counter sharding for viral post likes.

---

# 11. One-Page Final Interview Cheat Sheet

| Category | Fast Technical Summary | Key Source Code Location |
| :--- | :--- | :--- |
| **Tech Stack** | Flutter 3.x, Dart, Cloud Firestore, Firebase Auth, Cloud Functions v2 (Node.js 20), Cloud Storage. | `pubspec.yaml`, `functions/package.json` |
| **Primary Region** | `asia-south1` (Mumbai, India) for lower latency and data locality. | `functions/index.js` |
| **Architecture Pattern**| Multi-Tenant Subcollections: `/institutes/{instId}/...`. Natural data sandboxing. | `firestore.rules`, `lib/service/*` |
| **Authentication** | Firebase Auth email/password; accounts provisioned by administrators; custom claims for admins. | `lib/screen/auth.dart`, `functions/index.js` |
| **Role Routing** | `UserRoleDispatcher` evaluates Firestore role and routes to Admin, Student/Alumni, or Deactivated screen. | `lib/service/user_role_dispatcher.dart` |
| **Security Rules** | Declarative gateway checking institute membership, active status, role-gated posts, and anti-privilege escalation. | `firestore.rules`, `firestore.test.js` |
| **Transactions** | `runTransaction` for capacity-checked event RSVPs; `WriteBatch` for atomic messages and soft deletes. | `news_event_service.dart`, `admin_service.dart` |
| **Search Engine** | Prefix n-gram tokenization (`searchKeywords`) queried via `array-contains`. | `lib/service/search_service.dart` |
| **Permanent Purging** | 24-hour staging queue (`deletion_queue`) purged by an automated 5-minute Cloud Scheduler cron job. | `functions/index.js:346-365` |
| **Storage** | Cloud Storage bucket `project-cs261.firebasestorage.app` for user profile photos. | `profile_edit_screen.dart:89` |
| **Scalability Limit** | 1 MiB max doc size; 1 write/sec per document (resolved at scale via counter sharding). | Firestore Platform Engine |
| **Cost Profile** | $0/mo for <1k users (Spark plan); ~$7/mo for 10k users; ~$82/mo for 100k users (Blaze plan). | Official Blaze Plan Pricing |
| **Critical Fixes Needed** | Fix callable region in `admin_service.dart`, add `storage.rules`, initialize FCM, configure App Check. | `admin_service.dart`, `main.dart` |
