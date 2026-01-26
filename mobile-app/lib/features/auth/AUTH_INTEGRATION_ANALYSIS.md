# Auth Integration Analysis & Plan

## 📋 Backend Auth Functions (Go)

### Core Authentication Endpoints

**1. Registration Flow:**
- `POST /auth/register` - Creates user with email, password, username, display_name, age
  - Validates: email format, password (min 6), username (3-20 alphanumeric), display_name (2-50), age (13-120)
  - Checks: email uniqueness, username uniqueness (currently commented out)
  - Generates: 6-digit verification code, expires in 10 minutes
  - Sends: Verification email with code
  - Returns: `{success: true, message: "...", user_id: "uuid"}`

**2. Email Verification:**
- `POST /auth/verify-email` - Verifies email with 6-digit code
  - Validates: email, 6-digit code
  - Checks: code matches and not expired
  - Updates: sets `is_email_verified = true`
  - Generates: JWT token (30 days expiry)
  - Creates: Session in database
  - Sends: Welcome email
  - Returns: `{success: true, token: "jwt", expires_at: "...", user: {...}}`

**3. Login:**
- `POST /auth/login` - Login with email/username + password
  - Validates: email_or_username, password
  - Checks: user exists, is active, email verified, password matches
  - Generates: JWT token
  - Creates: Session
  - Updates: last_login_at
  - Returns: `{success: true, token: "jwt", expires_at: "...", user: {...}}`

**4. Username Availability:**
- Currently handled in `CheckUsernameExists` repository method
- **MISSING:** Dedicated endpoint for real-time username checking
- **NEEDED:** `GET /auth/check-username?username=xxx` endpoint

**5. OAuth (Google/GitHub/LinkedIn):**
- `GET /auth/{provider}/login` - Returns auth URL
- `GET /auth/{provider}/callback` - OAuth callback (redirects to frontend)
- `POST /auth/{provider}/exchange` - Exchanges code for token
  - Gets user info from provider
  - Creates user if new (with auto-generated username)
  - Links account if email exists
  - Returns: `{success: true, token: "jwt", user: {...}}`
  - **NOTE:** OAuth users still need password for your flow!

**6. Token Management:**
- `GET /auth/me` - Get current user (protected)
- `POST /auth/refresh` - Refresh token (protected)
- `POST /auth/logout` - Logout and blacklist token (protected)

**7. Password Reset:**
- `POST /auth/forgot-password` - Request reset
- `POST /auth/reset-password` - Reset with token

### Backend Data Models

**User Model Fields:**
```go
- id (UUID)
- email (string, unique)
- username (string, unique, 3-20 chars)
- password_hash (string, nullable for OAuth)
- display_name (string, 2-50 chars)
- age (int, 13-120)
- gender (string, nullable) - "male", "female", "non-binary", "prefer-not-to-say", "custom"
- gender_custom (string, nullable)
- bio (string, nullable, max 200)
- profile_picture (string, nullable) - URL
- is_email_verified (bool)
- email_verification_code (string, 6 digits)
- email_verification_expires_at (timestamp)
- google_id, github_id, linkedin_id (string, nullable)
- oauth_provider (string, nullable)
- is_active (bool)
- created_at, updated_at (timestamp)
```

### Backend Database Structure

**Database:** PostgreSQL via Supabase
**Repository Pattern:** Interface-based (easy to swap)
- `UserRepository` interface defines contract
- `SupabaseUserRepository` implements it
- Can easily swap to Postgres, MySQL, etc. by implementing interface

**Key Methods:**
- `CreateUser(ctx, user)` - Creates user
- `GetUserByEmail(ctx, email)` - Get by email
- `GetUserByUsername(ctx, username)` - Get by username
- `CheckEmailExists(ctx, email)` - Check email
- `CheckUsernameExists(ctx, username)` - Check username
- `VerifyEmail(ctx, email, code)` - Verify email
- `UpdateUser(ctx, user)` - Update user

---

## 📱 Flutter Auth Screens & Flow

### Screen Flow Analysis

**Route 1: New User Signup (Gamified Multi-Step)**

1. **Splash Screen** (`/`)
   - Shows logo, animates
   - Auto-navigates to `/welcome` after 2 seconds

2. **Welcome Screen** (`/welcome`)
   - Two buttons: "Already have an account" → `/signin`
   - "I'm new here" → `/signup-options`

3. **Signup Options Screen** (`/signup-options`)
   - Email signup → `/signup-email`
   - Social signup (Google/LinkedIn/GitHub) → Still goes to `/account-name` (needs password!)

4. **Signup Email Screen** (`/signup-email`)
   - Collects email
   - Validates format
   - On continue → `/otp-verification` (passes email)

5. **OTP Verification Screen** (`/otp-verification`)
   - Receives email from previous screen
   - 6-digit OTP input
   - Auto-verifies when complete
   - Resend option
   - On verify → `/account-name`

6. **Account Name Screen** (`/account-name`)
   - Username (with real-time availability check - debounced 800ms)
   - Display name
   - Gender dropdown (Male, Female, Other, Prefer not to say)
   - On next → `/age`

