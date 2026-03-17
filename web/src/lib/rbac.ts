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
  const permissions = ROUTE_PERMISSIONS[route]
  if (!permissions) return true
  return hasPermission(userRole, permissions)
}
