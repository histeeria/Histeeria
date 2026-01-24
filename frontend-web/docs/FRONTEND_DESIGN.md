# Upvista Community - Frontend Design Specification v1.0

> **Created by:** Hamza Hafeez - Founder & CEO of Upvista  
> **Version:** 1.0.0  
> **Design Philosophy:** iOS-inspired minimal professional design for Gen Z  
> **Date:** November 2025

---

## 🎯 Design Vision

**Objective:** Create a professional, scalable, Gen Z-friendly social platform that combines the visual appeal of Instagram, the professionalism of LinkedIn, and the minimalism of iOS.

**Core Principles:**
- 🎨 **Premium & Sleek:** iPhone 14 Pro Deep Purple inspired
- 🧊 **Glassmorphism:** Modern depth and visual hierarchy
- 📱 **iOS-Inspired:** Minimal, clean, intuitive
- ⚡ **Gen Z Content:** Fresh, engaging, dynamic
- 🎯 **Professional:** No childish colors or emojis
- 📏 **Justified Spacing:** Consistent, predictable layout
- 🔤 **Lower-Medium Typography:** Readable but not oversized

---

## 🎨 Brand Identity

### **Primary Brand Element:**
**Logo:** Vibrant purple "U" with liquid/drip aesthetic
- File: `/public/assets/u.png`
- Usage: Sidebar logo, favicon, loading screens
- Color: Electric purple with modern, fluid design

### **Brand Voice:**
- **Professional yet approachable**
- **Gen Z authentic** (not trying too hard)
- **Authoritative without being corporate**
- **Innovative and forward-thinking**

---

## 🌈 Color System

### **Brand Colors (Primary Palette)**

```typescript
// Based on your vibrant purple logo + iPhone 14 Pro Deep Purple
const brand = {
  // Primary Purple (from logo)
  purple: {
    50: '#FAF5FF',   // Lightest backgrounds
    100: '#F3E8FF',  // Hover states (light mode)
    200: '#E9D5FF',
    300: '#D8B4FE',
    400: '#C084FC',
    500: '#A855F7',  // Main brand purple (logo color)
    600: '#9333EA',  // Primary buttons, active states
    700: '#7E22CE',  // Darker accents
    800: '#6B21A8',  // Deep purple (dark mode accents)
    900: '#581C87',  // Darkest
  },
  
  // Secondary - Deep Purple (iPhone 14 Pro inspired)
  deepPurple: {
    50: '#F5F3FF',
    500: '#8B5CF6',  // Alternative accent
    900: '#4C1D95',  // Dark mode backgrounds
  },
}
```

### **Neutral Colors (iOS Inspired)**

```typescript
const neutral = {
  // Light Mode
  light: {
    bg: {
      primary: '#FFFFFF',      // Main background
      secondary: '#FAFAFA',    // Secondary background
      tertiary: '#F5F5F5',     // Cards, sections
      elevated: '#FFFFFF',     // Elevated cards
    },
    text: {
      primary: '#171717',      // Headings, primary text
      secondary: '#525252',    // Secondary text, captions
      tertiary: '#A3A3A3',     // Placeholder, disabled
      inverse: '#FFFFFF',      // Text on dark backgrounds
    },
    border: {
      default: '#E5E5E5',      // Default borders
      focus: '#A855F7',        // Focused inputs (purple)
      subtle: '#F5F5F5',       // Very subtle dividers
    },
  },
  
  // Dark Mode (Deep Purple Theme)
  dark: {
    bg: {
      primary: '#0A0A0A',      // Main background (true black)
      secondary: '#171717',    // Secondary background
      tertiary: '#262626',     // Cards, sections
      elevated: '#1F1F1F',     // Elevated cards
    },
    text: {
      primary: '#FAFAFA',      // Headings, primary text
      secondary: '#A3A3A3',    // Secondary text
      tertiary: '#525252',     // Placeholder, disabled
      inverse: '#0A0A0A',      // Text on light backgrounds
    },
    border: {
      default: '#262626',      // Default borders
      focus: '#A855F7',        // Focused inputs (purple)
      subtle: '#1F1F1F',       // Very subtle dividers
    },
  },
}
```

### **Semantic Colors**

```typescript
const semantic = {
  success: {
    light: '#10B981',  // Green
    dark: '#34D399',
  },
  error: {
    light: '#EF4444',  // Red
    dark: '#F87171',
  },
  warning: {
    light: '#F59E0B',  // Amber
    dark: '#FBBF24',
  },
  info: {
    light: '#3B82F6',  // Blue
    dark: '#60A5FA',
  },
}
```

### **Glassmorphism Effects**

```typescript
const glass = {
  light: {
    card: 'bg-white/70 backdrop-blur-xl border border-white/20',
    overlay: 'bg-white/50 backdrop-blur-md',
    sidebar: 'bg-white/80 backdrop-blur-2xl border-r border-white/20',
  },
  dark: {
    card: 'bg-gray-900/40 backdrop-blur-xl border border-white/10',
    overlay: 'bg-black/50 backdrop-blur-md',
    sidebar: 'bg-gray-900/60 backdrop-blur-2xl border-r border-white/10',
  },
}
```

