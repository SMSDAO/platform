import type { Metadata } from 'next'
import './globals.css'
import { Providers } from './providers'

export const metadata: Metadata = {
  title: 'Platform | Flash Glow Neo',
  description: 'CI/CD Platform with Flash Glow Neo design',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en" className="dark">
      <body className="bg-dark-base text-slate-200 min-h-screen">
        <Providers>{children}</Providers>
      </body>
    </html>
  )
}