7. **Age Screen** (`/age`)
   - Age wheel picker (13-100)
   - Optional (can skip)
   - On next/skip → `/profile-setup`

8. **Profile Setup Screen** (`/profile-setup`)
   - Profile picture (image picker, optional)
   - Bio (optional, max 200 chars)
   - On next/skip → `/password-setup`

9. **Password Setup Screen** (`/password-setup`)
   - Password (min 8 chars)
   - Confirm password
   - On "All set, welcome onboard!" → `/welcome-complete`

10. **Welcome Complete Screen** (`/welcome-complete`)
    - Celebration animation
    - "Get Started" button → `/home`

**Route 2: Returning User Signin**

1. **Welcome Screen** (`/welcome`)
   - "Already have an account" → `/signin`

2. **Signin Screen** (`/signin`)
   - Email input
   - Social login buttons
   - On continue → `/otp-verification` (for email)
   - **MISSING:** Cached account confirmation screen
   - **MISSING:** Password input screen

3. **OTP Verification** (for signin)
   - Same as signup flow
   - On verify → Should go to `/home` (not `/account-name`)

---

## 🔄 Integration Mapping

### Current Backend vs Flutter Flow Mismatch

**Backend Expects:**
```
1. POST /auth/register (email, password, username, display_name, age) → Returns user_id
2. POST /auth/verify-email (email, code) → Returns token + user
```

**Flutter Flow:**
```
1. Email → OTP → Account Name → Age → Profile → Password → Complete
```

**Problem:** Backend expects ALL data at once, but Flutter collects step-by-step!

### Solution: Multi-Step Registration

**Option A: Store Progress Locally (Recommended)**
- Store signup data in local state/cache as user progresses
- Only call backend when password is set (final step)
- Send all collected data in one `/auth/register` call

**Option B: Backend Support for Multi-Step**
- Create intermediate endpoints for each step
- Store partial registration in backend
- More complex, requires backend changes

**Recommendation:** Option A - Simpler, faster, no backend changes needed

---

## 🗄️ Database Integration Strategy

### Current Setup
- **Database:** PostgreSQL via Supabase
- **Repository Pattern:** Interface-based abstraction
- **Location:** `backend/internal/repository/user.go` (interface)
- **Implementation:** `backend/internal/repository/supabase_user_repository.go`

### Database Abstraction (For Easy Switching)

**Current Architecture:**
```
UserRepository (interface)
    ↓
SupabaseUserRepository (implementation)
```

**To Switch Database:**
1. Create new implementation (e.g., `PostgresUserRepository`)
2. Update factory in `repository/factory.go`
3. Change environment variable
4. No service/handler code changes needed!

**Key Interface Methods:**
- `CreateUser`, `GetUserByEmail`, `GetUserByUsername`
- `CheckEmailExists`, `CheckUsernameExists`
- `VerifyEmail`, `UpdateUser`
- All business logic stays the same!

---

## 📝 Integration Plan

### Phase 1: Data Models & State Management

**1. Create User Model**
```dart
@JsonSerializable()
class User {
  final String id;
  final String email;
  final String username;
  final String displayName;
  final int? age;
  final String? gender;
  final String? bio;
  final String? profilePicture;
  // ... all fields
}
```

**2. Create Signup State Model**
```dart
class SignupState {
  String? email;
  String? verificationCode;
  String? username;
  String? displayName;
  String? gender;
  int? age;
  File? profilePicture;
  String? bio;
  String? password;
}
```

**3. Create Auth Service**
```dart
class AuthService {
  // Registration
  Future<ApiResponse<String>> register(SignupState state);
  
  // Email verification
  Future<ApiResponse<AuthResponse>> verifyEmail(String email, String code);
  
  // Username check
  Future<bool> checkUsernameAvailability(String username);
  
  // Login
  Future<ApiResponse<AuthResponse>> login(String emailOrUsername, String password);
  
  // OAuth
  Future<String> getOAuthUrl(String provider);
  Future<ApiResponse<AuthResponse>> exchangeOAuthCode(String provider, String code);
}
```

### Phase 2: Screen Integration

**1. Splash Screen**
- Check if user is logged in (check token)
- If logged in → `/home`
- If not → `/welcome`

**2. Signup Email Screen**
- Call: Nothing yet (just collect email)
- Store: Email in local state

**3. OTP Verification Screen**
- Call: `POST /auth/register` with email only (if new) OR check if user exists
- **CHALLENGE:** Backend requires password, but we don't have it yet!
- **SOLUTION:** Modify backend OR use temporary password, then update later

**4. Account Name Screen**
- Call: `GET /auth/check-username?username=xxx` (need to create this endpoint)
- Store: Username, display_name, gender in state

**5. Age Screen**
- Store: Age in state (optional)

**6. Profile Setup Screen**
- Upload: Profile picture to Supabase Storage
- Store: Bio, profile_picture URL in state

**7. Password Setup Screen**
- **FINAL STEP:** Call `POST /auth/register` with ALL collected data
- Then call `POST /auth/verify-email` with stored email + code
- Store token, navigate to `/welcome-complete`

**8. Welcome Complete Screen**
- Navigate to `/home`