---

## 🔤 Typography System

### **Font Families**

```typescript
const fonts = {
  // Sans-serif (primary)
  sans: [
    '-apple-system',
    'BlinkMacSystemFont',
    '"SF Pro Display"',
    '"Segoe UI"',
    'Roboto',
    '"Helvetica Neue"',
    'Arial',
    'sans-serif',
  ].join(', '),
  
  // Monospace (code, numbers)
  mono: [
    '"SF Mono"',
    'Monaco',
    '"Cascadia Code"',
    '"Roboto Mono"',
    'monospace',
  ].join(', '),
}
```

### **Font Scales (Lower-Medium Sizing)**

```typescript
const fontSize = {
  // Body text
  xs: '0.75rem',     // 12px - Captions, metadata
  sm: '0.875rem',    // 14px - Secondary text, labels
  base: '0.9375rem', // 15px - Primary body text (iOS standard)
  
  // Headings
  lg: '1rem',        // 16px - Small headings, button text
  xl: '1.125rem',    // 18px - Card titles
  '2xl': '1.25rem',  // 20px - Section headers
  '3xl': '1.5rem',   // 24px - Page titles
  '4xl': '1.875rem', // 30px - Hero headings
  '5xl': '2.25rem',  // 36px - Large displays
}

const fontWeight = {
  normal: 400,      // Body text
  medium: 500,      // Emphasis
  semibold: 600,    // Headings, buttons
  bold: 700,        // Strong emphasis
}

const lineHeight = {
  tight: 1.2,       // Headings
  normal: 1.4,      // Body text (iOS-like)
  relaxed: 1.6,     // Long-form content
}
```

### **Typography Usage Examples:**

```tsx
// Page Title
<h1 className="text-3xl font-semibold text-neutral-900 dark:text-neutral-50">
  Welcome to Upvista
</h1>

// Section Header
<h2 className="text-2xl font-semibold text-neutral-800 dark:text-neutral-100">
  Your Communities
</h2>

// Card Title
<h3 className="text-xl font-semibold text-neutral-900 dark:text-neutral-50">
  Research Article Title
</h3>

// Body Text
<p className="text-base text-neutral-700 dark:text-neutral-300">
  This is the main content text that users will read.
</p>

// Secondary Text
<span className="text-sm text-neutral-500 dark:text-neutral-400">
  Posted 2 hours ago
</span>

// Caption/Metadata
<span className="text-xs text-neutral-400 dark:text-neutral-500">
  123 views
</span>
```

---

## 📏 Spacing System

### **Base Unit: 4px** (iOS standard)

```typescript
const spacing = {
  0: '0',
  0.5: '0.125rem',  // 2px
  1: '0.25rem',     // 4px
  2: '0.5rem',      // 8px
  3: '0.75rem',     // 12px
  4: '1rem',        // 16px - Base unit
  5: '1.25rem',     // 20px
  6: '1.5rem',      // 24px
  8: '2rem',        // 32px
  10: '2.5rem',     // 40px
  12: '3rem',       // 48px
  16: '4rem',       // 64px
  20: '5rem',       // 80px
  24: '6rem',       // 96px
}
```

### **Common Patterns:**

```tsx
// Card padding
className="p-6"  // 24px all around

// Stack spacing (vertical)
className="space-y-4"  // 16px between children

// Inline spacing (horizontal)
className="space-x-3"  // 12px between children

// Section margins
className="mb-8"  // 32px bottom margin

// Container padding
className="px-4 md:px-6 lg:px-8"  // Responsive padding
```

---

## 🧩 Component Specifications

### **1. Button Component**

**Variants:**

```tsx
// Primary (Purple - Main actions)
<button className="
  px-6 py-3 
  bg-purple-600 hover:bg-purple-700 active:bg-purple-800
  text-white font-semibold text-base
  rounded-xl 
  transition-all duration-200
  shadow-lg shadow-purple-500/30
  hover:shadow-xl hover:shadow-purple-500/40
  disabled:opacity-50 disabled:cursor-not-allowed
">
  Primary Action
</button>

// Secondary (Outlined)
<button className="
  px-6 py-3
  border-2 border-purple-600 hover:border-purple-700
  text-purple-600 dark:text-purple-400 font-semibold text-base
  rounded-xl
  transition-all duration-200
  hover:bg-purple-50 dark:hover:bg-purple-950/30
">
  Secondary Action
</button>

// Ghost (Minimal)
<button className="
  px-4 py-2
  text-neutral-700 dark:text-neutral-300 font-medium text-sm
  rounded-lg
  hover:bg-neutral-100 dark:hover:bg-neutral-800
  transition-colors duration-200
">
  Ghost Action
</button>

// Icon Button
<button className="
  w-10 h-10
  flex items-center justify-center
  rounded-full
  text-neutral-600 dark:text-neutral-400
  hover:bg-neutral-100 dark:hover:bg-neutral-800
  transition-colors duration-200
">
  <Icon />
</button>
```

