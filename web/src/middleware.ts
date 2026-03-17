import { withAuth } from 'next-auth/middleware'
import { NextResponse } from 'next/server'
import { ROUTE_PERMISSIONS } from '@/lib/rbac'

export default withAuth(
  function middleware(req) {
    const { pathname } = req.nextUrl
    const token = req.nextauth.token
    const userRole = (token?.role as string) ?? 'user'

    // Find the most specific matching route permission entry
    const matchedRoute = Object.keys(ROUTE_PERMISSIONS)
      .filter((route) => pathname === route || pathname.startsWith(route + '/'))
      .sort((a, b) => b.length - a.length)[0]

    if (matchedRoute) {
      const allowedRoles = ROUTE_PERMISSIONS[matchedRoute]
      if (!allowedRoles.includes(userRole as 'user' | 'admin' | 'developer')) {
        // Redirect to dashboard with insufficient permissions
        const url = req.nextUrl.clone()
        url.pathname = '/dashboard'
        url.searchParams.set('error', 'insufficient_permissions')
        return NextResponse.redirect(url)
      }
    }

    return NextResponse.next()
  },
  {
    callbacks: {
      authorized: ({ token }) => !!token,
    },
  }
)

export const config = {
  matcher: ['/dashboard/:path*', '/profile'],
}
