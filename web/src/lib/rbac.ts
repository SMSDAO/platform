export type Role = 'user' | 'admin' | 'developer'

export const ROLE_HIERARCHY: Record<Role, number> = {
  user: 1,
  admin: 2,
  developer: 3,
}

export const ROUTE_PERMISSIONS: Record<string, Role[]> = {
  '/dashboard': ['user', 'admin', 'developer'],
  '/dashboard/admin': ['admin', 'developer'],
  '/dashboard/dev': ['developer'],
  '/profile': ['user', 'admin', 'developer'],
}

export function hasPermission(userRole: string, requiredRoles: Role[]): boolean {
  return requiredRoles.includes(userRole as Role)
}

export function canAccessRoute(userRole: string, route: string): boolean {
  // Find the most specific (longest) matching route prefix
  const matchedRoute = Object.keys(ROUTE_PERMISSIONS)
    .filter((r) => route === r || route.startsWith(r + '/'))
    .sort((a, b) => b.length - a.length)[0]
  if (!matchedRoute) return true
  return hasPermission(userRole, ROUTE_PERMISSIONS[matchedRoute])
}