**Sizes:**
- Small: `px-4 py-2 text-sm` (Secondary actions)
- Medium: `px-6 py-3 text-base` (Primary actions)
- Large: `px-8 py-4 text-lg` (Hero CTAs)

---

### **2. Card Component (Glassmorphic)**

```tsx
// Light Mode Glass Card
<div className="
  rounded-2xl 
  bg-white/70 backdrop-blur-xl 
  border border-white/20
  shadow-xl shadow-neutral-200/50
  p-6
  transition-all duration-300
  hover:shadow-2xl hover:shadow-neutral-300/50
  hover:scale-[1.01]
">
  {children}
</div>

// Dark Mode Glass Card
<div className="
  rounded-2xl
  bg-gray-900/40 backdrop-blur-xl
  border border-white/10
  shadow-xl shadow-black/50
  p-6
  transition-all duration-300
  hover:shadow-2xl hover:shadow-black/60
  hover:scale-[1.01]
">
  {children}
</div>

// Solid Card (Alternative)
<div className="
  rounded-2xl
  bg-white dark:bg-neutral-900
  border border-neutral-200 dark:border-neutral-800
  shadow-lg
  p-6
  transition-all duration-200
  hover:shadow-xl
">
  {children}
</div>
```

---

### **3. Input Component (Floating Label)**

```tsx
// Already implemented in auth pages - reuse this pattern
<div className="relative">
  <input
    type="text"
    placeholder=" "
    className="
      peer w-full
      rounded-2xl
      border-2 border-neutral-300 dark:border-neutral-700
      bg-transparent
      px-5 py-4 text-base
      text-neutral-900 dark:text-neutral-50
      transition-all duration-200
      focus:border-purple-600 focus:outline-none
      placeholder-transparent
    "
  />
  <label className="
    absolute -top-3 left-4
    bg-white dark:bg-neutral-900
    px-2 text-sm font-medium
    text-purple-600 dark:text-purple-400
    peer-placeholder-shown:top-4 
    peer-placeholder-shown:text-base 
    peer-placeholder-shown:text-neutral-400
    peer-focus:-top-3 
    peer-focus:text-sm 
    peer-focus:text-purple-600 dark:peer-focus:text-purple-400
    transition-all duration-200
  ">
    Label Text
  </label>
</div>
```

---

### **4. Avatar Component**

```tsx
// Sizes
const avatarSizes = {
  xs: 'w-6 h-6',      // 24px - Inline mentions
  sm: 'w-8 h-8',      // 32px - Comments
  md: 'w-10 h-10',    // 40px - Feed posts
  lg: 'w-12 h-12',    // 48px - Sidebar
  xl: 'w-16 h-16',    // 64px - Profile headers
  '2xl': 'w-24 h-24', // 96px - Profile pages
  '3xl': 'w-32 h-32', // 128px - Large profile displays
}

// Implementation
<div className="relative">
  {/* Avatar Image */}
  <img
    src={user.profile_picture || '/default-avatar.png'}
    alt={user.display_name}
    className="
      w-10 h-10 
      rounded-full 
      object-cover
      border-2 border-white dark:border-neutral-800
      shadow-md
    "
  />
  
  {/* Online Status Indicator (optional) */}
  <div className="
    absolute -bottom-0.5 -right-0.5
    w-3 h-3
    bg-green-500
    border-2 border-white dark:border-neutral-900
    rounded-full
  " />
</div>
```

---

### **5. Badge/Tag Component**

```tsx
// Purple Badge (primary)
<span className="
  inline-flex items-center
  px-3 py-1
  rounded-full
  bg-purple-100 dark:bg-purple-900/30
  text-purple-700 dark:text-purple-300
  text-xs font-medium
  border border-purple-200 dark:border-purple-800/50
">
  Research
</span>

// Neutral Badge
<span className="
  inline-flex items-center
  px-3 py-1
  rounded-full
  bg-neutral-100 dark:bg-neutral-800
  text-neutral-700 dark:text-neutral-300
  text-xs font-medium
">
  New
</span>

// Status Badges
{/* Online */}
<span className="px-2 py-1 rounded-md bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-300 text-xs font-medium">
  Active
</span>

{/* Verified */}
<span className="inline-flex items-center gap-1 px-2 py-1 rounded-md bg-blue-100 dark:bg-blue-900/30 text-blue-700 dark:text-blue-300 text-xs font-medium">
  <VerifiedIcon size={12} /> Verified
</span>
```

---

## 📱 Layout System

