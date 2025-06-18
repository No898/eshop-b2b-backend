# 🔐 Authentication Components

Kompletní průvodce implementací autentizace pro frontend aplikace s JWT tokeny a GraphQL.

## 📋 Obsah
- [🚀 Quick Start](#-quick-start)
- [🔧 Setup](#-setup)
- [🎯 Components](#-components)
- [🔄 Hooks](#-hooks)
- [🛡️ Route Protection](#-route-protection)
- [🧪 Testing](#-testing)

---

## 🚀 Quick Start

### Základní JWT Flow
1. **Login** → získej JWT token
2. **Store token** → localStorage/sessionStorage
3. **Attach to requests** → Authorization header
4. **Auto refresh** → před expirací
5. **Logout** → vymaž token

---

## 🔧 Setup

### Apollo Client s Auth
```tsx
// lib/apollo-client.ts
import { ApolloClient, InMemoryCache, createHttpLink } from '@apollo/client';
import { setContext } from '@apollo/client/link/context';

const httpLink = createHttpLink({
  uri: process.env.NEXT_PUBLIC_GRAPHQL_URL || 'http://localhost:3000/graphql',
});

const authLink = setContext((_, { headers }) => {
  const token = typeof window !== 'undefined' ? localStorage.getItem('auth_token') : null;

  return {
    headers: {
      ...headers,
      authorization: token ? `Bearer ${token}` : "",
    }
  }
});

export const apolloClient = new ApolloClient({
  link: authLink.concat(httpLink),
  cache: new InMemoryCache()
});
```

### Auth Context
```tsx
// contexts/AuthContext.tsx
interface AuthContextType {
  user: User | null;
  token: string | null;
  login: (email: string, password: string) => Promise<boolean>;
  logout: () => void;
  loading: boolean;
  isAuthenticated: boolean;
}

export const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [token, setToken] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  const [loginMutation] = useMutation(LOGIN_USER);

  const login = async (email: string, password: string): Promise<boolean> => {
    try {
      const result = await loginMutation({
        variables: { email, password }
      });

      const { user: loggedUser, token: authToken, errors } = result.data.loginUser;

      if (errors?.length > 0) {
        throw new Error(errors[0]);
      }

      setUser(loggedUser);
      setToken(authToken);
      localStorage.setItem('auth_token', authToken);

      return true;
    } catch (error) {
      console.error('Login error:', error);
      return false;
    }
  };

  const logout = () => {
    setUser(null);
    setToken(null);
    localStorage.removeItem('auth_token');
  };

  return (
    <AuthContext.Provider value={{
      user,
      token,
      login,
      logout,
      loading,
      isAuthenticated: !!user
    }}>
      {children}
    </AuthContext.Provider>
  );
}

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within AuthProvider');
  }
  return context;
};
```

---

## 🎯 Components

### LoginForm
```tsx
// components/auth/LoginForm.tsx
export default function LoginForm({ onSuccess, redirectTo = '/dashboard' }) {
  const [formData, setFormData] = useState({
    email: '',
    password: ''
  });
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const { login } = useAuth();
  const router = useRouter();

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError('');

    const success = await login(formData.email, formData.password);

    if (success) {
      onSuccess?.();
      router.push(redirectTo);
    } else {
      setError('Neplatné přihlašovací údaje');
    }

    setLoading(false);
  };

  return (
    <div className="max-w-md mx-auto bg-white p-8 rounded-lg shadow-lg">
      <h2 className="text-2xl font-bold text-center mb-6">Přihlášení</h2>

      {error && (
        <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded mb-4">
          {error}
        </div>
      )}

      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">
            Email
          </label>
          <input
            type="email"
            value={formData.email}
            onChange={(e) => setFormData(prev => ({ ...prev, email: e.target.value }))}
            className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
            required
            disabled={loading}
          />
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">
            Heslo
          </label>
          <input
            type="password"
            value={formData.password}
            onChange={(e) => setFormData(prev => ({ ...prev, password: e.target.value }))}
            className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
            required
            disabled={loading}
          />
        </div>

        <button
          type="submit"
          disabled={loading}
          className="w-full bg-blue-600 text-white py-2 px-4 rounded-lg hover:bg-blue-700 disabled:opacity-50"
        >
          {loading ? 'Přihlašuji...' : 'Přihlásit se'}
        </button>
      </form>
    </div>
  );
}
```

### UserProfile
```tsx
// components/auth/UserProfile.tsx
export default function UserProfile() {
  const { user, logout } = useAuth();

  if (!user) return null;

  return (
    <div className="relative">
      <button className="flex items-center space-x-2 text-gray-700 hover:text-gray-900">
        {user.avatarUrl ? (
          <img
            src={user.avatarUrl}
            alt={user.email}
            className="w-8 h-8 rounded-full"
          />
        ) : (
          <div className="w-8 h-8 bg-gray-300 rounded-full flex items-center justify-center">
            <span className="text-sm font-medium">
              {user.email.charAt(0).toUpperCase()}
            </span>
          </div>
        )}
        <span className="text-sm font-medium">{user.companyName || user.email}</span>
      </button>

      <div className="absolute right-0 mt-2 w-48 bg-white rounded-md shadow-lg py-1 z-50">
        <div className="px-4 py-2 text-sm text-gray-700 border-b">
          <div className="font-medium">{user.companyName}</div>
          <div className="text-gray-500">{user.email}</div>
          {user.role === 'admin' && (
            <div className="text-xs bg-red-100 text-red-700 px-2 py-1 rounded mt-1 inline-block">
              Admin
            </div>
          )}
        </div>

        <button
          onClick={logout}
          className="block w-full text-left px-4 py-2 text-sm text-gray-700 hover:bg-gray-100"
        >
          Odhlásit se
        </button>
      </div>
    </div>
  );
}
```

---

## 🛡️ Route Protection

### ProtectedRoute Component
```tsx
// components/auth/ProtectedRoute.tsx
export default function ProtectedRoute({
  children,
  requireAdmin = false,
  fallback
}) {
  const { isAuthenticated, loading, user } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (!loading) {
      if (!isAuthenticated) {
        router.push('/login');
        return;
      }

      if (requireAdmin && user?.role !== 'admin') {
        router.push('/unauthorized');
        return;
      }
    }
  }, [isAuthenticated, loading, user, requireAdmin, router]);

  if (loading) {
    return fallback || <div>Loading...</div>;
  }

  if (!isAuthenticated || (requireAdmin && user?.role !== 'admin')) {
    return null;
  }

  return <>{children}</>;
}
```

---

## 🧪 Testing

### GraphQL Queries
```graphql
# Test login
mutation TestLogin {
  loginUser(
    email: "admin@example.com"
    password: "password123"
  ) {
    user {
      id
      email
      role
      companyName
    }
    token
    errors
  }
}

# Test current user
query TestCurrentUser {
  currentUser {
    id
    email
    role
    companyName
  }
}
```

---

## 🔗 Related Documentation
- **[GraphQL API](../api/graphql.md)** - Authentication mutations
- **[Security Guide](../api/security.md)** - JWT security best practices

---

*Dokumentace aktualizována: 2025-01-18*