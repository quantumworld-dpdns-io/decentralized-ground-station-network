import { create } from 'zustand';
import { persist } from 'zustand/middleware';

export type Theme = 'dark' | 'light';
export type SidebarState = 'expanded' | 'collapsed';

interface AuthState {
  user: {
    id: string;
    name: string;
    email: string;
    role: 'admin' | 'operator' | 'viewer';
  } | null;
  isAuthenticated: boolean;
  setUser: (user: AuthState['user']) => void;
  clearUser: () => void;
}

interface ThemeState {
  theme: Theme;
  setTheme: (theme: Theme) => void;
  toggleTheme: () => void;
}

interface DashboardState {
  sidebar: SidebarState;
  setSidebar: (state: SidebarState) => void;
  toggleSidebar: () => void;
  selectedStationId: string | null;
  setSelectedStation: (id: string | null) => void;
  timeRange: string;
  setTimeRange: (range: string) => void;
}

interface Notification {
  id: string;
  title: string;
  message: string;
  type: 'info' | 'success' | 'warning' | 'error';
  read: boolean;
  timestamp: Date;
}

interface NotificationState {
  notifications: Notification[];
  unreadCount: number;
  addNotification: (notification: Omit<Notification, 'id' | 'timestamp' | 'read'>) => void;
  markAsRead: (id: string) => void;
  markAllAsRead: () => void;
  clearNotifications: () => void;
}

export const useAuthStore = create<AuthState>((set) => ({
  user: null,
  isAuthenticated: false,
  setUser: (user) => set({ user, isAuthenticated: true }),
  clearUser: () => set({ user: null, isAuthenticated: false }),
}));

export const useThemeStore = create<ThemeState>()(
  persist(
    (set) => ({
      theme: 'dark',
      setTheme: (theme) => set({ theme }),
      toggleTheme: () =>
        set((state) => ({ theme: state.theme === 'dark' ? 'light' : 'dark' })),
    }),
    { name: 'dgsn-theme' },
  ),
);

export const useDashboardStore = create<DashboardState>((set) => ({
  sidebar: 'expanded',
  setSidebar: (sidebar) => set({ sidebar }),
  toggleSidebar: () =>
    set((state) => ({
      sidebar: state.sidebar === 'expanded' ? 'collapsed' : 'expanded',
    })),
  selectedStationId: null,
  setSelectedStation: (id) => set({ selectedStationId: id }),
  timeRange: '24h',
  setTimeRange: (range) => set({ timeRange: range }),
}));

export const useNotificationStore = create<NotificationState>((set) => ({
  notifications: [],
  unreadCount: 0,
  addNotification: (notification) =>
    set((state) => ({
      notifications: [
        {
          ...notification,
          id: `notif-${Date.now()}`,
          timestamp: new Date(),
          read: false,
        },
        ...state.notifications,
      ],
      unreadCount: state.unreadCount + 1,
    })),
  markAsRead: (id) =>
    set((state) => ({
      notifications: state.notifications.map((n) =>
        n.id === id ? { ...n, read: true } : n,
      ),
      unreadCount: Math.max(0, state.unreadCount - 1),
    })),
  markAllAsRead: () =>
    set((state) => ({
      notifications: state.notifications.map((n) => ({ ...n, read: true })),
      unreadCount: 0,
    })),
  clearNotifications: () => set({ notifications: [], unreadCount: 0 }),
}));