### **Desktop Layout (1024px+)**

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Screen (100vw × 100vh)                      │
├──────────────┬──────────────────────────────────┬───────────────────┤
│   Sidebar    │         Main Content             │   Right Panel     │
│   240px      │         flex-1 (max-w-4xl)       │   320px           │
│   fixed      │         centered                 │   sticky          │
│   h-screen   │                                  │   (optional)      │
│              │                                  │                   │
│  [Logo]      │  [Page Content]                  │  [Suggestions]    │
│  Nav Items   │                                  │  [Trending]       │
│  ...         │                                  │  [Ads]            │
│              │                                  │                   │
│  [Profile]   │                                  │                   │
│  [More]      │                                  │                   │
└──────────────┴──────────────────────────────────┴───────────────────┘
```

**Implementation:**
```tsx
<div className="flex min-h-screen bg-neutral-50 dark:bg-neutral-950">
  {/* Sidebar */}
  <aside className="hidden lg:flex w-60 fixed h-screen">
    <Sidebar />
  </aside>
  
  {/* Main Content */}
  <main className="flex-1 lg:ml-60">
    <div className="max-w-4xl mx-auto px-4 py-6">
      {children}
    </div>
  </main>
  
  {/* Right Panel (optional) */}
  <aside className="hidden xl:block w-80 sticky top-0 h-screen">
    <RightPanel />
  </aside>
</div>
```

---

### **Mobile Layout (<1024px)**

```
┌────────────────────────┐
│      Top Bar (64px)    │
│  [U] Upvista  🔔💼💬  │
├────────────────────────┤
│                        │
│                        │
│    Main Content        │
│    (Full width)        │
│    pt-16 pb-16         │
│                        │
│                        │
├────────────────────────┤
│   Bottom Nav (64px)    │
│  🏠  👥  ➕  🌐  👤  │
└────────────────────────┘
```

**Implementation:**
```tsx
<div className="min-h-screen bg-neutral-50 dark:bg-neutral-950">
  {/* Top Bar (mobile only) */}
  <header className="lg:hidden fixed top-0 w-full h-16 z-50">
    <Topbar />
  </header>
  
  {/* Main Content */}
  <main className="pt-16 pb-16 lg:pt-0 lg:pb-0">
    {children}
  </main>
  
  {/* Bottom Nav (mobile only) */}
  <nav className="lg:hidden fixed bottom-0 w-full h-16 z-50">
    <BottomNav />
  </nav>
</div>
```

---

## 🧭 Navigation Structure

### **Sidebar Navigation (Desktop)**

```tsx
// components/layout/Sidebar.tsx

const navigation = [
  { name: 'Home', href: '/home', icon: HomeIcon, color: 'purple' },
  { name: 'Search', href: '/search', icon: SearchIcon },
  { name: 'Communities', href: '/communities', icon: UsersIcon },
  { name: 'Explore', href: '/explore', icon: CompassIcon },
  { name: 'Messages', href: '/messages', icon: MessageCircleIcon, badge: 3 },
  { name: 'Notifications', href: '/notifications', icon: BellIcon, badge: 12 },
  { name: 'Create', href: '/create', icon: PlusSquareIcon, color: 'purple' },
  { name: 'Collaborate', href: '/collaborate', icon: UsersIcon },
  { name: 'Jobs', href: '/jobs', icon: BriefcaseIcon },
  { name: 'Profile', href: '/profile', icon: UserIcon },
]

const moreMenu = [
  { name: 'Settings', icon: SettingsIcon },
  { name: 'Your Activity', icon: ActivityIcon },
  { name: 'Saved', icon: BookmarkIcon },
  { name: 'Your Earnings', icon: DollarSignIcon },
  { name: 'Account Summary', icon: BarChartIcon },
  { name: 'Switch Profiles', icon: UserSwitchIcon },
  { name: 'Switch Theme', icon: SunMoonIcon },
  { name: 'Switch Language', icon: LanguagesIcon },
  { name: 'Report a Problem', icon: AlertCircleIcon },
  { name: 'Logout', icon: LogOutIcon, color: 'red' },
]

<nav className="
  w-60 h-screen fixed
  bg-white/80 dark:bg-gray-900/60
  backdrop-blur-2xl
  border-r border-neutral-200/50 dark:border-neutral-800/50
  flex flex-col
  py-6 px-4
">
  {/* Logo */}
  <div className="flex items-center gap-3 px-4 mb-8">
    <img src="/assets/u.png" alt="Upvista" className="w-10 h-10" />
    <h1 className="text-xl font-bold">
      <span className="bg-gradient-to-r from-purple-600 to-purple-400 bg-clip-text text-transparent">
        Upvista
      </span>
      {' '}
      <span className="text-neutral-900 dark:text-neutral-100">
        Community
      </span>
    </h1>
  </div>
  
  {/* Navigation Items */}
  <div className="flex-1 space-y-1">
    {navigation.map(item => (
      <NavItem key={item.name} {...item} />
    ))}
  </div>
  
  {/* More Button */}
  <button className="... (expands moreMenu)">
    More
  </button>
</nav>
```

**Nav Item Specs:**

```tsx
// Active state
<a className="
  flex items-center gap-4
  px-4 py-3
  rounded-xl
  bg-purple-100 dark:bg-purple-900/30
  text-purple-600 dark:text-purple-400
  font-semibold
  border-l-4 border-purple-600
">
  <Icon className="w-6 h-6" />
  <span>Home</span>
  {badge && <Badge>{badge}</Badge>}
</a>