### Phase 3: Backend Modifications Needed

**1. Create Username Check Endpoint**
```go
GET /auth/check-username?username=xxx
Returns: {available: true/false}
```

**2. Modify Registration Flow (Option 1 - Recommended)**
- Allow registration without password initially
- Set temporary password
- Require password update before first login
- OR: Allow password to be set later via separate endpoint

**3. Modify Registration Flow (Option 2 - Better)**
- Create multi-step registration support:
  - `POST /auth/register-init` - Just email (sends OTP)
  - `POST /auth/register-complete` - All data including password

**4. OAuth Flow Modification**
- After OAuth exchange, if user is new, require additional info
- Create endpoint: `POST /auth/oauth/complete-profile`
- Collect: password, username, display_name, gender, age, bio, picture

---

## 🎯 Recommended Integration Approach

### Strategy: Hybrid Approach

**1. Email Signup Flow:**
- Step 1-5: Collect data locally (no backend calls except username check)
- Step 6 (Password): Call `POST /auth/register` with ALL data
- Step 7: Call `POST /auth/verify-email` (if not auto-verified)
- Store token, navigate to home

**2. Username Availability:**
- Create new endpoint: `GET /auth/check-username?username=xxx`
- Call during typing (debounced 800ms)
- Show real-time feedback

**3. OAuth Flow:**
- After OAuth exchange, check if user needs profile completion
- If new OAuth user → Show profile completion screens
- Collect: password, username, display_name, gender, etc.
- Call: `POST /auth/oauth/complete-profile` (new endpoint)

**4. Signin Flow:**
- Email → Check if user exists (new endpoint or use login with dummy password)
- Show cached account confirmation
- Password → `POST /auth/login`

---

## 🔧 Backend Endpoints to Create/Modify

### New Endpoints Needed:

1. **Username Availability Check**
   ```
   GET /auth/check-username?username=xxx
   Response: {available: true/false, message: "..."}
   ```

2. **OAuth Profile Completion**
   ```
   POST /auth/oauth/complete-profile
   Body: {password, username, display_name, gender, age, bio, profile_picture}
   Response: {success: true, message: "Profile completed"}
   ```

3. **Email Registration Init (Optional)**
   ```
   POST /auth/register-init
   Body: {email}
   Response: {success: true, user_id: "uuid", message: "OTP sent"}
   ```

### Modified Endpoints:

1. **Registration Endpoint**
   - Make password optional initially
   - OR create separate completion endpoint

---

## 📊 Data Flow Diagram

```
Flutter Signup Flow:
┌─────────────┐
│ Email Input │ → Store email locally
└──────┬──────┘
       │
       ↓
┌─────────────┐
│ OTP Verify  │ → POST /auth/register (email only) OR check existing
└──────┬──────┘   → Store user_id locally
       │
       ↓
┌─────────────┐
│ Account Name│ → GET /auth/check-username (real-time)
└──────┬──────┘   → Store username, display_name, gender locally
       │
       ↓
┌─────────────┐
│ Age Screen  │ → Store age locally (optional)
└──────┬──────┘
       │
       ↓
┌─────────────┐
│ Profile     │ → Upload picture to Supabase Storage
└──────┬──────┘   → Store bio, picture_url locally
       │
       ↓
┌─────────────┐
│ Password    │ → POST /auth/register (ALL DATA)
└──────┬──────┘   → POST /auth/verify-email (if needed)
       │          → Store token
       ↓
┌─────────────┐
│ Complete    │ → Navigate to /home
└─────────────┘
```

---

## 🚀 Implementation Steps

### Step 1: Create Backend Endpoints (If Needed)
- Username check endpoint
- OAuth profile completion endpoint

### Step 2: Create Flutter Models
- User model
- AuthResponse model
- SignupState model

### Step 3: Create Auth Service
- Implement all API calls
- Handle token storage
- Error handling

### Step 4: Create State Management
- Signup state provider (using Provider/Riverpod)
- Auth state provider

### Step 5: Integrate Screens
- Connect each screen to service
- Handle navigation based on API responses
- Show loading/error states

### Step 6: Handle OAuth
- Implement OAuth flows
- Handle profile completion for new OAuth users

---

## ⚠️ Important Considerations

1. **Password Requirement:** Backend requires password on registration, but Flutter collects it last
   - **Solution:** Store all data locally, send everything when password is set

2. **Username Uniqueness:** Backend has CheckUsernameExists but no endpoint
   - **Solution:** Create endpoint OR call account service endpoint

3. **OAuth Users Need Password:** Your flow requires password even for OAuth
   - **Solution:** After OAuth, show profile completion screens including password

4. **Cached Account Confirmation:** Not implemented in backend
   - **Solution:** Store last login info in Flutter local storage, show confirmation screen

5. **Database Switching:** Already abstracted via repository pattern
   - **No changes needed** - just implement new repository interface

---

## ✅ Next Steps

1. Review this analysis
2. Decide on registration flow approach (local storage vs backend multi-step)
3. Create missing backend endpoints (if needed)
4. Start implementing Flutter models and services
5. Connect screens one by one

**Ready to proceed with implementation?**
