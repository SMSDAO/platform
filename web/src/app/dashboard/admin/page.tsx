import { getServerSession } from 'next-auth'
import { authOptions } from '@/lib/auth'
import { redirect } from 'next/navigation'
import { Navbar } from '@/components/layout/Navbar'
import { prisma } from '@/lib/prisma'
import { Users, Shield, Settings, Activity, UserCheck } from 'lucide-react'

const roleColors: Record<string, string> = {
  admin: 'text-neon-purple bg-neon-purple/10 border-neon-purple/20',
  developer: 'text-neon-green bg-neon-green/10 border-neon-green/20',
  user: 'text-neon-cyan bg-neon-cyan/10 border-neon-cyan/20',
}

const statColorClasses: Record<string, string> = {
  cyan: 'bg-neon-cyan/10 text-neon-cyan',
  purple: 'bg-neon-purple/10 text-neon-purple',
  green: 'bg-neon-green/10 text-neon-green',
}

export default async function AdminPage() {
  const session = await getServerSession(authOptions)

  if (!session) redirect('/auth/login')
  if (!['admin', 'developer'].includes(session.user?.role)) redirect('/dashboard')

  const users = await prisma.user.findMany({
    select: { id: true, email: true, name: true, role: true, createdAt: true },
    orderBy: { createdAt: 'desc' },
  })

  const stats = [
    { label: 'Total Users', value: users.length, icon: <Users className="w-5 h-5" />, color: 'cyan' },
    { label: 'Admins', value: users.filter(u => u.role === 'admin').length, icon: <Shield className="w-5 h-5" />, color: 'purple' },
    { label: 'Active Today', value: users.length, icon: <Activity className="w-5 h-5" />, color: 'green' },
  ]

  return (
    <div className="min-h-screen bg-dark-base">
      <Navbar />
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 pt-24">
        <div className="mb-8">
          <div className="flex items-center gap-3 mb-2">
            <div className="w-10 h-10 rounded-xl bg-neon-purple/10 flex items-center justify-center glow-purple">
              <Shield className="w-5 h-5 text-neon-purple" />
            </div>
            <h1 className="text-3xl font-bold text-white">Admin Panel</h1>
          </div>
          <p className="text-slate-400">Manage users, roles, and system settings</p>
        </div>

        {/* Stats */}
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 mb-8">
          {stats.map((s, i) => (
            <div key={i} className="glass rounded-2xl p-5 border border-white/5">
              <div className={`w-10 h-10 rounded-xl flex items-center justify-center mb-3 ${statColorClasses[s.color]}`}>
                {s.icon}
              </div>
              <div className="text-2xl font-bold text-white">{s.value}</div>
              <div className="text-sm text-slate-400">{s.label}</div>
            </div>
          ))}
        </div>

        {/* User Table */}
        <div className="glass rounded-2xl border border-white/5">
          <div className="flex items-center justify-between p-6 border-b border-white/5">
            <div className="flex items-center gap-2">
              <UserCheck className="w-5 h-5 text-neon-purple" />
              <h2 className="text-lg font-semibold text-white">User Management</h2>
            </div>
          </div>

          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="border-b border-white/5">
                  <th className="text-left px-6 py-3 text-xs font-medium text-slate-500 uppercase tracking-wider">User</th>
                  <th className="text-left px-6 py-3 text-xs font-medium text-slate-500 uppercase tracking-wider">Email</th>
                  <th className="text-left px-6 py-3 text-xs font-medium text-slate-500 uppercase tracking-wider">Role</th>
                  <th className="text-left px-6 py-3 text-xs font-medium text-slate-500 uppercase tracking-wider">Joined</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-white/5">
                {users.map((user) => (
                  <tr key={user.id} className="hover:bg-white/[0.02] transition-colors">
                    <td className="px-6 py-4">
                      <div className="flex items-center gap-3">
                        <div className="w-8 h-8 rounded-full bg-gradient-to-br from-neon-cyan to-neon-purple flex items-center justify-center text-xs font-bold text-dark-base">
                          {(user.name || user.email)[0].toUpperCase()}
                        </div>
                        <span className="text-sm text-white">{user.name || 'Unknown'}</span>
                      </div>
                    </td>
                    <td className="px-6 py-4 text-sm text-slate-400">{user.email}</td>
                    <td className="px-6 py-4">
                      <span className={`px-2 py-1 rounded-md text-xs font-medium border ${roleColors[user.role] || roleColors.user}`}>
                        {user.role}
                      </span>
                    </td>
                    <td className="px-6 py-4 text-sm text-slate-400">
                      {new Date(user.createdAt).toLocaleDateString()}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      </main>
    </div>
  )
}