// Inactive state
<a className="
  flex items-center gap-4
  px-4 py-3
  rounded-xl
  text-neutral-700 dark:text-neutral-300
  font-medium
  hover:bg-neutral-100 dark:hover:bg-neutral-800
  transition-colors duration-200
">
  <Icon className="w-6 h-6" />
  <span>Search</span>
</a>
```

---

### **Top Bar (Mobile)**

```tsx
<header className="
  h-16 w-full
  bg-white/80 dark:bg-gray-900/60
  backdrop-blur-2xl
  border-b border-neutral-200/50 dark:border-neutral-800/50
  px-4
  flex items-center justify-between
">
  {/* Left: Logo */}
  <div className="flex items-center gap-2">
    <img src="/assets/u.png" className="w-8 h-8" />
    <span className="text-lg font-bold bg-gradient-to-r from-purple-600 to-purple-400 bg-clip-text text-transparent">
      Upvista
    </span>
  </div>
  
  {/* Right: Action Icons */}
  <div className="flex items-center gap-2">
    <IconButton icon={BellIcon} badge={12} />
    <IconButton icon={BriefcaseIcon} />
    <IconButton icon={MessageCircleIcon} badge={3} />
  </div>
</header>
```

---

### **Bottom Navigation (Mobile)**

```tsx
<nav className="
  h-16 w-full
  bg-white/80 dark:bg-gray-900/60
  backdrop-blur-2xl
  border-t border-neutral-200/50 dark:border-neutral-800/50
  px-4
  flex items-center justify-around
">
  <NavIcon icon={HomeIcon} label="Home" active />
  <NavIcon icon={UsersIcon} label="Communities" />
  <NavIcon icon={PlusSquareIcon} label="Create" color="purple" />
  <NavIcon icon={CompassIcon} label="Explore" />
  <NavIcon icon={UserIcon} label="Profile" />
