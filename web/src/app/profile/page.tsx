import { getServerSession } from 'next-auth'
import { authOptions } from '@/lib/auth'
import { redirect } from 'next/navigation'
import { Navbar } from '@/components/layout/Navbar'
import { prisma } from '@/lib/prisma'
import { User, Mail, Shield, Calendar, Edit3 } from 'lucide-react'

const roleConfig: Record<string, { color: string; label: string; description: string; badgeClass: string }> = {
  admin: {
    color: 'neon-purple',
    label: 'Admin',
    description: 'Full platform access',
    badgeClass: 'bg-neon-purple/10 text-neon-purple border-neon-purple/20',
  },
  developer: {
    color: 'neon-green',
    label: 'Developer',
    description: 'Developer tools access',
    badgeClass: 'bg-neon-green/10 text-neon-green border-neon-green/20',
  },
  user: {
    color: 'neon-cyan',
    label: 'User',
    description: 'Standard access',
    badgeClass: 'bg-neon-cyan/10 text-neon-cyan border-neon-cyan/20',
  },
}

export default async function ProfilePage() {
  const session = await getServerSession(authOptions)

  if (!session) redirect('/auth/login')

  const user = await prisma.user.findUnique({
    where: { id: session.user.id },
    select: { id: true, email: true, name: true, role: true, createdAt: true },
  })

  if (!user) redirect('/auth/login')

  const roleInfo = roleConfig[user.role] || roleConfig.user

  return (
    <div className="min-h-screen bg-dark-base">
      <Navbar />
      <main className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8 pt-24">
        <div className="mb-8">
          <h1 className="text-3xl font-bold text-white">Profile</h1>
          <p className="text-slate-400 mt-1">Manage your account settings</p>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* Profile Card */}
          <div className="glass rounded-2xl p-6 border border-white/5 text-center">
            <div className="w-20 h-20 rounded-full bg-gradient-to-br from-neon-cyan to-neon-purple flex items-center justify-center text-3xl font-bold text-dark-base mx-auto mb-4">
              {(user.name || user.email)[0].toUpperCase()}
            </div>
            <h2 className="text-xl font-bold text-white">{user.name || 'No name set'}</h2>
            <p className="text-slate-400 text-sm mt-1">{user.email}</p>
            <div className={`inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-medium mt-3 border ${roleInfo.badgeClass}`}>
              <Shield className="w-3 h-3" />
              {roleInfo.label}
            </div>
            <button className="w-full mt-4 flex items-center justify-center gap-2 py-2 rounded-xl glass border border-white/10 text-slate-300 hover:border-neon-cyan/30 transition-all text-sm">
              <Edit3 className="w-4 h-4" /> Edit Profile
            </button>
          </div>

          {/* Details */}
          <div className="lg:col-span-2 space-y-4">
            <div className="glass rounded-2xl p-6 border border-white/5">
              <h3 className="text-lg font-semibold text-white mb-4">Account Information</h3>
              <div className="space-y-4">
                {[
                  { icon: <User className="w-4 h-4" />, label: 'Full Name', value: user.name || 'Not set' },
                  { icon: <Mail className="w-4 h-4" />, label: 'Email Address', value: user.email },
                  { icon: <Shield className="w-4 h-4" />, label: 'Role', value: `${roleInfo.label} — ${roleInfo.description}` },
                  {
                    icon: <Calendar className="w-4 h-4" />,
                    label: 'Member Since',
                    value: new Date(user.createdAt).toLocaleDateString('en-US', {
                      year: 'numeric',
                      month: 'long',
                      day: 'numeric',
                    }),
                  },
                ].map((field, i) => (
                  <div key={i} className="flex items-start gap-3 py-3 border-b border-white/5 last:border-0">
                    <div className="w-8 h-8 rounded-lg bg-white/5 flex items-center justify-center text-slate-400 flex-shrink-0 mt-0.5">
                      {field.icon}
                    </div>
                    <div>
                      <div className="text-xs text-slate-500 mb-0.5">{field.label}</div>
                      <div className="text-sm text-white">{field.value}</div>
                    </div>
                  </div>
                ))}
              </div>
            </div>

            {/* Access Permissions */}
            <div className="glass rounded-2xl p-6 border border-white/5">
              <h3 className="text-lg font-semibold text-white mb-4">Access Permissions</h3>
              <div className="space-y-2">
                {[
                  { route: '/dashboard', label: 'Main Dashboard', allowed: true },
                  { route: '/profile', label: 'Profile Settings', allowed: true },
                  { route: '/dashboard/admin', label: 'Admin Panel', allowed: ['admin', 'developer'].includes(user.role) },
                  { route: '/dashboard/dev', label: 'Developer Panel', allowed: user.role === 'developer' },
                ].map((perm, i) => (
                  <div key={i} className="flex items-center justify-between py-2">
                    <div>
                      <div className="text-sm text-white">{perm.label}</div>
                      <div className="text-xs text-slate-500">{perm.route}</div>
                    </div>
                    <span className={`text-xs px-2 py-1 rounded-full font-medium ${
                      perm.allowed
                        ? 'bg-neon-green/10 text-neon-green border border-neon-green/20'
                        : 'bg-red-400/10 text-red-400 border border-red-400/20'
                    }`}>
                      {perm.allowed ? '✓ Allowed' : '✗ Denied'}
                    </span>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>
      </main>
    </div>
  )
}
