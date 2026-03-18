import { getServerSession } from 'next-auth'
import { authOptions } from '@/lib/auth'
import { redirect } from 'next/navigation'
import Link from 'next/link'
import { Navbar } from '@/components/layout/Navbar'
import { Activity, GitBranch, CheckCircle, Clock, TrendingUp, Zap } from 'lucide-react'

const statColorClasses: Record<string, string> = {
  cyan: 'bg-neon-cyan/10 text-neon-cyan',
  purple: 'bg-neon-purple/10 text-neon-purple',
  green: 'bg-neon-green/10 text-neon-green',
}

export default async function DashboardPage() {
  const session = await getServerSession(authOptions)

  if (!session) {
    redirect('/auth/login')
  }

  const stats = [
    { label: 'Active Pipelines', value: '12', icon: <Activity className="w-5 h-5" />, color: 'cyan', change: '+3' },
    { label: 'Deployments Today', value: '47', icon: <GitBranch className="w-5 h-5" />, color: 'purple', change: '+12' },
    { label: 'Success Rate', value: '98.2%', icon: <CheckCircle className="w-5 h-5" />, color: 'green', change: '+0.4%' },
    { label: 'Avg Build Time', value: '2m 34s', icon: <Clock className="w-5 h-5" />, color: 'cyan', change: '-18s' },
  ]

  const recentActivity = [
    { name: 'main-api', branch: 'main', status: 'success', time: '2 min ago', duration: '1m 42s' },
    { name: 'frontend-app', branch: 'feat/dashboard', status: 'running', time: '5 min ago', duration: '0m 54s' },
    { name: 'worker-service', branch: 'fix/memory-leak', status: 'failed', time: '12 min ago', duration: '2m 11s' },
    { name: 'auth-service', branch: 'main', status: 'success', time: '23 min ago', duration: '1m 05s' },
    { name: 'notification-svc', branch: 'release/v2.1', status: 'success', time: '1 hr ago', duration: '3m 22s' },
  ]

  return (
    <div className="min-h-screen bg-dark-base">
      <Navbar />
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 pt-24">
        {/* Header */}
        <div className="mb-8">
          <h1 className="text-3xl font-bold text-white">
            Welcome back,{' '}
            <span className="text-glow-cyan text-neon-cyan">
              {session.user?.name || session.user?.email}
            </span>
          </h1>
          <p className="text-slate-400 mt-1">Here&apos;s what&apos;s happening with your pipelines</p>
        </div>

        {/* Stats Grid */}
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
          {stats.map((stat, i) => (
            <div key={i} className="glass rounded-2xl p-5 border border-white/5 hover:border-neon-cyan/20 transition-all">
              <div className="flex items-center justify-between mb-3">
                <div className={`w-10 h-10 rounded-xl flex items-center justify-center ${statColorClasses[stat.color]}`}>
                  {stat.icon}
                </div>
                <span className="text-xs text-neon-green font-medium">{stat.change}</span>
              </div>
              <div className="text-2xl font-bold text-white">{stat.value}</div>
              <div className="text-sm text-slate-400 mt-1">{stat.label}</div>
            </div>
          ))}
        </div>

        {/* Recent Activity */}
        <div className="glass rounded-2xl border border-white/5">
          <div className="flex items-center justify-between p-6 border-b border-white/5">
            <div className="flex items-center gap-2">
              <TrendingUp className="w-5 h-5 text-neon-cyan" />
              <h2 className="text-lg font-semibold text-white">Recent Pipeline Runs</h2>
            </div>
            <button className="text-sm text-neon-cyan hover:underline">View all</button>
          </div>

          <div className="divide-y divide-white/5">
            {recentActivity.map((item, i) => (
              <div key={i} className="flex items-center justify-between px-6 py-4 hover:bg-white/[0.02] transition-colors">
                <div className="flex items-center gap-3">
                  <div className={`w-2 h-2 rounded-full ${
                    item.status === 'success' ? 'bg-neon-green' :
                    item.status === 'running' ? 'bg-neon-cyan animate-pulse' :
                    'bg-red-400'
                  }`} />
                  <div>
                    <div className="text-sm font-medium text-white">{item.name}</div>
                    <div className="text-xs text-slate-500 flex items-center gap-1">
                      <GitBranch className="w-3 h-3" /> {item.branch}
                    </div>
                  </div>
                </div>
                <div className="flex items-center gap-6 text-xs text-slate-500">
                  <span className="flex items-center gap-1">
                    <Clock className="w-3 h-3" /> {item.duration}
                  </span>
                  <span>{item.time}</span>
                  <span className={`px-2 py-0.5 rounded-full text-xs font-medium ${
                    item.status === 'success' ? 'bg-neon-green/10 text-neon-green' :
                    item.status === 'running' ? 'bg-neon-cyan/10 text-neon-cyan' :
                    'bg-red-400/10 text-red-400'
                  }`}>
                    {item.status}
                  </span>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Role-based Quick Links */}
        {(session.user?.role === 'admin' || session.user?.role === 'developer') && (
          <div className="mt-6 grid grid-cols-1 sm:grid-cols-2 gap-4">
            {session.user?.role === 'admin' && (
              <Link href="/dashboard/admin" className="glass rounded-2xl p-5 border border-neon-purple/20 hover:border-neon-purple/40 hover:glow-purple transition-all">
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 rounded-xl bg-neon-purple/10 flex items-center justify-center">
                    <Zap className="w-5 h-5 text-neon-purple" />
                  </div>
                  <div>
                    <div className="font-semibold text-white">Admin Panel</div>
                    <div className="text-xs text-slate-400">Manage users &amp; settings</div>
                  </div>
                </div>
              </Link>
            )}
            {session.user?.role === 'developer' && (
              <Link href="/dashboard/dev" className="glass rounded-2xl p-5 border border-neon-green/20 hover:border-neon-green/40 hover:glow-green transition-all">
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 rounded-xl bg-neon-green/10 flex items-center justify-center">
                    <Activity className="w-5 h-5 text-neon-green" />
                  </div>
                  <div>
                    <div className="font-semibold text-white">Dev Panel</div>
                    <div className="text-xs text-slate-400">Advanced developer tools</div>
                  </div>
                </div>
              </Link>
            )}
          </div>
        )}
      </main>
    </div>
  )
}
