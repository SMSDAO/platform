import { getServerSession } from 'next-auth'
import { authOptions } from '@/lib/auth'
import { redirect } from 'next/navigation'
import { Navbar } from '@/components/layout/Navbar'
import { Code2, Terminal, GitBranch, Package, Cpu, Database, HardDrive, Activity } from 'lucide-react'

const levelBadgeClasses: Record<string, string> = {
  SUCCESS: 'bg-neon-green/10 text-neon-green',
  WARN: 'bg-yellow-400/10 text-yellow-400',
  ERROR: 'bg-red-400/10 text-red-400',
  INFO: 'bg-slate-700 text-slate-400',
}

const levelTextClasses: Record<string, string> = {
  INFO: 'text-slate-400',
  SUCCESS: 'text-neon-green',
  WARN: 'text-yellow-400',
  ERROR: 'text-red-400',
}

const metricBarClasses: Record<string, string> = {
  cyan: 'bg-neon-cyan',
  purple: 'bg-neon-purple',
  green: 'bg-neon-green',
}

const metricValueClasses: Record<string, string> = {
  cyan: 'text-neon-cyan',
  purple: 'text-neon-purple',
  green: 'text-neon-green',
}

export default async function DevPage() {
  const session = await getServerSession(authOptions)

  if (!session) redirect('/auth/login')
  if (session.user?.role !== 'developer') redirect('/dashboard')

  const metrics = [
    { label: 'CPU Usage', value: '23%', max: 100, current: 23, color: 'cyan', icon: <Cpu className="w-4 h-4" /> },
    { label: 'Memory', value: '4.2 GB', max: 100, current: 52, color: 'purple', icon: <Database className="w-4 h-4" /> },
    { label: 'Storage', value: '128 GB', max: 100, current: 67, color: 'green', icon: <HardDrive className="w-4 h-4" /> },
  ]

  const logs = [
    { time: '14:32:01', level: 'INFO', message: 'Pipeline main-api#142 started' },
    { time: '14:32:05', level: 'INFO', message: 'Running unit tests...' },
    { time: '14:32:18', level: 'SUCCESS', message: 'All 247 tests passed' },
    { time: '14:32:19', level: 'INFO', message: 'Building Docker image...' },
    { time: '14:33:02', level: 'SUCCESS', message: 'Image built: main-api:sha-a1b2c3d' },
    { time: '14:33:05', level: 'INFO', message: 'Pushing to registry...' },
    { time: '14:33:12', level: 'WARN', message: 'Registry rate limit approaching (80%)' },
    { time: '14:33:14', level: 'SUCCESS', message: 'Deploy to staging complete' },
    { time: '14:33:15', level: 'INFO', message: 'Running smoke tests...' },
    { time: '14:33:45', level: 'SUCCESS', message: 'Pipeline completed in 1m 44s' },
  ]

  return (
    <div className="min-h-screen bg-dark-base">
      <Navbar />
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 pt-24">
        <div className="mb-8">
          <div className="flex items-center gap-3 mb-2">
            <div className="w-10 h-10 rounded-xl bg-neon-green/10 flex items-center justify-center glow-green">
              <Code2 className="w-5 h-5 text-neon-green" />
            </div>
            <h1 className="text-3xl font-bold text-white">Developer Panel</h1>
          </div>
          <p className="text-slate-400">Advanced tools and metrics for developers</p>
        </div>

        {/* System Metrics */}
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 mb-6">
          {metrics.map((m, i) => (
            <div key={i} className="glass rounded-2xl p-5 border border-white/5">
              <div className="flex items-center justify-between mb-3">
                <div className="flex items-center gap-2 text-slate-400">
                  {m.icon}
                  <span className="text-sm">{m.label}</span>
                </div>
                <span className={`text-sm font-semibold ${metricValueClasses[m.color]}`}>{m.value}</span>
              </div>
              <div className="h-1.5 bg-white/5 rounded-full overflow-hidden">
                <div
                  className={`h-full rounded-full transition-all ${metricBarClasses[m.color]}`}
                  style={{ width: `${m.current}%` }}
                />
              </div>
              <div className="text-xs text-slate-500 mt-1">{m.current}% used</div>
            </div>
          ))}
        </div>

        {/* Logs Terminal */}
        <div className="glass rounded-2xl border border-white/5 mb-6">
          <div className="flex items-center justify-between p-4 border-b border-white/5">
            <div className="flex items-center gap-2">
              <Terminal className="w-5 h-5 text-neon-green" />
              <span className="text-sm font-semibold text-white">Live Pipeline Logs</span>
            </div>
            <div className="flex items-center gap-1.5">
              <div className="w-3 h-3 rounded-full bg-red-500" />
              <div className="w-3 h-3 rounded-full bg-yellow-500" />
              <div className="w-3 h-3 rounded-full bg-green-500" />
            </div>
          </div>
          <div className="p-4 font-mono text-sm space-y-1.5 max-h-80 overflow-y-auto">
            {logs.map((log, i) => (
              <div key={i} className="flex items-start gap-3">
                <span className="text-slate-600 text-xs mt-0.5 flex-shrink-0">{log.time}</span>
                <span className={`text-xs px-1.5 py-0.5 rounded font-bold flex-shrink-0 ${levelBadgeClasses[log.level] || levelBadgeClasses.INFO}`}>
                  {log.level}
                </span>
                <span className={levelTextClasses[log.level] || levelTextClasses.INFO}>{log.message}</span>
              </div>
            ))}
          </div>
        </div>

        {/* Package Stats */}
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div className="glass rounded-2xl p-5 border border-white/5">
            <div className="flex items-center gap-2 mb-4">
              <Package className="w-5 h-5 text-neon-cyan" />
              <h3 className="font-semibold text-white">Dependencies</h3>
            </div>
            <div className="space-y-2">
              {[
                { name: 'next', version: '15.2.9', status: 'up-to-date' },
                { name: 'react', version: '18.3.0', status: 'up-to-date' },
                { name: 'prisma', version: '5.14.0', status: 'up-to-date' },
                { name: 'next-auth', version: '4.24.0', status: 'up-to-date' },
              ].map((dep, i) => (
                <div key={i} className="flex items-center justify-between py-2 border-b border-white/5 last:border-0">
                  <span className="text-sm text-slate-300">{dep.name}</span>
                  <div className="flex items-center gap-2">
                    <span className="text-xs text-slate-500">v{dep.version}</span>
                    <span className="text-xs text-neon-green bg-neon-green/10 px-2 py-0.5 rounded-full">✓</span>
                  </div>
                </div>
              ))}
            </div>
          </div>

          <div className="glass rounded-2xl p-5 border border-white/5">
            <div className="flex items-center gap-2 mb-4">
              <GitBranch className="w-5 h-5 text-neon-purple" />
              <h3 className="font-semibold text-white">Repository Stats</h3>
            </div>
            <div className="space-y-3">
              {[
                { label: 'Total Commits', value: '1,247' },
                { label: 'Open PRs', value: '8' },
                { label: 'Active Branches', value: '23' },
                { label: 'Code Coverage', value: '87.3%' },
              ].map((stat, i) => (
                <div key={i} className="flex items-center justify-between">
                  <span className="text-sm text-slate-400">{stat.label}</span>
                  <span className="text-sm font-semibold text-white">{stat.value}</span>
                </div>
              ))}
            </div>
          </div>
        </div>
      </main>
    </div>
  )
}