</nav>
```

---

## 📄 Page Layouts

### **Home Page** (`app/(main)/home/page.tsx`)

**Layout:**
```
┌─────────────────────────────────────────────────┐
│  Category Tabs (Horizontal Scroll)             │
│  [ All ][ Communities ][ Research ][ Projects ] │
├─────────────────────────────────────────────────┤
│                                                 │
│  Feed Card (Glass)                             │
│  ┌──────────────────────────────────────────┐  │
│  │  👤 John Doe   [@johndoe]     2h ago     │  │
│  │  🏷️ Research Article                    │  │
│  ├──────────────────────────────────────────┤  │
│  │  "The Future of AI in Healthcare..."     │  │
│  │  [Read more]                             │  │
│  ├──────────────────────────────────────────┤  │
│  │  💜 245   💬 32   🔗 Share              │  │
│  └──────────────────────────────────────────┘  │
│                                                 │
│  Feed Card (Glass)                             │
│  [Repeat pattern]                              │
│                                                 │
│  [Load More - Infinite Scroll]                 │
│                                                 │
│  --- OR Empty State ---                        │
│                                                 │
│  ┌──────────────────────────────────────────┐  │
│  │          🌟 Welcome to Upvista!          │  │
│  │                                          │  │
│  │  No posts yet. Start exploring or        │  │
│  │  create your first post!                 │  │
│  │                                          │  │
│  │  [Explore Communities]  [Create Post]    │  │
│  └──────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘
```

**Components:**
- `CategoryTabs` - Horizontal scrolling, pill-shaped active state
- `FeedCard` - Glassmorphic post container
- `PostActions` - Like, comment, share buttons
- `EmptyFeed` - Engaging empty state
- `InfiniteScroll` - Load more on scroll

---

### **Search Page** (`app/(main)/search/page.tsx`)

**Layout:**
```
┌─────────────────────────────────────────────────┐
│  🔍 Search for anything...        [Filters 🎚️] │
├─────────────────────────────────────────────────┤
│  Quick Filters:                                  │
│  [ All ][ Profiles ][ Posts ][ Communities ]... │
├─────────────────────────────────────────────────┤
│                                                 │
│  Results (if search active)                     │
│  ┌──────────────────────────────────────────┐  │
│  │  👤 Profile Result                       │  │
│  │  @username - "Bio here"    [Follow]      │  │
│  └──────────────────────────────────────────┘  │
│                                                 │
│  ┌──────────────────────────────────────────┐  │
│  │  📄 Post Result                          │  │
│  │  "Title" - 2h ago                        │  │
│  └──────────────────────────────────────────┘  │
│                                                 │
│  --- OR Recent Searches ---                     │
│                                                 │
│  Recent:                                        │
│  🕒 "machine learning"                          │
│  🕒 "design community"                          │
│                                                 │
│  Trending:                                      │
│  🔥 #AI2025                                     │
│  🔥 #WebDevelopment                             │
└─────────────────────────────────────────────────┘
```

**Features:**
- Debounced search (300ms)
- Real-time results
- Filter by category
- Recent searches stored (localStorage)
- Trending topics

---

### **Communities Page** (`app/(main)/communities/page.tsx`)

**Three-Column Layout (Desktop):**

```
┌──────────────┬───────────────────────────┬──────────────────┐
│ My           │  Community Feed           │  Discover        │
│ Communities  │  (Selected community)     │  Communities     │
│ (240px)      │  (flex-1)                 │  (280px)         │
├──────────────┼───────────────────────────┼──────────────────┤
│ [+ Create]   │  📍 Design Team           │  [Search]        │
│              │  1.2k members             │                  │
│ JOINED (5)   │  ──────────────────────   │  📊 Tech Hub     │
│ ● Design     │                           │  24k members     │
│   Team       │  Post in community        │  [Join] →        │
│ ● Dev Club   │  [Content]                │                  │
│ ● Research   │                           │  🎨 Designers    │
│              │  Post in community        │  8.5k members    │
│ DISCOVER     │  [Content]                │  [Join] →        │
│ → Tech       │                           │                  │
│ → Design     │  [Load More]              │  💼 Startups     │
│ → Business   │                           │  12k members     │
│              │                           │  [Join] →        │
└──────────────┴───────────────────────────┴──────────────────┘
```

**Mobile (Stacked):**
- Top: My communities (horizontal scroll)
- Middle: Selected community feed
- Bottom: Discover button (opens modal/sheet)

---

### **Profile Page** (`app/(main)/profile/page.tsx`)

**Layout:**
```
┌─────────────────────────────────────────────────┐
│  Cover Image (glassmorphic gradient)           │
│  ┌────────────────────────────────────────────┐│
│  │                                            ││
│  │        Profile Header                      ││
│  │        ┌──────┐                           ││
│  │        │ Ava- │  John Doe                 ││
│  │        │ tar  │  @johndoe                 ││
│  │        └──────┘  Bio text here...         ││
│  │                  📍 Location • 🔗 Link    ││
│  │                                            ││
│  │        [Edit Profile]  [Share]             ││
│  └────────────────────────────────────────────┘│
├─────────────────────────────────────────────────┤
│  Stats Bar (Glass)                              │
│  250 Posts  •  1.2k Followers  •  340 Following │
├─────────────────────────────────────────────────┤
│  Tabs: [ Posts ][ Research ][ Communities ]     │
├─────────────────────────────────────────────────┤
│                                                 │
│  Content Grid/Feed                              │
│  (Based on selected tab)                        │
│                                                 │
└─────────────────────────────────────────────────┘
```

---

### **Create Page** (`app/(main)/create/page.tsx`)

**Modal/Full Page:**
```
┌─────────────────────────────────────────────────┐
│  ← Back          Create Post          [Post] → │
├─────────────────────────────────────────────────┤
│                                                 │
│  Post Type:                                     │
│  [ Text ][ Article ][ Reel ][ Research ]        │
│                                                 │
│  ─────────────────────────────────────────────  │
│                                                 │
│  📝 What's on your mind?                        │
│  [Large text area - glassmorphic]               │
│                                                 │
│  ─────────────────────────────────────────────  │
│                                                 │
│  📎 [Attach Media]  🏷️ [Add Tags]  🌐 [Visibility]│
│                                                 │
│  Community: [Select community ▼]                │
│  Category: [Select category ▼]                  │
│  Tags: [AI, Research, Innovation]               │
│                                                 │
└─────────────────────────────────────────────────┘
```

---

## 🎨 Component Design Specifications

### **Feed Card (Main Content Card)**

```tsx
<article className="
  rounded-2xl
  bg-white/70 dark:bg-gray-900/40
  backdrop-blur-xl
  border border-neutral-200/50 dark:border-neutral-800/50
  shadow-lg
  p-6
  transition-all duration-200
  hover:shadow-xl
  hover:scale-[1.005]
">
  {/* Header */}
  <div className="flex items-start justify-between mb-4">
    <div className="flex items-center gap-3">
      <Avatar size="md" src={user.avatar} />
      <div>
        <h3 className="text-base font-semibold text-neutral-900 dark:text-neutral-50">
          {user.name}
        </h3>
        <p className="text-sm text-neutral-500 dark:text-neutral-400">
          @{user.username} • 2h ago
        </p>
      </div>
    </div>
    <button className="text-neutral-400 hover:text-neutral-600">⋮</button>
  </div>
  
  {/* Category Badge */}
  <div className="mb-3">
    <Badge variant="purple">Research Article</Badge>
  </div>
  
  {/* Content */}
  <div className="mb-4">
    <h2 className="text-xl font-semibold text-neutral-900 dark:text-neutral-50 mb-2">
      The Future of AI in Healthcare
    </h2>
    <p className="text-base text-neutral-700 dark:text-neutral-300 line-clamp-3">
      Lorem ipsum dolor sit amet, consectetur adipiscing elit...
    </p>
  </div>
  
  {/* Media (if exists) */}
  <img src="..." className="rounded-xl mb-4 w-full" />
  
  {/* Actions */}
  <div className="flex items-center gap-6 text-neutral-600 dark:text-neutral-400">
    <button className="flex items-center gap-2 hover:text-purple-600 transition-colors">
      <HeartIcon className="w-5 h-5" />
      <span className="text-sm font-medium">245</span>
    </button>
    <button className="flex items-center gap-2 hover:text-purple-600 transition-colors">
      <MessageCircleIcon className="w-5 h-5" />
      <span className="text-sm font-medium">32</span>
    </button>
    <button className="flex items-center gap-2 hover:text-purple-600 transition-colors">
      <Share2Icon className="w-5 h-5" />
    </button>
    <button className="ml-auto flex items-center gap-2 hover:text-purple-600 transition-colors">
      <BookmarkIcon className="w-5 h-5" />
    </button>
  </div>
