import Link from 'next/link'
import { ArrowRight, Zap, Shield, Code2, Terminal } from 'lucide-react'

export default function LandingPage() {
  return (
    <div className="min-h-screen bg-dark-base neon-grid overflow-hidden">
      {/* Navbar */}
      <nav className="fixed top-0 w-full z-50 glass border-b border-white/5">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between h-16">
            <div className="flex items-center gap-2">
              <Zap className="w-6 h-6 text-neon-cyan" />
              <span className="text-xl font-bold text-glow-cyan text-neon-cyan">Platform</span>
            </div>
            <div className="flex items-center gap-4">
              <Link
                href="/auth/login"
                className="px-4 py-2 text-slate-300 hover:text-neon-cyan transition-colors"
              >
                Sign In
              </Link>
              <Link
                href="/auth/register"
                className="px-4 py-2 rounded-lg bg-neon-cyan/10 border border-neon-cyan/30 text-neon-cyan hover:bg-neon-cyan/20 transition-all"
              >
                Get Started
              </Link>
            </div>
          </div>
        </div>
      </nav>

      {/* Hero */}
      <section className="relative min-h-screen flex items-center justify-center pt-16">
        <div className="absolute top-1/4 left-1/4 w-96 h-96 rounded-full bg-neon-cyan/5 blur-3xl pointer-events-none" />
        <div className="absolute bottom-1/4 right-1/4 w-96 h-96 rounded-full bg-neon-purple/5 blur-3xl pointer-events-none" />

        <div className="relative z-10 max-w-5xl mx-auto px-4 text-center">
          <div className="inline-flex items-center gap-2 px-4 py-2 rounded-full glass border border-neon-cyan/20 text-neon-cyan text-sm mb-8">
            <Zap className="w-4 h-4" />
            <span>Flash Glow Neo CI/CD Platform</span>
          </div>

          <h1 className="text-5xl sm:text-7xl font-bold mb-6 leading-tight">
            <span className="text-white">Deploy with </span>
            <span className="text-glow-cyan text-neon-cyan">Neon</span>
            <span className="text-white"> Speed</span>
          </h1>

          <p className="text-xl text-slate-400 max-w-2xl mx-auto mb-12">
            A powerful CI/CD platform built for modern teams. Automate your deployments,
            monitor pipelines, and ship faster with our glassmorphic dashboard.
          </p>

          <div className="flex flex-col sm:flex-row gap-4 justify-center">
            <Link
              href="/auth/register"
              className="inline-flex items-center gap-2 px-8 py-4 rounded-xl bg-neon-cyan text-dark-base font-semibold hover:bg-neon-cyan/90 glow-cyan transition-all text-lg"
            >
              Start Building <ArrowRight className="w-5 h-5" />
            </Link>
            <Link
              href="/auth/login"
              className="inline-flex items-center gap-2 px-8 py-4 rounded-xl glass border border-white/10 text-white hover:border-neon-cyan/30 transition-all text-lg"
            >
              Sign In
            </Link>
          </div>
        </div>
      </section>

      {/* Features */}
      <section className="py-24 px-4">
        <div className="max-w-6xl mx-auto">
          <h2 className="text-3xl font-bold text-center mb-4 text-white">
            Built for <span className="text-glow-purple text-neon-purple">Developers</span>
          </h2>
          <p className="text-slate-400 text-center mb-16 max-w-xl mx-auto">
            Everything you need to build, test, and deploy your applications at scale.
          </p>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            <div className="glass rounded-2xl p-6 hover:border-neon-cyan/30 transition-all group">
              <div className="w-14 h-14 rounded-xl bg-neon-cyan/10 flex items-center justify-center mb-4 transition-all">
                <Terminal className="w-8 h-8 text-neon-cyan" />
              </div>
              <h3 className="text-lg font-semibold text-white mb-2">Pipeline Automation</h3>
              <p className="text-slate-400 text-sm leading-relaxed">
                Define complex CI/CD pipelines with a simple YAML config. Run tests, builds, and deployments automatically.
              </p>
            </div>

            <div className="glass rounded-2xl p-6 hover:border-neon-purple/30 transition-all group">
              <div className="w-14 h-14 rounded-xl bg-neon-purple/10 flex items-center justify-center mb-4 transition-all">
                <Shield className="w-8 h-8 text-neon-purple" />
              </div>
              <h3 className="text-lg font-semibold text-white mb-2">Role-Based Access</h3>
              <p className="text-slate-400 text-sm leading-relaxed">
                Granular RBAC controls ensure the right people have access to the right resources.
              </p>
            </div>

            <div className="glass rounded-2xl p-6 hover:border-neon-green/30 transition-all group">
              <div className="w-14 h-14 rounded-xl bg-neon-green/10 flex items-center justify-center mb-4 transition-all">
                <Code2 className="w-8 h-8 text-neon-green" />
              </div>
              <h3 className="text-lg font-semibold text-white mb-2">Developer Tools</h3>
              <p className="text-slate-400 text-sm leading-relaxed">
                Rich developer panel with logs, metrics, and debugging tools to accelerate your workflow.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* CTA */}
      <section className="py-24 px-4">
        <div className="max-w-3xl mx-auto text-center">
          <div className="gradient-border inline-block w-full">
            <div className="bg-dark-card rounded-xl p-12">
              <h2 className="text-3xl font-bold text-white mb-4">
                Ready to <span className="text-glow-green text-neon-green">Launch?</span>
              </h2>
              <p className="text-slate-400 mb-8">
                Join thousands of developers shipping faster with our platform.
              </p>
              <Link
                href="/auth/register"
                className="inline-flex items-center gap-2 px-8 py-4 rounded-xl bg-neon-green text-dark-base font-semibold hover:bg-neon-green/90 glow-green transition-all"
              >
                Create Free Account <ArrowRight className="w-5 h-5" />
              </Link>
            </div>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="border-t border-white/5 py-8 px-4">
        <div className="max-w-7xl mx-auto flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Zap className="w-5 h-5 text-neon-cyan" />
            <span className="text-neon-cyan font-semibold">Platform</span>
          </div>
          <p className="text-slate-500 text-sm">© 2024 Platform. Flash Glow Neo Design.</p>
        </div>
      </footer>
    </div>
  )
}
