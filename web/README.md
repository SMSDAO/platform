# Platform Web — Flash Glow Neo Dashboard

> Full-stack Next.js 15 web application with Flash Glow Neo UI, RBAC, and Prisma.

## Quick Start

```bash
npm install
cp .env.example .env       # edit NEXTAUTH_SECRET
npm run db:push            # create SQLite schema
npm run db:seed            # seed demo users
npm run dev                # http://localhost:3000
```

## Demo Accounts

| Email | Password | Role | Access |
|---|---|---|---|
| `admin@admin.com` | `admin123` | Admin | Dashboard, Admin Panel, Profile |
| `dev@admin.com` | `developer123` | Developer | All routes including Dev Panel |

Register any new account at `/auth/register` — it defaults to the **User** role.

## Environment Variables

| Variable | Required | Description |
|---|---|---|
| `DATABASE_URL` | ✅ | `file:./dev.db` for SQLite; or a Postgres URL |
| `NEXTAUTH_SECRET` | ✅ | Random secret for JWT signing (`openssl rand -base64 32`) |
| `NEXTAUTH_URL` | ✅ | Full base URL of the app, e.g. `http://localhost:3000` |

## Scripts

| Command | Description |
|---|---|
| `npm run dev` | Start development server |
| `npm run build` | Build production bundle |
| `npm run start` | Start production server |
| `npm run db:generate` | Regenerate Prisma client after schema changes |
| `npm run db:push` | Push schema to database (creates tables) |
| `npm run db:seed` | Seed demo admin and developer accounts |
| `npm run lint` | Run ESLint |

## Vercel Deployment

The `vercel.json` in this directory configures one-click deployment.

1. Click the **Deploy to Vercel** button in the root README
2. Set the three environment variables in the Vercel dashboard:
   - `DATABASE_URL` — use a Postgres provider (e.g. [Neon](https://neon.tech) free tier) for production
   - `NEXTAUTH_SECRET` — generate with `openssl rand -base64 32`
   - `NEXTAUTH_URL` — your Vercel project URL

> **Note:** SQLite (`file:./dev.db`) works locally but is not persistent on Vercel's serverless functions. For production, set `DATABASE_URL` to a Postgres connection string and change `provider = "postgresql"` in `prisma/schema.prisma`.

## RBAC

Route permissions are defined in `src/lib/rbac.ts`:

```ts
export const ROUTE_PERMISSIONS: Record<string, Role[]> = {
  '/dashboard':       ['user', 'admin', 'developer'],
  '/dashboard/admin': ['admin', 'developer'],
  '/dashboard/dev':   ['developer'],
  '/profile':         ['user', 'admin', 'developer'],
}
```

NextAuth middleware in `src/middleware.ts` enforces these on every request — no client-side-only guards.

## Flash Glow Neo Design System

### Color Tokens

| Token | Hex | Usage |
|---|---|---|
| `neon-cyan` | `#00d4ff` | Primary accent, links, active states |
| `neon-purple` | `#a855f7` | Secondary accent, admin badges |
| `neon-green` | `#00ff88` | Success states, developer badge |
| `dark-base` | `#0a0a0f` | Page background |
| `dark-card` | `#0f0f1a` | Card backgrounds |
| `dark-border` | `#1a1a2e` | Dividers, inactive borders |

### Utility Classes (globals.css)

```css
.glow-cyan     /* Cyan box-shadow halo */
.glow-purple   /* Purple box-shadow halo */
.glow-green    /* Green box-shadow halo */
.text-glow-cyan    /* Cyan neon text-shadow */
.text-glow-purple  /* Purple neon text-shadow */
.text-glow-green   /* Green neon text-shadow */
.glass         /* Glassmorphism card */
.glass-dark    /* Darker glass variant */
.gradient-border   /* Animated gradient border */
.neon-grid     /* Dot-grid background */
```

### Adding New Pages

1. Create `src/app/your-page/page.tsx`
2. Add route + required roles to `src/lib/rbac.ts` → `ROUTE_PERMISSIONS`
3. Add a nav link in `src/components/layout/Navbar.tsx` gated by `session.user.role`

### Adding New Roles

1. Update `Role` type in `src/lib/rbac.ts`
2. Update `ROLE_HIERARCHY` and `ROUTE_PERMISSIONS`
3. Update `prisma/schema.prisma` comment documentation (the role is stored as a plain `String`)
4. Update `src/types/next-auth.d.ts` if needed

## Project Structure

```
web/
├── .env.example
├── vercel.json                      # Vercel deploy config
├── next.config.js
├── tailwind.config.js               # Flash Glow Neo color tokens + animations
├── prisma/
│   ├── schema.prisma                # User model (id, email, password, role)
│   └── seed.ts                      # Seed admin + developer users
└── src/
    ├── middleware.ts                 # NextAuth route protection
    ├── types/next-auth.d.ts          # Session type augmentation (id + role)
    ├── app/
    │   ├── layout.tsx               # Root layout + SessionProvider
    │   ├── globals.css              # Tailwind directives + glow utilities
    │   ├── providers.tsx            # NextAuth SessionProvider wrapper
    │   ├── page.tsx                 # Public landing page
    │   ├── auth/
    │   │   ├── login/page.tsx       # Sign-in form
    │   │   └── register/page.tsx    # Registration form
    │   ├── dashboard/
    │   │   ├── page.tsx             # Main dashboard (all roles)
    │   │   ├── admin/page.tsx       # Admin panel (admin + developer)
    │   │   └── dev/page.tsx         # Developer panel (developer only)
    │   ├── profile/page.tsx         # Profile + access permissions view
    │   └── api/
    │       └── auth/
    │           ├── [...nextauth]/   # NextAuth handler (GET + POST)
    │           └── register/        # User self-registration API
    ├── components/
    │   └── layout/
    │       └── Navbar.tsx           # Role-aware top navigation
    └── lib/
        ├── auth.ts                  # NextAuth options (CredentialsProvider)
        ├── prisma.ts                # Prisma client singleton
        └── rbac.ts                  # Role types + permission helpers
```