</article>
```

---

### **Category Tabs (Horizontal Scroll)**

```tsx
<div className="
  flex gap-2
  overflow-x-auto
  scrollbar-hide
  pb-1
  mb-6
">
  {categories.map(cat => (
    <button
      key={cat}
      className={`
        px-4 py-2
        rounded-full
        text-sm font-semibold
        whitespace-nowrap
        transition-all duration-200
        ${active 
          ? 'bg-purple-600 text-white shadow-lg shadow-purple-500/30' 
          : 'bg-neutral-100 dark:bg-neutral-800 text-neutral-700 dark:text-neutral-300 hover:bg-neutral-200 dark:hover:bg-neutral-700'
        }
      `}
    >
      {cat}
    </button>
  ))}
</div>
```

---

## 🎭 Theme Context Implementation

### **Theme Provider:**

```tsx
// lib/contexts/ThemeContext.tsx

'use client';

import { createContext, useContext, useEffect, useState } from 'react';

type Theme = 'light' | 'dark';

interface ThemeContextType {
  theme: Theme;
  setTheme: (theme: Theme) => void;
  toggleTheme: () => void;
}

const ThemeContext = createContext<ThemeContextType | undefined>(undefined);

export function ThemeProvider({ children }: { children: React.ReactNode }) {
  const [theme, setTheme] = useState<Theme>('light');

  useEffect(() => {
    // Load from localStorage
    const stored = localStorage.getItem('theme') as Theme;
    if (stored) {
      setTheme(stored);
      document.documentElement.classList.toggle('dark', stored === 'dark');
    }
  }, []);

  const toggleTheme = () => {
    const newTheme = theme === 'light' ? 'dark' : 'light';
    setTheme(newTheme);
    localStorage.setItem('theme', newTheme);
    document.documentElement.classList.toggle('dark', newTheme === 'dark');
  };

  return (
    <ThemeContext.Provider value={{ theme, setTheme, toggleTheme }}>
      {children}
    </ThemeContext.Provider>
  );
}

export const useTheme = () => {
  const context = useContext(ThemeContext);
  if (!context) throw new Error('useTheme must be used within ThemeProvider');
  return context;
};
```

**Usage:**
```tsx
const { theme, toggleTheme } = useTheme();

<button onClick={toggleTheme}>
  {theme === 'light' ? <MoonIcon /> : <SunIcon />}
</button>
```

---

## 🎬 Animations & Interactions

### **Smooth Transitions (iOS-like)**

```tsx
// Page transitions
const pageVariants = {
  initial: { opacity: 0, y: 20 },
  animate: { opacity: 1, y: 0 },
  exit: { opacity: 0, y: -20 },
}

<motion.div
  variants={pageVariants}
  initial="initial"
  animate="animate"
  exit="exit"
  transition={{ duration: 0.3, ease: 'easeOut' }}
>
  {children}
</motion.div>

// Card hover
<motion.div
  whileHover={{ scale: 1.01, y: -2 }}
  whileTap={{ scale: 0.99 }}
  transition={{ duration: 0.2 }}
>
  <Card />
</motion.div>

// Button press
<motion.button
  whileTap={{ scale: 0.95 }}
  transition={{ duration: 0.1 }}
>
  Click me
</motion.button>
```

**Animation Principles:**
- **Subtle:** Not distracting
- **Fast:** 200-300ms max
- **Purposeful:** Provides feedback
- **Smooth:** Ease-out curves (iOS standard)

---

## 📐 Responsive Breakpoints

```typescript
const breakpoints = {
  sm: '640px',   // Mobile landscape
  md: '768px',   // Tablet
  lg: '1024px',  // Desktop (sidebar appears)
  xl: '1280px',  // Large desktop (right panel appears)
  '2xl': '1536px', // Extra large
}
```

**Usage:**
```tsx
className="
  w-full        // Mobile: full width
  md:w-1/2      // Tablet: 50% width
  lg:w-1/3      // Desktop: 33% width
  xl:w-1/4      // Large: 25% width
"
```

---

## 🎨 Design Tokens (Tailwind Config)

```typescript
// tailwind.config.ts

