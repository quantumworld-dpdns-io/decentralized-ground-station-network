import { useAuthStore } from '@/lib/state/store';

const API_BASE = '/api/v1';

interface ApiError {
  status: number;
  message: string;
  code?: string;
}

class ApiClientError extends Error {
  status: number;
  code?: string;

  constructor(error: ApiError) {
    super(error.message);
    this.name = 'ApiClientError';
    this.status = error.status;
    this.code = error.code;
  }
}

async function getAuthHeaders(): Promise<HeadersInit> {
  const headers: HeadersInit = {
    'Content-Type': 'application/json',
  };

  try {
    const { data: session } = await import('next-auth/react').then((m) =>
      m.getSession(),
    );
    if (session?.accessToken) {
      headers['Authorization'] = `Bearer ${session.accessToken}`;
    }
  } catch {
    // Not in a browser environment or not authenticated
  }

  return headers;
}

async function request<T>(
  endpoint: string,
  options: RequestInit = {},
): Promise<T> {
  const headers = await getAuthHeaders();
  const url = `${API_BASE}${endpoint}`;

  const response = await fetch(url, {
    ...options,
    headers: {
      ...headers,
      ...options.headers,
    },
  });

  if (!response.ok) {
    let error: ApiError;
    try {
      const body = await response.json();
      error = {
        status: response.status,
        message: body.message || body.error || 'Request failed',
        code: body.code,
      };
    } catch {
      error = {
        status: response.status,
        message: `HTTP ${response.status}: ${response.statusText}`,
      };
    }

    if (response.status === 401) {
      useAuthStore.getState().clearUser();
    }

    throw new ApiClientError(error);
  }

  if (response.status === 204) {
    return undefined as T;
  }

  return response.json();
}

export const api = {
  get: <T>(endpoint: string, params?: Record<string, string>) => {
    const query = params
      ? '?' + new URLSearchParams(params).toString()
      : '';
    return request<T>(`${endpoint}${query}`);
  },

  post: <T>(endpoint: string, data?: unknown) =>
    request<T>(endpoint, {
      method: 'POST',
      body: data ? JSON.stringify(data) : undefined,
    }),

  put: <T>(endpoint: string, data?: unknown) =>
    request<T>(endpoint, {
      method: 'PUT',
      body: data ? JSON.stringify(data) : undefined,
    }),

  patch: <T>(endpoint: string, data?: unknown) =>
    request<T>(endpoint, {
      method: 'PATCH',
      body: data ? JSON.stringify(data) : undefined,
    }),

  delete: <T>(endpoint: string) =>
    request<T>(endpoint, { method: 'DELETE' }),
};

export { ApiClientError };
export type { ApiError };
