'use client';

import { useSession } from 'next-auth/react';
import { useAuthStore } from '@/lib/state/store';
import { useEffect } from 'react';

export function useAuth() {
  const { data: session, status } = useSession();
  const { user, isAuthenticated, setUser, clearUser } = useAuthStore();

  useEffect(() => {
    if (status === 'authenticated' && session?.user) {
      setUser({
        id: session.user.id || session.user.email || 'unknown',
        name: session.user.name || 'User',
        email: session.user.email || '',
        role: (session.user as { role?: 'admin' | 'operator' | 'viewer' }).role || 'operator',
      });
    } else if (status === 'unauthenticated') {
      clearUser();
    }
  }, [status, session, setUser, clearUser]);

  return {
    user,
    isAuthenticated,
    isLoading: status === 'loading',
    session,
  };
}