export default {
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        brand: {
          purple: {
            50: '#FAF5FF',
            500: '#A855F7',  // Main
            600: '#9333EA',  // Primary buttons
            900: '#581C87',
          },
        },
      },
      fontSize: {
        xs: '0.75rem',
        sm: '0.875rem',
        base: '0.9375rem',  // 15px iOS standard
        lg: '1rem',
        xl: '1.125rem',
        '2xl': '1.25rem',
        '3xl': '1.5rem',
      },
      borderRadius: {
        'xl': '0.75rem',   // 12px
        '2xl': '1rem',     // 16px
        '3xl': '1.5rem',   // 24px
      },
      backdropBlur: {
        xs: '2px',
        sm: '4px',
        md: '8px',
        lg: '12px',
        xl: '16px',
        '2xl': '24px',
        '3xl': '32px',
      },
    },
  },
}
```

---

## 📱 Specific Page Designs

### **Settings Page** (`app/(main)/settings/page.tsx`)

**Layout:**
```
┌─────────────────────────────────────────────────┐
│  ← Back to Profile        Settings              │
├────────────┬────────────────────────────────────┤
│ Sidebar    │  Content Area                      │
│ (220px)    │                                    │
│            │  Account                            │
│ • Account  │  ┌──────────────────────────────┐  │
│ • Privacy  │  │  Profile Picture             │  │
│ • Security │  │  [Upload new]                │  │
│ • Sessions │  │                              │  │
│ • Data     │  │  Email: user@example.com     │  │
│ • Language │  │  [Change]                    │  │
│ • Theme    │  │                              │  │
│ • Help     │  │  Username: @johndoe          │  │
│            │  │  [Change] (Next: 15 days)    │  │
│            │  └──────────────────────────────┘  │
│            │                                    │
│            │  Danger Zone                       │
│            │  [Deactivate] [Delete Account]    │
└────────────┴────────────────────────────────────┘
```

---

## 🎯 Implementation Priority

### **Phase 1: Foundation** (Week 1)
1. Design tokens (colors, typography, spacing)
2. Theme context (dark/light switching)
3. Base UI components:
   - Button (all variants)
   - Card (glass + solid)
   - Input (floating label)
   - Avatar
   - Badge
   - Icon Button

### **Phase 2: Layout** (Week 1-2)
4. Sidebar component (desktop)
5. Topbar component (mobile)
6. BottomNav component (mobile)
7. MainLayout wrapper
8. Responsive behavior

### **Phase 3: Core Pages** (Week 2)
9. Home page (with empty feed)
10. Profile page (with mock data)
11. Settings page (connect to backend APIs)
12. Search page (with demo results)

### **Phase 4: Features** (Week 3)
13. Communities page
14. Create post modal
15. Messages page skeleton
16. Notifications page

### **Phase 5: Backend Integration** (Week 3-4)
17. Connect all pages to APIs
18. Real data fetching
19. Authentication flow
20. Protected routes

---

## 📦 Required NPM Packages

```bash
# UI & Icons
npm install lucide-react          # Professional icons (iOS-like)
npm install framer-motion         # Smooth animations
npm install @radix-ui/react-*     # Accessible components

# State Management
npm install zustand               # Lightweight state (theme, user)

# Utilities
npm install clsx                  # Conditional classes
npm install tailwind-merge        # Merge Tailwind classes
npm install date-fns              # Date formatting

# Forms (if needed)
npm install react-hook-form       # Form management
npm install zod                   # Validation
```

---

## 🎨 Design Principles

### **1. Consistency**
- Same spacing everywhere (4px base)
- Same border radius (16px/24px)
- Same transitions (200ms)
- Same hover states

### **2. Hierarchy**
- Size indicates importance
- Color draws attention
- Spacing creates groups
- Borders separate sections

### **3. Feedback**
- Hover states on all interactive elements
- Active states clearly visible
- Loading states for async operations
- Success/error states

### **4. Accessibility**
- High contrast ratios (WCAG AA)
- Focus indicators visible
- Keyboard navigation
- Screen reader friendly

---

## 🎯 **Next Steps to Implement**

**In agent mode, tell me:**

*"Build the design system foundation (Phase 1) with:*
- *Tailwind config with custom theme*
- *Theme context for dark/light mode*
- *Base UI components (Button, Card, Input, Avatar, Badge)*
- *Then build the Sidebar and create Home page demo"*

**I'll create:**
1. ✅ Complete Tailwind configuration with your purple branding
2. ✅ Theme provider with dark/light switching
3. ✅ Reusable component library
4. ✅ Sidebar with your navigation structure
5. ✅ Home page with glassmorphic feed cards
6. ✅ Empty state designs
7. ✅ Responsive mobile navigation

**Then you can:**
- Review the design
- Approve or request changes
- I replicate pattern across all pages

---

## 📋 Design Checklist

Before starting implementation:

- [x] Brand color defined (Vibrant Purple #A855F7)
- [x] Color palette created (light + dark modes)
- [x] Typography system defined
- [x] Spacing scale established
- [x] Component specifications written
- [x] Layout structure decided
- [x] Navigation structure finalized
- [x] Page layouts designed
- [x] Responsive behavior planned
- [x] Animation principles set

**Ready to build!** ✅

---

**Created with vision by Hamza Hafeez**  
Founder & CEO, Upvista  
*Building the future of professional social networking* 🚀

