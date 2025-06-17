# 🎯 Frontend Průvodce - Jednoduchý návod pro začátečníky

Kompletní návod jak používat naše GraphQL API ve frontend aplikaci + UI tipy pro B2B eshop. Každý příklad je ready-to-use!

---

## 📋 Obsah
- [🚀 Quick Start](#-quick-start)
- [🔐 Autentizace](#-autentizace)
- [📊 Získávání dat (Queries)](#-získávání-dat-queries)
- [✏️ Změny dat (Mutations)](#️-změny-dat-mutations)
- [📍 Address Management](#-address-management)
- [🏷️ Bulk Pricing System](#️-bulk-pricing-system)
- [🎨 Product Variants System](#-product-variants-system)
- [📚 Docusaurus Documentation](#-docusaurus-documentation)
- [❌ Error Handling](#-error-handling)
- [💳 Payment Errors](#-payment-errors)
- [🔧 TypeScript Setup](#-typescript-setup)
- [🎨 UI Tips](#-ui-tips)
- [🐛 Troubleshooting](#-troubleshooting)

---

## 🚀 Quick Start

### ⚠️ Důležité - URL konfigurace
**Localhost nebude fungovat!** Pokud:
- Frontend běží na jiné adrese než backend
- Backend je nasazený na Railway
- Frontend je nasazený na Vercel

Musíš použít **veřejnou URL** backendu!

### 1. Instalace GraphQL klienta
```bash
npm install @apollo/client graphql
# nebo
yarn add @apollo/client graphql
```

### 2. Základní setup (Next.js/React)
```typescript
// lib/apollo-client.ts
import { ApolloClient, InMemoryCache, createHttpLink } from '@apollo/client';
import { setContext } from '@apollo/client/link/context';

// Automatická detekce prostředí
const getGraphQLUrl = () => {
  // Pokud máš backend na Railway
  if (process.env.NODE_ENV === 'production') {
    return 'https://your-app-name.railway.app/graphql'; // Změň na svoji Railway URL
  }

  // Pro development (pokud backend běží lokálně)
  return 'http://localhost:3000/graphql';
};

const httpLink = createHttpLink({
  uri: getGraphQLUrl(),
});

const authLink = setContext((_, { headers }) => {
  // Získáme token z localStorage
  const token = localStorage.getItem('authToken');

  return {
    headers: {
      ...headers,
      authorization: token ? `Bearer ${token}` : "",
    }
  }
});

const client = new ApolloClient({
  link: authLink.concat(httpLink),
  cache: new InMemoryCache(),
});

export default client;
```

### 3. Environment variables (.env.local)
```bash
# .env.local soubor v root složce frontend projektu

# Development (pokud backend běží lokálně)
NEXT_PUBLIC_GRAPHQL_URL=http://localhost:3000/graphql

# Production (Railway URL)
NEXT_PUBLIC_GRAPHQL_URL=https://your-app-name.railway.app/graphql
```

### 4. Lepší konfigurace s env proměnnými
```typescript
// lib/apollo-client.ts - vylepšená verze
import { ApolloClient, InMemoryCache, createHttpLink } from '@apollo/client';
import { setContext } from '@apollo/client/link/context';

const httpLink = createHttpLink({
  uri: process.env.NEXT_PUBLIC_GRAPHQL_URL || 'http://localhost:3000/graphql',
});

const authLink = setContext((_, { headers }) => {
  const token = localStorage.getItem('authToken');

  return {
    headers: {
      ...headers,
      authorization: token ? `Bearer ${token}` : "",
    }
  }
});

const client = new ApolloClient({
  link: authLink.concat(httpLink),
  cache: new InMemoryCache(),
});

export default client;
```

### 5. Provider setup
```typescript
// pages/_app.tsx (Next.js) nebo App.tsx (React)
import { ApolloProvider } from '@apollo/client';
import client from '../lib/apollo-client';

function MyApp({ Component, pageProps }) {
  return (
    <ApolloProvider client={client}>
      <Component {...pageProps} />
    </ApolloProvider>
  );
}
```

---

## 🔐 Autentizace

### ⚠️ **DŮLEŽITÉ - Nepoužívejte next-auth!**

**Pokud máte v package.json `next-auth`, odstraňte ho:**
```bash
npm uninstall next-auth
```

**Proč next-auth nepoužíváme:**
- ❌ **Duplikace** - backend už má Devise + JWT autentizaci
- ❌ **Komplikace** - next-auth vytváří vlastní user tabulky
- ❌ **B2B specifika** - náš backend má company_name, vat_id, role
- ❌ **GraphQL nekompatibilita** - next-auth je primárně pro REST API
- ❌ **Zbytečná složitost** - máme funkční JWT systém

**Místo toho používáme:**
- ✅ **Apollo Client** s JWT tokeny (authLink)
- ✅ **Zustand store** pro user state management
- ✅ **Naše GraphQL mutations** (`loginUser`, `registerUser`)
- ✅ **localStorage** pro persistenci tokenů

### 🔧 **Kompletní autentizační setup**

#### 1. Apollo Client s JWT autentizací
```typescript
// lib/apollo-client.ts
import { ApolloClient, InMemoryCache, createHttpLink } from '@apollo/client';
import { setContext } from '@apollo/client/link/context';

const httpLink = createHttpLink({
  uri: process.env.NEXT_PUBLIC_GRAPHQL_URL || 'http://localhost:3000/graphql',
});

// AuthLink automaticky přidá JWT token do všech requests
const authLink = setContext((_, { headers }) => {
  // Získáme token z localStorage (nebo ze Zustand store)
  const token = localStorage.getItem('authToken');

  return {
    headers: {
      ...headers,
      authorization: token ? `Bearer ${token}` : "",
    }
  }
});

const client = new ApolloClient({
  link: authLink.concat(httpLink),
  cache: new InMemoryCache(),
  defaultOptions: {
    watchQuery: {
      errorPolicy: 'all',
    },
    query: {
      errorPolicy: 'all',
    }
  }
});

export default client;
```

#### 2. Zustand Auth Store s Apollo integrací
```typescript
// stores/auth-store.ts
import { create } from 'zustand'
import { persist } from 'zustand/middleware'
import client from '../lib/apollo-client'
import { LOGIN_USER, REGISTER_USER } from '../mutations/auth'

interface User {
  id: string
  email: string
  companyName?: string
  vatId?: string
  role: 'customer' | 'admin'
}

interface AuthStore {
  user: User | null
  token: string | null
  isAuthenticated: boolean
  isLoading: boolean
  login: (email: string, password: string) => Promise<{ success: boolean; errors: string[] }>
  register: (data: RegisterData) => Promise<{ success: boolean; errors: string[] }>
  logout: () => void
  setUser: (user: User, token: string) => void
}

export const useAuthStore = create<AuthStore>()(
  persist(
    (set, get) => ({
      user: null,
      token: null,
      isAuthenticated: false,
      isLoading: false,

      login: async (email, password) => {
        set({ isLoading: true })

        try {
          const { data } = await client.mutate({
            mutation: LOGIN_USER,
            variables: { email, password }
          })

          if (data.loginUser.errors.length === 0) {
            const { user, token } = data.loginUser

            // Uložíme do store i localStorage
            localStorage.setItem('authToken', token)
            set({
              user,
              token,
              isAuthenticated: true,
              isLoading: false
            })

            return { success: true, errors: [] }
          } else {
            set({ isLoading: false })
            return { success: false, errors: data.loginUser.errors }
          }
        } catch (error) {
          set({ isLoading: false })
          return { success: false, errors: ['Chyba při přihlašování'] }
        }
      },

      register: async (registerData) => {
        set({ isLoading: true })

        try {
          const { data } = await client.mutate({
            mutation: REGISTER_USER,
            variables: registerData
          })

          if (data.registerUser.errors.length === 0) {
            const { user, token } = data.registerUser

            localStorage.setItem('authToken', token)
            set({
              user,
              token,
              isAuthenticated: true,
              isLoading: false
            })

            return { success: true, errors: [] }
          } else {
            set({ isLoading: false })
            return { success: false, errors: data.registerUser.errors }
          }
        } catch (error) {
          set({ isLoading: false })
          return { success: false, errors: ['Chyba při registraci'] }
        }
      },

      logout: () => {
        localStorage.removeItem('authToken')
        client.clearStore() // Vyčistí Apollo cache
        set({
          user: null,
          token: null,
          isAuthenticated: false
        })
      },

      setUser: (user, token) => {
        localStorage.setItem('authToken', token)
        set({ user, token, isAuthenticated: true })
      }
    }),
    {
      name: 'auth-storage',
      // Neukládáme token do persist storage - jen do localStorage
      partialize: (state) => ({
        user: state.user,
        isAuthenticated: state.isAuthenticated
      })
    }
  )
)
```

### 📝 **GraphQL Mutations pro autentizaci**

#### Registrace nového uživatele
```typescript
// mutations/auth.ts
import { gql } from '@apollo/client';

const REGISTER_USER = gql`
  mutation RegisterUser(
    $email: String!,
    $password: String!,
    $passwordConfirmation: String!,
    $companyName: String,
    $vatId: String
  ) {
    registerUser(
      email: $email
      password: $password
      passwordConfirmation: $passwordConfirmation
      companyName: $companyName
      vatId: $vatId
    ) {
      user {
        id
        email
        role
        companyName
        vatId
      }
      token
      errors
    }
  }
`;

// Použití v komponentě
function RegisterForm() {
  const [registerUser, { loading, error }] = useMutation(REGISTER_USER);

  const handleSubmit = async (formData) => {
    try {
      const { data } = await registerUser({
        variables: {
          email: formData.email,
          password: formData.password,
          passwordConfirmation: formData.passwordConfirmation,
          companyName: formData.companyName,
          vatId: formData.vatId
        }
      });

      if (data.registerUser.errors.length === 0) {
        // Úspěch - uložíme token
        localStorage.setItem('authToken', data.registerUser.token);
        // Přesměrujeme na dashboard
        router.push('/dashboard');
      } else {
        // Zobrazíme chyby
        console.log('Chyby:', data.registerUser.errors);
      }
    } catch (err) {
      console.error('Chyba při registraci:', err);
    }
  };

  return (
    <form onSubmit={handleSubmit}>
      {/* formulář */}
      <button type="submit" disabled={loading}>
        {loading ? 'Registrujeme...' : 'Registrovat'}
      </button>
    </form>
  );
}
```

### 🎨 **Moderní komponenty s Shadcn UI**

#### Login komponenta
```typescript
// components/auth/LoginForm.tsx
import { useState } from 'react'
import { useRouter } from 'next/router'
import { useAuthStore } from '@/stores/auth-store'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { useToast } from '@/components/ui/use-toast'

export function LoginForm() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const { login, isLoading } = useAuthStore()
  const { toast } = useToast()
  const router = useRouter()

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()

    const result = await login(email, password)

    if (result.success) {
      toast({
        title: "Úspěch",
        description: "Byli jste úspěšně přihlášeni",
      })
      router.push('/dashboard')
    } else {
      toast({
        title: "Chyba",
        description: result.errors.join(', '),
        variant: "destructive",
      })
    }
  }

  return (
    <Card className="w-full max-w-md mx-auto">
      <CardHeader>
        <CardTitle>Přihlášení</CardTitle>
      </CardHeader>
      <CardContent>
        <form onSubmit={handleSubmit} className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="email">Email</Label>
            <Input
              id="email"
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="vas@email.cz"
              required
            />
          </div>
          <div className="space-y-2">
            <Label htmlFor="password">Heslo</Label>
            <Input
              id="password"
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="Vaše heslo"
              required
            />
          </div>
          <Button type="submit" className="w-full" disabled={isLoading}>
            {isLoading ? 'Přihlašujeme...' : 'Přihlásit se'}
          </Button>
        </form>
      </CardContent>
    </Card>
  )
}
```

#### Register komponenta
```typescript
// components/auth/RegisterForm.tsx
import { useState } from 'react'
import { useRouter } from 'next/router'
import { useAuthStore } from '@/stores/auth-store'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { useToast } from '@/components/ui/use-toast'

export function RegisterForm() {
  const [formData, setFormData] = useState({
    email: '',
    password: '',
    passwordConfirmation: '',
    companyName: '',
    vatId: ''
  })

  const { register, isLoading } = useAuthStore()
  const { toast } = useToast()
  const router = useRouter()

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()

    const result = await register(formData)

    if (result.success) {
      toast({
        title: "Úspěch",
        description: "Účet byl úspěšně vytvořen",
      })
      router.push('/dashboard')
    } else {
      toast({
        title: "Chyba",
        description: result.errors.join(', '),
        variant: "destructive",
      })
    }
  }

  const handleChange = (field: string) => (e: React.ChangeEvent<HTMLInputElement>) => {
    setFormData(prev => ({ ...prev, [field]: e.target.value }))
  }

  return (
    <Card className="w-full max-w-md mx-auto">
      <CardHeader>
        <CardTitle>Registrace</CardTitle>
      </CardHeader>
      <CardContent>
        <form onSubmit={handleSubmit} className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="email">Email *</Label>
            <Input
              id="email"
              type="email"
              value={formData.email}
              onChange={handleChange('email')}
              placeholder="vas@email.cz"
              required
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="password">Heslo *</Label>
            <Input
              id="password"
              type="password"
              value={formData.password}
              onChange={handleChange('password')}
              placeholder="Minimálně 6 znaků"
              required
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="passwordConfirmation">Potvrzení hesla *</Label>
            <Input
              id="passwordConfirmation"
              type="password"
              value={formData.passwordConfirmation}
              onChange={handleChange('passwordConfirmation')}
              placeholder="Zopakujte heslo"
              required
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="companyName">Název firmy</Label>
            <Input
              id="companyName"
              value={formData.companyName}
              onChange={handleChange('companyName')}
              placeholder="Vaše firma s.r.o."
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="vatId">IČO/DIČ</Label>
            <Input
              id="vatId"
              value={formData.vatId}
              onChange={handleChange('vatId')}
              placeholder="12345678"
            />
          </div>

          <Button type="submit" className="w-full" disabled={isLoading}>
            {isLoading ? 'Registrujeme...' : 'Registrovat se'}
          </Button>
        </form>
      </CardContent>
    </Card>
  )
}
```

#### Protected Route komponenta
```typescript
// components/auth/ProtectedRoute.tsx
import { useAuthStore } from '@/stores/auth-store'
import { useRouter } from 'next/router'
import { useEffect } from 'react'

interface ProtectedRouteProps {
  children: React.ReactNode
}

export function ProtectedRoute({ children }: ProtectedRouteProps) {
  const { isAuthenticated, user } = useAuthStore()
  const router = useRouter()

  useEffect(() => {
    if (!isAuthenticated) {
      router.push('/login')
    }
  }, [isAuthenticated, router])

  if (!isAuthenticated) {
    return <div>Přesměrováváme...</div>
  }

  return <>{children}</>
}
```

#### Logout tlačítko
```typescript
// components/auth/LogoutButton.tsx
import { useAuthStore } from '@/stores/auth-store'
import { Button } from '@/components/ui/button'
import { useRouter } from 'next/router'
import { LogOut } from 'lucide-react'

export function LogoutButton() {
  const { logout } = useAuthStore()
  const router = useRouter()

  const handleLogout = () => {
    logout()
    router.push('/login')
  }

  return (
    <Button variant="ghost" onClick={handleLogout}>
      <LogOut className="w-4 h-4 mr-2" />
      Odhlásit se
    </Button>
  )
}
```
```

---

## 📊 Získávání dat (Queries)

### Seznam produktů
```typescript
// queries/products.ts
const GET_PRODUCTS = gql`
  query GetProducts {
    products {
      id
      name
      description
      priceDecimal
      currency
      available
    }
  }
`;

// Použití v komponentě
function ProductList() {
  const { loading, error, data } = useQuery(GET_PRODUCTS);

  if (loading) return <div>Načítáme produkty...</div>;
  if (error) return <div>Chyba: {error.message}</div>;

  return (
    <div>
      {data.products.map(product => (
        <div key={product.id}>
          <h3>{product.name}</h3>
          <p>{product.description}</p>
          <p><strong>{product.priceDecimal} {product.currency}</strong></p>
        </div>
      ))}
    </div>
  );
}
```

### Aktuální uživatel
```typescript
const GET_CURRENT_USER = gql`
  query GetCurrentUser {
    currentUser {
      id
      email
      role
      companyName
    }
  }
`;

function UserProfile() {
  const { loading, error, data } = useQuery(GET_CURRENT_USER);

  if (loading) return <div>Načítáme profil...</div>;
  if (error) return <div>Nejste přihlášeni</div>;
  if (!data.currentUser) return <div>Uživatel nenalezen</div>;

  return (
    <div>
      <h2>Váš profil</h2>
      <p>Email: {data.currentUser.email}</p>
      <p>Role: {data.currentUser.role}</p>
      {data.currentUser.companyName && (
        <p>Firma: {data.currentUser.companyName}</p>
      )}
    </div>
  );
}
```

### Moje objednávky
```typescript
const GET_MY_ORDERS = gql`
  query GetMyOrders {
    myOrders {
      id
      totalDecimal
      status
      createdAt
      itemsCount
      orderItems {
        id
        quantity
        unitPriceDecimal
        product {
          id
          name
        }
      }
    }
  }
`;

function MyOrders() {
  const { loading, error, data } = useQuery(GET_MY_ORDERS);

  if (loading) return <div>Načítáme objednávky...</div>;
  if (error) return <div>Chyba při načítání objednávek</div>;

  return (
    <div>
      <h2>Moje objednávky</h2>
      {data.myOrders.map(order => (
        <div key={order.id} style={{ border: '1px solid #ddd', padding: '10px', margin: '10px 0' }}>
          <h3>Objednávka #{order.id}</h3>
          <p>Celkem: {order.totalDecimal} Kč</p>
          <p>Status: {order.status}</p>
          <p>Počet položek: {order.itemsCount}</p>

          <h4>Položky:</h4>
          {order.orderItems.map(item => (
            <div key={item.id}>
              {item.product.name} - {item.quantity}x {item.unitPriceDecimal} Kč
            </div>
          ))}
        </div>
      ))}
    </div>
  );
}
```

---

## ✏️ Změny dat (Mutations)

### Vytvoření objednávky
```typescript
const CREATE_ORDER = gql`
  mutation CreateOrder($items: [OrderItemInput!]!) {
    createOrder(
      items: $items
    ) {
      order {
        id
        totalDecimal
        status
        itemsCount
      }
      errors
    }
  }
`;

function CreateOrderForm() {
  const [createOrder, { loading }] = useMutation(CREATE_ORDER);
  const [cartItems, setCartItems] = useState([
    { productId: "1", quantity: 2 },
    { productId: "2", quantity: 1 }
  ]);

  const handleCreateOrder = async () => {
    try {
      const { data } = await createOrder({
        variables: {
          items: cartItems.map(item => ({
            productId: item.productId,
            quantity: item.quantity
          }))
        }
      });

      if (data.createOrder.errors.length === 0) {
        alert('Objednávka vytvořena!');
        // Přesměrujeme na objednávku
        router.push(`/orders/${data.createOrder.order.id}`);
      } else {
        alert('Chyby: ' + data.createOrder.errors.join(', '));
      }
    } catch (err) {
      alert('Chyba při vytváření objednávky');
    }
  };

  return (
    <div>
      <h2>Vytvořit objednávku</h2>
      {/* Zobrazení košíku */}
      <button onClick={handleCreateOrder} disabled={loading}>
        {loading ? 'Vytváříme...' : 'Vytvořit objednávku'}
      </button>
    </div>
  );
}
```

### Platba objednávky
```typescript
const PAY_ORDER = gql`
  mutation PayOrder($orderId: ID!) {
    payOrder(
      orderId: $orderId
    ) {
      success
      paymentUrl
      paymentId
      errorCode
      errors
    }
  }
`;

function PaymentButton({ orderId }) {
  const [payOrder, { loading }] = useMutation(PAY_ORDER);

  const handlePayment = async () => {
    try {
      const { data } = await payOrder({
        variables: { orderId }
      });

      if (data.payOrder.success) {
        // Přesměruj na platební bránu
        window.location.href = data.payOrder.paymentUrl;
      } else {
        // Zobraz chybu podle error kódu
        const errorMessage = getErrorMessage(data.payOrder.errorCode);
        alert(errorMessage);
      }
    } catch (err) {
      alert('Chyba při zpracování platby');
    }
  };

  return (
    <button onClick={handlePayment} disabled={loading}>
      {loading ? 'Připravujeme platbu...' : 'Zaplatit'}
    </button>
  );
}
```

---

## 📍 Address Management

### Adresní systém pro B2B
Náš backend podporuje pokročilý address management s českými specifiky pro B2B klienty:

#### 🏢 Typy adres
- **Billing Address (Fakturační)** - POVINNÁ pro firmy s DIČ/IČO
- **Shipping Address (Doručovací)** - Volitelná, pokud není uvedena, používá se billing

#### 🇨🇿 České B2B specifika
- **IČO** (Company Registration ID) - validace 8 číslic
- **DIČ** (VAT ID) - validace CZ + 8-10 číslic
- **PSČ** - validace 5 číslic s automatickým formátováním

### AddressType (GraphQL Schema)
```graphql
type Address {
  id: ID!
  addressType: String!         # "billing" | "shipping"
  street: String!
  city: String!
  postalCode: String!          # Automaticky formátováno "123 45"
  country: String!             # Default "CZ"
  companyName: String
  companyVatId: String         # DIČ - pouze pro billing adresy
  companyRegistrationId: String # IČO - pouze pro billing adresy
  isDefault: Boolean!          # Jedna default per type per user
  createdAt: String!
  updatedAt: String!
}
```

### 📝 Adresní formulář komponenta
```typescript
// components/AddressForm.tsx
import React, { useState } from 'react';
import { useMutation } from '@apollo/client';

interface AddressFormData {
  addressType: 'billing' | 'shipping';
  street: string;
  city: string;
  postalCode: string;
  country: string;
  companyName?: string;
  companyVatId?: string;      // DIČ
  companyRegistrationId?: string; // IČO
  isDefault: boolean;
}

const CREATE_ADDRESS = gql`
  mutation CreateAddress($input: CreateAddressInput!) {
    createAddress(input: $input) {
      address {
        id
        addressType
        street
        city
        postalCode
        companyName
        companyVatId
        companyRegistrationId
        isDefault
      }
      errors
    }
  }
`;

export default function AddressForm({
  initialType = 'billing',
  onSuccess
}: {
  initialType?: 'billing' | 'shipping';
  onSuccess?: () => void;
}) {
  const [formData, setFormData] = useState<AddressFormData>({
    addressType: initialType,
    street: '',
    city: '',
    postalCode: '',
    country: 'CZ',
    companyName: '',
    companyVatId: '',
    companyRegistrationId: '',
    isDefault: true
  });

  const [createAddress, { loading, error }] = useMutation(CREATE_ADDRESS, {
    onCompleted: (data) => {
      if (data.createAddress.address && !data.createAddress.errors?.length) {
        onSuccess?.();
      }
    }
  });

  // Automatické formátování PSČ při psaní
  const handlePostalCodeChange = (value: string) => {
    const cleaned = value.replace(/\D/g, ''); // Pouze číslice
    if (cleaned.length <= 5) {
      const formatted = cleaned.length > 3
        ? `${cleaned.slice(0, 3)} ${cleaned.slice(3)}`
        : cleaned;
      setFormData(prev => ({ ...prev, postalCode: formatted }));
    }
  };

  // Validace IČO (8 číslic)
  const validateIco = (ico: string): boolean => {
    const cleaned = ico.replace(/\D/g, '');
    return cleaned.length === 8;
  };

  // Validace DIČ (CZ + 8-10 číslic)
  const validateDic = (dic: string): boolean => {
    const dicRegex = /^CZ\d{8,10}$/;
    return dicRegex.test(dic.toUpperCase());
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    // Validace pro billing adresy
    if (formData.addressType === 'billing') {
      if (formData.companyRegistrationId && !validateIco(formData.companyRegistrationId)) {
        alert('IČO musí obsahovat přesně 8 číslic');
        return;
      }

      if (formData.companyVatId && !validateDic(formData.companyVatId)) {
        alert('DIČ musí být ve formátu CZ12345678 (CZ + 8-10 číslic)');
        return;
      }
    }

    await createAddress({
      variables: {
        input: {
          ...formData,
          // Pro shipping adresy odstraníme company údaje
          ...(formData.addressType === 'shipping' && {
            companyName: null,
            companyVatId: null,
            companyRegistrationId: null
          })
        }
      }
    });
  };

  return (
    <div className="bg-white p-6 rounded-lg shadow-md">
      <h3 className="text-lg font-semibold mb-4">
        {formData.addressType === 'billing' ? '🏢 Fakturační adresa' : '📦 Doručovací adresa'}
      </h3>

      <form onSubmit={handleSubmit} className="space-y-4">
        {/* Typ adresy */}
        <div>
          <label className="block text-sm font-medium mb-2">Typ adresy</label>
          <div className="flex gap-4">
            <label className="flex items-center">
              <input
                type="radio"
                value="billing"
                checked={formData.addressType === 'billing'}
                onChange={(e) => setFormData(prev => ({
                  ...prev,
                  addressType: e.target.value as 'billing' | 'shipping'
                }))}
                className="mr-2"
              />
              🏢 Fakturační
            </label>
            <label className="flex items-center">
              <input
                type="radio"
                value="shipping"
                checked={formData.addressType === 'shipping'}
                onChange={(e) => setFormData(prev => ({
                  ...prev,
                  addressType: e.target.value as 'billing' | 'shipping'
                }))}
                className="mr-2"
              />
              📦 Doručovací
            </label>
          </div>
        </div>

        {/* Adresní údaje */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div className="md:col-span-2">
            <label className="block text-sm font-medium mb-1">
              Ulice a číslo popisné *
            </label>
            <input
              type="text"
              required
              value={formData.street}
              onChange={(e) => setFormData(prev => ({ ...prev, street: e.target.value }))}
              placeholder="např. Václavské náměstí 123"
              className="w-full p-2 border rounded focus:ring-2 focus:ring-blue-500"
            />
          </div>

          <div>
            <label className="block text-sm font-medium mb-1">Město *</label>
            <input
              type="text"
              required
              value={formData.city}
              onChange={(e) => setFormData(prev => ({ ...prev, city: e.target.value }))}
              placeholder="Praha"
              className="w-full p-2 border rounded focus:ring-2 focus:ring-blue-500"
            />
          </div>

          <div>
            <label className="block text-sm font-medium mb-1">PSČ *</label>
            <input
              type="text"
              required
              value={formData.postalCode}
              onChange={(e) => handlePostalCodeChange(e.target.value)}
              placeholder="110 00"
              maxLength={6}
              className="w-full p-2 border rounded focus:ring-2 focus:ring-blue-500"
            />
          </div>
        </div>

        {/* Firemní údaje - pouze pro billing */}
        {formData.addressType === 'billing' && (
          <div className="bg-blue-50 p-4 rounded-lg">
            <h4 className="font-medium mb-3 text-blue-800">🏢 Firemní údaje</h4>

            <div className="space-y-3">
              <div>
                <label className="block text-sm font-medium mb-1">Název firmy</label>
                <input
                  type="text"
                  value={formData.companyName || ''}
                  onChange={(e) => setFormData(prev => ({ ...prev, companyName: e.target.value }))}
                  placeholder="Lootea s.r.o."
                  className="w-full p-2 border rounded focus:ring-2 focus:ring-blue-500"
                />
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                <div>
                  <label className="block text-sm font-medium mb-1">
                    IČO
                    <span className="text-xs text-gray-500">(8 číslic)</span>
                  </label>
                  <input
                    type="text"
                    value={formData.companyRegistrationId || ''}
                    onChange={(e) => {
                      const cleaned = e.target.value.replace(/\D/g, '');
                      if (cleaned.length <= 8) {
                        setFormData(prev => ({ ...prev, companyRegistrationId: cleaned }));
                      }
                    }}
                    placeholder="12345678"
                    maxLength={8}
                    className="w-full p-2 border rounded focus:ring-2 focus:ring-blue-500"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium mb-1">
                    DIČ
                    <span className="text-xs text-gray-500">(CZ12345678)</span>
                  </label>
                  <input
                    type="text"
                    value={formData.companyVatId || ''}
                    onChange={(e) => {
                      let value = e.target.value.toUpperCase();
                      if (!value.startsWith('CZ') && value.length > 0) {
                        value = 'CZ' + value.replace(/\D/g, '');
                      }
                      if (value.length <= 12) { // CZ + 10 číslic max
                        setFormData(prev => ({ ...prev, companyVatId: value }));
                      }
                    }}
                    placeholder="CZ12345678"
                    maxLength={12}
                    className="w-full p-2 border rounded focus:ring-2 focus:ring-blue-500"
                  />
                </div>
              </div>
            </div>
          </div>
        )}

        {/* Default adresa */}
        <label className="flex items-center">
          <input
            type="checkbox"
            checked={formData.isDefault}
            onChange={(e) => setFormData(prev => ({ ...prev, isDefault: e.target.checked }))}
            className="mr-2"
          />
          <span className="text-sm">
            Nastavit jako výchozí {formData.addressType === 'billing' ? 'fakturační' : 'doručovací'} adresu
          </span>
        </label>

        {/* Error handling */}
        {error && (
          <div className="bg-red-50 text-red-700 p-3 rounded border border-red-200">
            <strong>Chyba:</strong> {error.message}
          </div>
        )}

        {/* Submit */}
        <button
          type="submit"
          disabled={loading}
          className="w-full bg-blue-600 hover:bg-blue-700 disabled:bg-gray-400
                     text-white font-medium py-2 px-4 rounded transition-colors"
        >
          {loading ? 'Ukládám...' : 'Uložit adresu'}
        </button>
      </form>
    </div>
  );
}
```

### 📋 Seznam adres komponenta
```typescript
// components/AddressList.tsx
import React from 'react';
import { useQuery, useMutation } from '@apollo/client';

const GET_USER_ADDRESSES = gql`
  query GetUserAddresses {
    currentUser {
      id
      addresses {
        id
        addressType
        street
        city
        postalCode
        companyName
        companyVatId
        companyRegistrationId
        isDefault
      }
    }
  }
`;

const SET_DEFAULT_ADDRESS = gql`
  mutation SetDefaultAddress($id: ID!) {
    setDefaultAddress(id: $id) {
      address {
        id
        isDefault
      }
      errors
    }
  }
`;

export default function AddressList() {
  const { data, loading, error } = useQuery(GET_USER_ADDRESSES);
  const [setDefault] = useMutation(SET_DEFAULT_ADDRESS, {
    refetchQueries: [GET_USER_ADDRESSES]
  });

  if (loading) return <div>Načítám adresy...</div>;
  if (error) return <div>Chyba při načítání adres: {error.message}</div>;

  const addresses = data?.currentUser?.addresses || [];
  const billingAddresses = addresses.filter(addr => addr.addressType === 'billing');
  const shippingAddresses = addresses.filter(addr => addr.addressType === 'shipping');

  const AddressCard = ({ address }: { address: any }) => (
    <div className={`p-4 border rounded-lg ${address.isDefault ? 'border-green-500 bg-green-50' : 'border-gray-200'}`}>
      <div className="flex justify-between items-start mb-2">
        <h4 className="font-medium">
          {address.addressType === 'billing' ? '🏢 Fakturační' : '📦 Doručovací'}
          {address.isDefault && <span className="ml-2 text-xs bg-green-600 text-white px-2 py-1 rounded">Výchozí</span>}
        </h4>

        {!address.isDefault && (
          <button
            onClick={() => setDefault({ variables: { id: address.id } })}
            className="text-xs text-blue-600 hover:text-blue-800"
          >
            Nastavit jako výchozí
          </button>
        )}
      </div>

      <div className="text-sm text-gray-700 space-y-1">
        <div>{address.street}</div>
        <div>{address.city}, {address.postalCode}</div>

        {address.companyName && (
          <div className="mt-2 pt-2 border-t border-gray-200">
            <div className="font-medium">{address.companyName}</div>
            {address.companyRegistrationId && <div>IČO: {address.companyRegistrationId}</div>}
            {address.companyVatId && <div>DIČ: {address.companyVatId}</div>}
          </div>
        )}
      </div>
    </div>
  );

  return (
    <div className="space-y-6">
      {/* Fakturační adresy */}
      <section>
        <h3 className="text-lg font-semibold mb-3">🏢 Fakturační adresy</h3>
        {billingAddresses.length > 0 ? (
          <div className="grid gap-4 md:grid-cols-2">
            {billingAddresses.map(address => (
              <AddressCard key={address.id} address={address} />
            ))}
          </div>
        ) : (
          <p className="text-gray-500 italic">Žádné fakturační adresy</p>
        )}
      </section>

      {/* Doručovací adresy */}
      <section>
        <h3 className="text-lg font-semibold mb-3">📦 Doručovací adresy</h3>
        {shippingAddresses.length > 0 ? (
          <div className="grid gap-4 md:grid-cols-2">
            {shippingAddresses.map(address => (
              <AddressCard key={address.id} address={address} />
            ))}
          </div>
        ) : (
          <p className="text-gray-500 italic">
            Žádné doručovací adresy - bude použita fakturační adresa
          </p>
        )}
      </section>
    </div>
  );
}
```

### 🎯 UX Tipy pro adresní formuláře

#### ✅ Co dělat správně:
1. **Automatické formátování** - PSČ, DIČ se formátují při psaní
2. **Inline validace** - Okamžitá kontrola IČO/DIČ formátu
3. **Smart defaults** - Země "CZ", auto-přidání "CZ" k DIČ
4. **Conditional fields** - Firemní údaje jen pro billing adresy
5. **Visual hierarchy** - Jasné rozlišení billing vs shipping
6. **Default flagging** - Uživatel ví, která adresa je výchozí

#### ❌ Čeho se vyvarovat:
1. **Příliš mnoho povinných polí** - Pro shipping jen minimum
2. **Absence auto-complete** - Používejte `autocomplete` atributy
3. **Špatné validační zprávy** - Buďte konkrétní ("IČO musí mít 8 číslic")
4. **Dlouhé formuláře** - Rozdělte billing/shipping do kroků
5. **Ignorování českých specifik** - IČO/DIČ jsou důležité pro B2B

#### 🎨 CSS utility classes pro formuláře:
```css
/* Custom CSS pro českou lokalizaci */
.czech-form-field {
  @apply w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all duration-200;
}

.czech-form-error {
  @apply text-red-600 text-sm mt-1;
}

.czech-form-success {
  @apply text-green-600 text-sm mt-1;
}

.billing-section {
  @apply bg-blue-50 border border-blue-200 rounded-lg p-4;
}

.shipping-section {
  @apply bg-gray-50 border border-gray-200 rounded-lg p-4;
}
```

---

## 🏷️ Bulk Pricing System

### Dynamické ceny podle množství
Náš backend podporuje sofistikovaný bulk pricing systém s českými B2B specifiky:

#### 📊 Cenové úrovně
- **1ks** - Retail cena (pro malé objednávky)
- **1bal** - Balení (typicky 10-12 kusů)
- **10bal** - Kartón/Paleta (120+ kusů)
- **custom** - Vlastní množstevní slevy

### GraphQL Queries pro bulk pricing
```typescript
// Real-time pricing query
const GET_PRODUCT_PRICING = gql`
  query GetProductPricing($productId: ID!, $quantity: Int!) {
    product(id: $productId) {
      id
      name
      basePrice: priceDecimal
      currentPrice: priceForQuantity(quantity: $quantity)
      savings: bulkSavingsForQuantity(quantity: $quantity)
      hasBulkPricing

      priceTiers {
        id
        tierName
        minQuantity
        maxQuantity
        priceDecimal
        quantityRangeDescription
        savingsPercentage
        description
      }
    }
  }
`;

// Lista produktů s bulk pricing info
const GET_PRODUCTS_WITH_PRICING = gql`
  query GetProductsWithPricing {
    products {
      id
      name
      priceDecimal
      hasBulkPricing

      priceTiers {
        tierName
        minQuantity
        priceDecimal
        savingsPercentage
      }
    }
  }
`;
```

### React komponenta pro cenové úrovně
```tsx
// components/BulkPricingTable.tsx
interface BulkPricingTableProps {
  product: {
    id: string;
    name: string;
    priceDecimal: number;
    priceTiers: PriceTier[];
    hasBulkPricing: boolean;
  };
  selectedQuantity: number;
  onQuantitySelect: (quantity: number) => void;
}

export default function BulkPricingTable({
  product,
  selectedQuantity,
  onQuantitySelect
}: BulkPricingTableProps) {
  if (!product.hasBulkPricing) {
    return (
      <div className="bg-gray-50 p-4 rounded-lg">
        <p className="text-lg font-semibold">{product.priceDecimal} CZK/ks</p>
        <p className="text-sm text-gray-600">Jednotná cena</p>
      </div>
    );
  }

  return (
    <div className="bulk-pricing-table">
      <h3 className="text-lg font-semibold mb-4">💰 Množstevní slevy</h3>

      <div className="overflow-x-auto">
        <table className="min-w-full bg-white border border-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-4 py-2 text-left">Množství</th>
              <th className="px-4 py-2 text-left">Cena/ks</th>
              <th className="px-4 py-2 text-left">Úspora</th>
              <th className="px-4 py-2 text-left">Akce</th>
            </tr>
          </thead>
          <tbody>
            {product.priceTiers.map((tier) => {
              const isActive = selectedQuantity >= tier.minQuantity &&
                              (tier.maxQuantity === null || selectedQuantity <= tier.maxQuantity);

              return (
                <tr
                  key={tier.id}
                  className={`border-t hover:bg-gray-50 cursor-pointer ${
                    isActive ? 'bg-green-50 border-green-200' : ''
                  }`}
                  onClick={() => onQuantitySelect(tier.minQuantity)}
                >
                  <td className="px-4 py-3">
                    <div>
                      <span className="font-medium text-sm text-gray-900">
                        {tier.tierName.toUpperCase()}
                      </span>
                      <div className="text-xs text-gray-500">
                        {tier.quantityRangeDescription}
                      </div>
                    </div>
                  </td>

                  <td className="px-4 py-3">
                    <span className="text-lg font-bold text-green-600">
                      {tier.priceDecimal.toFixed(2)} CZK
                    </span>
                  </td>

                  <td className="px-4 py-3">
                    {tier.savingsPercentage > 0 && (
                      <span className="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-red-100 text-red-700">
                        -{tier.savingsPercentage}%
                      </span>
                    )}
                  </td>

                  <td className="px-4 py-3">
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        onQuantitySelect(tier.minQuantity);
                      }}
                      className="text-sm text-blue-600 hover:text-blue-800 font-medium"
                    >
                      Vybrat
                    </button>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>

      {product.priceTiers.some(tier => tier.description) && (
        <div className="mt-3 space-y-1">
          {product.priceTiers
            .filter(tier => tier.description)
            .map(tier => (
              <p key={tier.id} className="text-xs text-gray-500">
                <strong>{tier.tierName}:</strong> {tier.description}
              </p>
            ))}
        </div>
      )}
    </div>
  );
}
```

### Smart Quantity Selector s real-time pricing
```tsx
// components/SmartQuantitySelector.tsx
import { useState, useEffect } from 'react';
import { useQuery } from '@apollo/client';

interface SmartQuantitySelectorProps {
  productId: string;
  onQuantityChange: (quantity: number, totalPrice: number, savings: number) => void;
}

export default function SmartQuantitySelector({
  productId,
  onQuantityChange
}: SmartQuantitySelectorProps) {
  const [quantity, setQuantity] = useState(1);

  // Real-time pricing query
  const { data, loading } = useQuery(GET_PRODUCT_PRICING, {
    variables: { productId, quantity },
    fetchPolicy: 'cache-and-network'
  });

  const currentPrice = data?.product?.currentPrice || 0;
  const savings = data?.product?.savings || 0;
  const totalPrice = currentPrice * quantity;
  const basePrice = data?.product?.basePrice || 0;

  useEffect(() => {
    onQuantityChange(quantity, totalPrice, savings);
  }, [quantity, totalPrice, savings, onQuantityChange]);

  const handleQuantityChange = (newQuantity: number) => {
    if (newQuantity >= 1) {
      setQuantity(newQuantity);
    }
  };

  // Quick select buttons for common bulk quantities
  const quickSelectOptions = data?.product?.priceTiers?.map(tier => ({
    quantity: tier.minQuantity,
    label: tier.tierName.toUpperCase(),
    savings: tier.savingsPercentage
  })) || [];

  return (
    <div className="space-y-4">
      {/* Manual quantity input */}
      <div className="flex items-center gap-4">
        <label className="font-medium text-sm">Množství:</label>
        <div className="flex items-center border border-gray-300 rounded-lg">
          <button
            onClick={() => handleQuantityChange(quantity - 1)}
            disabled={quantity <= 1}
            className="px-3 py-2 text-gray-600 hover:text-gray-800 disabled:opacity-50"
          >
            −
          </button>
          <input
            type="number"
            value={quantity}
            onChange={(e) => handleQuantityChange(parseInt(e.target.value) || 1)}
            min="1"
            className="w-20 px-3 py-2 text-center border-l border-r border-gray-300 focus:outline-none"
          />
          <button
            onClick={() => handleQuantityChange(quantity + 1)}
            className="px-3 py-2 text-gray-600 hover:text-gray-800"
          >
            +
          </button>
        </div>
      </div>

      {/* Quick select buttons */}
      {quickSelectOptions.length > 0 && (
        <div className="space-y-2">
          <p className="text-sm font-medium text-gray-700">Rychlý výběr:</p>
          <div className="flex flex-wrap gap-2">
            {quickSelectOptions.map((option) => (
              <button
                key={option.quantity}
                onClick={() => handleQuantityChange(option.quantity)}
                className={`px-3 py-1 text-xs rounded-full border transition-colors ${
                  quantity >= option.quantity
                    ? 'bg-blue-100 border-blue-300 text-blue-700'
                    : 'bg-gray-100 border-gray-300 text-gray-700 hover:bg-gray-200'
                }`}
              >
                {option.label}
                {option.savings > 0 && (
                  <span className="ml-1 font-medium">(-{option.savings}%)</span>
                )}
              </button>
            ))}
          </div>
        </div>
      )}

      {/* Pricing summary */}
      <div className="bg-blue-50 p-4 rounded-lg border border-blue-200">
        <div className="space-y-2">
          <div className="flex justify-between items-center">
            <span className="text-sm font-medium">Cena za kus:</span>
            <div className="text-right">
              <span className="text-lg font-bold text-blue-600">
                {currentPrice.toFixed(2)} CZK
              </span>
              {savings > 0 && basePrice > currentPrice && (
                <div className="text-xs text-gray-500 line-through">
                  {basePrice.toFixed(2)} CZK
                </div>
              )}
            </div>
          </div>

          <div className="flex justify-between items-center">
            <span className="text-sm font-medium">Celková cena:</span>
            <span className="text-xl font-bold text-blue-600">
              {totalPrice.toFixed(2)} CZK
            </span>
          </div>

          {savings > 0 && (
            <div className="pt-2 border-t border-blue-200">
              <div className="flex items-center justify-between">
                <span className="text-sm text-green-600 font-medium">
                  💰 Vaše úspora:
                </span>
                <span className="text-sm font-bold text-green-600">
                  {savings.toFixed(1)}% ({((basePrice - currentPrice) * quantity).toFixed(2)} CZK)
                </span>
              </div>
            </div>
          )}
        </div>
      </div>

      {loading && (
        <div className="text-center text-sm text-gray-500">
          Přepočítávám cenu...
        </div>
      )}
    </div>
  );
}
```

### Bulk Actions v košíku
```tsx
// components/CartBulkActions.tsx
export default function CartBulkActions({ cartItems, onBulkUpdate }) {
  const suggestBulkUpgrades = () => {
    return cartItems
      .filter(item => item.product.hasBulkPricing)
      .map(item => {
        const nextTier = item.product.priceTiers.find(
          tier => tier.minQuantity > item.quantity
        );

        if (nextTier) {
          const currentTotal = item.quantity * item.unitPrice;
          const upgradedTotal = nextTier.minQuantity * nextTier.priceDecimal;
          const savings = ((currentTotal - upgradedTotal) / currentTotal * 100);

          return {
            item,
            nextTier,
            potentialSavings: savings,
            recommendedQuantity: nextTier.minQuantity
          };
        }
        return null;
      })
      .filter(Boolean);
  };

  const suggestions = suggestBulkUpgrades();

  if (suggestions.length === 0) return null;

  return (
    <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
      <h4 className="font-medium text-yellow-800 mb-3">
        💡 Doporučení pro větší úspory
      </h4>

      <div className="space-y-3">
        {suggestions.map(({ item, nextTier, potentialSavings, recommendedQuantity }) => (
          <div key={item.id} className="flex items-center justify-between">
            <div className="flex-1">
              <p className="text-sm font-medium">{item.product.name}</p>
              <p className="text-xs text-gray-600">
                Zvyšte na {recommendedQuantity} ks pro {potentialSavings.toFixed(1)}% úsporu
              </p>
            </div>

            <button
              onClick={() => onBulkUpdate(item.id, recommendedQuantity)}
              className="ml-4 px-3 py-1 bg-yellow-600 text-white text-xs rounded hover:bg-yellow-700"
            >
              Zvýšit
            </button>
          </div>
        ))}
      </div>
    </div>
  );
}
```

### CSS Styles pro bulk pricing
```css
/* styles/bulk-pricing.css */
.bulk-pricing-table {
  @apply space-y-4;
}

.bulk-pricing-tier {
  @apply p-4 border-2 rounded-lg cursor-pointer transition-all duration-200;
}

.bulk-pricing-tier:hover {
  @apply border-blue-300 shadow-md;
}

.bulk-pricing-tier--active {
  @apply border-green-500 bg-green-50;
}

.bulk-pricing-tier--best-value {
  @apply relative;
}

.bulk-pricing-tier--best-value::before {
  content: "Nejlepší hodnota";
  @apply absolute -top-2 left-4 bg-red-500 text-white text-xs px-2 py-1 rounded;
}

.savings-badge {
  @apply inline-flex items-center px-2 py-1 rounded-full text-xs font-medium;
}

.savings-badge--low {
  @apply bg-yellow-100 text-yellow-700;
}

.savings-badge--medium {
  @apply bg-orange-100 text-orange-700;
}

.savings-badge--high {
  @apply bg-red-100 text-red-700;
}
```

---

## 🎨 Product Variants System

### Hierarchické varianty produktů
Náš backend podporuje sofistikovaný variant systém pro B2B produkty:

#### 🏗️ Architektura variant
- **Parent Product** - základní produkt (např. "Popping Pearls")
- **Variant Products** - konkrétní varianty (Jahoda 3kg, Mango 5kg, atd.)
- **Variant Attributes** - typy atributů (flavor, size, color)
- **Automatic SKU** - generované SKU kódy (0001-STR-MED)

### GraphQL Queries pro variants
```typescript
// Produkty s variantami
const GET_PRODUCTS_WITH_VARIANTS = gql`
  query GetProductsWithVariants {
    products {
      id
      name
      priceDecimal
      isVariantParent
      isVariantChild
      hasVariants
      variantsCount

      # Pro parent produkty
      variants {
        id
        name
        variantDisplayName
        priceDecimal
        quantity
        inStock
        variantSku

        # Atributy variant
        flavor {
          id
          value
          displayValue
          colorCode
        }
        size {
          id
          value
          displayValue
        }
        color {
          id
          value
          displayValue
          colorCode
        }

        # Bulk pricing pro varianty
        hasBulkPricing
        priceForQuantity(quantity: 1)
        priceForQuantity(quantity: 12)
        priceForQuantity(quantity: 120)
      }

      # Pro variant produkty
      parentProduct {
        id
        name
      }

      variantAttributeValues {
        attributeName
        attributeDisplayName
        displayValue
        colorCode
      }
    }
  }
`;

// Variant attributes
const GET_VARIANT_ATTRIBUTES = gql`
  query GetVariantAttributes {
    variantAttributes {
      id
      name
      displayName
      description
      isFlavor
      isSize
      isColor

      activeValues {
        id
        value
        displayValue
        colorCode
        description
        sortOrder
      }
    }

    flavors {
      id
      value
      displayValue
      colorCode
      productsCount
    }

    sizes {
      id
      value
      displayValue
      productsCount
    }
  }
`;
```

### React komponenta pro výběr variant
```tsx
// components/VariantSelector.tsx
import { useState } from 'react';
import { useQuery } from '@apollo/client';

interface VariantSelectorProps {
  parentProduct: {
    id: string;
    name: string;
    variants: ProductVariant[];
  };
  onVariantSelect: (variant: ProductVariant) => void;
}

export default function VariantSelector({ parentProduct, onVariantSelect }: VariantSelectorProps) {
  const [selectedAttributes, setSelectedAttributes] = useState<Record<string, string>>({});

  // Group variants by attributes for easier selection
  const variantsByAttributes = parentProduct.variants.reduce((acc, variant) => {
    const key = variant.variantAttributeValues
      .map(attr => `${attr.attributeName}:${attr.value}`)
      .join('|');
    acc[key] = variant;
    return acc;
  }, {} as Record<string, ProductVariant>);

  // Get available attribute values
  const availableAttributes = parentProduct.variants.reduce((acc, variant) => {
    variant.variantAttributeValues.forEach(attr => {
      if (!acc[attr.attributeName]) {
        acc[attr.attributeName] = {
          displayName: attr.attributeDisplayName,
          values: []
        };
      }

      const exists = acc[attr.attributeName].values.find(v => v.value === attr.value);
      if (!exists) {
        acc[attr.attributeName].values.push({
          value: attr.value,
          displayValue: attr.displayValue,
          colorCode: attr.colorCode
        });
      }
    });
    return acc;
  }, {} as Record<string, any>);

  const handleAttributeSelect = (attributeName: string, value: string) => {
    const newSelection = { ...selectedAttributes, [attributeName]: value };
    setSelectedAttributes(newSelection);

    // Find matching variant
    const attributeKey = Object.entries(newSelection)
      .map(([attr, val]) => `${attr}:${val}`)
      .sort()
      .join('|');

    const matchingVariant = Object.entries(variantsByAttributes).find(([key]) => {
      const keyParts = key.split('|').sort();
      const selectionParts = attributeKey.split('|').sort();
      return keyParts.every(part => selectionParts.includes(part));
    });

    if (matchingVariant) {
      onVariantSelect(matchingVariant[1]);
    }
  };

  return (
    <div className="variant-selector space-y-6">
      <h3 className="text-lg font-semibold">{parentProduct.name}</h3>

      {Object.entries(availableAttributes).map(([attributeName, attributeData]) => (
        <div key={attributeName} className="space-y-2">
          <label className="block text-sm font-medium text-gray-700">
            {attributeData.displayName}
          </label>

          <div className="flex flex-wrap gap-2">
            {attributeData.values.map((value: any) => {
              const isSelected = selectedAttributes[attributeName] === value.value;

              return (
                <button
                  key={value.value}
                  onClick={() => handleAttributeSelect(attributeName, value.value)}
                  className={`px-4 py-2 rounded-lg border-2 transition-all ${
                    isSelected
                      ? 'border-blue-500 bg-blue-50 text-blue-700'
                      : 'border-gray-300 hover:border-gray-400 text-gray-700'
                  }`}
                  style={value.colorCode ? {
                    borderLeftColor: value.colorCode,
                    borderLeftWidth: '4px'
                  } : {}}
                >
                  {value.displayValue}
                  {value.colorCode && (
                    <span
                      className="inline-block w-3 h-3 rounded-full ml-2"
                      style={{ backgroundColor: value.colorCode }}
                    />
                  )}
                </button>
              );
            })}
          </div>
        </div>
      ))}
    </div>
  );
}
```

### Karta varianty produktu
```tsx
// components/VariantCard.tsx
interface VariantCardProps {
  variant: ProductVariant;
  onAddToCart: (variant: ProductVariant, quantity: number) => void;
}

export default function VariantCard({ variant, onAddToCart }: VariantCardProps) {
  const [quantity, setQuantity] = useState(1);

  return (
    <div className="variant-card bg-white border border-gray-200 rounded-lg p-6 hover:shadow-md transition-shadow">
      <div className="flex items-start justify-between mb-4">
        <div>
          <h4 className="text-lg font-semibold text-gray-900">
            {variant.variantDisplayName}
          </h4>
          <p className="text-sm text-gray-600 mt-1">
            SKU: {variant.variantSku}
          </p>
        </div>

        <div className="text-right">
          <p className="text-2xl font-bold text-green-600">
            {variant.priceDecimal} CZK
          </p>
          {variant.hasBulkPricing && (
            <p className="text-xs text-gray-500">
              od {variant.priceForQuantity(12)} CZK při 12+ ks
            </p>
          )}
        </div>
      </div>

      {/* Variant attributes */}
      <div className="flex flex-wrap gap-2 mb-4">
        {variant.flavor && (
          <span
            className="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-pink-100 text-pink-800"
            style={variant.flavor.colorCode ? {
              backgroundColor: variant.flavor.colorCode + '20',
              color: variant.flavor.colorCode
            } : {}}
          >
            🍓 {variant.flavor.displayValue}
          </span>
        )}

        {variant.size && (
          <span className="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
            📦 {variant.size.displayValue}
          </span>
        )}

        {variant.color && (
          <span className="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
            <span
              className="w-3 h-3 rounded-full mr-1"
              style={{ backgroundColor: variant.color.colorCode }}
            />
            {variant.color.displayValue}
          </span>
        )}
      </div>

      {/* Stock status */}
      <div className="mb-4">
        {variant.inStock ? (
          <span className="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-green-100 text-green-800">
            ✅ Skladem ({variant.quantity} ks)
          </span>
        ) : (
          <span className="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-red-100 text-red-800">
            ❌ Vyprodáno
          </span>
        )}
      </div>

      {/* Quantity selector and add to cart */}
      {variant.inStock && (
        <div className="flex items-center gap-4">
          <div className="flex items-center border border-gray-300 rounded-lg">
            <button
              onClick={() => setQuantity(Math.max(1, quantity - 1))}
              className="px-3 py-2 text-gray-600 hover:text-gray-800"
            >
              −
            </button>
            <input
              type="number"
              value={quantity}
              onChange={(e) => setQuantity(Math.max(1, parseInt(e.target.value) || 1))}
              min="1"
              max={variant.quantity}
              className="w-16 px-3 py-2 text-center border-l border-r border-gray-300 focus:outline-none"
            />
            <button
              onClick={() => setQuantity(Math.min(variant.quantity, quantity + 1))}
              className="px-3 py-2 text-gray-600 hover:text-gray-800"
            >
              +
            </button>
          </div>

          <button
            onClick={() => onAddToCart(variant, quantity)}
            className="flex-1 bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition-colors"
          >
            Přidat do košíku
          </button>
        </div>
      )}
    </div>
  );
}
```

### Grid variant produktů
```tsx
// components/VariantGrid.tsx
interface VariantGridProps {
  parentProduct: {
    id: string;
    name: string;
    variants: ProductVariant[];
  };
  onAddToCart: (variant: ProductVariant, quantity: number) => void;
}

export default function VariantGrid({ parentProduct, onAddToCart }: VariantGridProps) {
  return (
    <div className="variant-grid">
      <div className="mb-6">
        <h2 className="text-2xl font-bold text-gray-900">{parentProduct.name}</h2>
        <p className="text-gray-600 mt-2">
          {parentProduct.variants.length} variant{parentProduct.variants.length !== 1 ? 'y' : 'a'} k dispozici
        </p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {parentProduct.variants.map((variant) => (
          <VariantCard
            key={variant.id}
            variant={variant}
            onAddToCart={onAddToCart}
          />
        ))}
      </div>
    </div>
  );
}
```

### Mutation pro vytvoření varianty
```typescript
// mutations/variants.ts
const CREATE_PRODUCT_VARIANT = gql`
  mutation CreateProductVariant(
    $parentProductId: ID!
    $variantAttributes: JSON!
    $priceCents: Int!
    $quantity: Int!
    $description: String
    $weightValue: Float
    $weightUnit: String
  ) {
    createProductVariant(
      parentProductId: $parentProductId
      variantAttributes: $variantAttributes
      priceCents: $priceCents
      quantity: $quantity
      description: $description
      weightValue: $weightValue
      weightUnit: $weightUnit
    ) {
      variant {
        id
        name
        variantDisplayName
        variantSku
        priceDecimal
        quantity
        inStock

        flavor {
          displayValue
          colorCode
        }

        size {
          displayValue
        }

        parentProduct {
          id
          name
        }
      }
      errors
    }
  }
`;

// Použití v komponentě
function CreateVariantForm({ parentProductId, onSuccess }) {
  const [createVariant] = useMutation(CREATE_PRODUCT_VARIANT);

  const handleSubmit = async (formData) => {
    try {
      const { data } = await createVariant({
        variables: {
          parentProductId,
          variantAttributes: {
            flavor: formData.flavorId,
            size: formData.sizeId
          },
          priceCents: formData.priceCents,
          quantity: formData.quantity,
          description: formData.description,
          weightValue: formData.weightValue,
          weightUnit: formData.weightUnit
        }
      });

      if (data.createProductVariant.errors.length === 0) {
        onSuccess(data.createProductVariant.variant);
      } else {
        // Handle errors
        console.error(data.createProductVariant.errors);
      }
    } catch (error) {
      console.error('Error creating variant:', error);
    }
  };

  // ... form rendering
}
```

### CSS Styles pro variants
```css
/* styles/variants.css */
.variant-selector {
  @apply space-y-6;
}

.variant-card {
  @apply bg-white border border-gray-200 rounded-lg p-6 hover:shadow-md transition-shadow;
}

.variant-card--selected {
  @apply border-blue-500 bg-blue-50;
}

.variant-attribute-badge {
  @apply inline-flex items-center px-2 py-1 rounded-full text-xs font-medium;
}

.variant-attribute-badge--flavor {
  @apply bg-pink-100 text-pink-800;
}

.variant-attribute-badge--size {
  @apply bg-blue-100 text-blue-800;
}

.variant-attribute-badge--color {
  @apply bg-gray-100 text-gray-800;
}

.variant-grid {
  @apply grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6;
}

.variant-selector-button {
  @apply px-4 py-2 rounded-lg border-2 transition-all cursor-pointer;
}

.variant-selector-button:hover {
  @apply border-gray-400;
}

.variant-selector-button--selected {
  @apply border-blue-500 bg-blue-50 text-blue-700;
}

.variant-color-indicator {
  @apply inline-block w-3 h-3 rounded-full;
}
```

---

## 📚 Docusaurus Documentation

### Moderní dokumentační systém pro B2B API
Pro komplexní dokumentaci našeho B2B API a frontend komponent používáme **Docusaurus v3** - moderní static site generator od Meta.

#### 🏗️ Struktura dokumentace
```
docs/
├── docusaurus.config.js     # Konfigurace Docusaurus
├── package.json             # Dependencies
├── docs/                    # Markdown dokumenty
│   ├── intro.md            # Úvodní stránka
│   ├── api/                # API dokumentace
│   │   ├── graphql.md      # GraphQL schema a queries
│   │   ├── mutations.md    # Mutations a examples
│   │   └── types.md        # TypeScript types
│   ├── components/         # React komponenty
│   │   ├── products.md     # Product komponenty
│   │   ├── variants.md     # Variant komponenty
│   │   └── bulk-pricing.md # Bulk pricing komponenty
│   └── guides/             # Návody a tutoriály
│       ├── setup.md        # Nastavení projektu
│       ├── authentication.md # Auth flow
│       └── deployment.md   # Deployment guide
├── src/                    # Custom React komponenty
│   ├── components/         # Reusable komponenty
│   ├── css/               # Custom CSS
│   └── pages/             # Custom stránky
└── static/                # Statické soubory
    ├── img/               # Obrázky a loga
    └── api/               # API examples
```

#### 🚀 Výhody Docusaurus pro B2B projekt
- **Automatické API docs** - generování z GraphQL schema
- **Interaktivní examples** - live code examples s GraphQL Playground
- **Versioning** - dokumentace pro různé verze API
- **Search** - pokročilé vyhledávání v dokumentaci
- **Dark/Light mode** - pro lepší UX
- **Mobile responsive** - dokumentace dostupná všude
- **Czech localization** - podpora češtiny

#### 📦 Instalace a setup
```bash
# Vytvoření Docusaurus projektu
npx create-docusaurus@latest docs classic --typescript

# Instalace additional packages
cd docs
npm install @docusaurus/theme-live-codeblock
npm install @graphql-tools/schema
npm install graphql-playground-react
```

#### ⚙️ Konfigurace pro B2B API
```javascript
// docusaurus.config.js
module.exports = {
  title: 'Lootea B2B API Documentation',
  tagline: 'Complete B2B e-commerce API with GraphQL',
  url: 'https://api-docs.lootea.cz',
  baseUrl: '/',

  themeConfig: {
    navbar: {
      title: 'Lootea B2B API',
      items: [
        {
          type: 'doc',
          docId: 'intro',
          position: 'left',
          label: 'Dokumentace',
        },
        {
          to: '/api/playground',
          label: 'GraphQL Playground',
          position: 'left',
        },
        {
          href: 'https://github.com/lootea/b2b-backend',
          label: 'GitHub',
          position: 'right',
        },
      ],
    },

    prism: {
      theme: require('prism-react-renderer/themes/github'),
      darkTheme: require('prism-react-renderer/themes/dracula'),
      additionalLanguages: ['graphql', 'typescript', 'bash'],
    },

    liveCodeBlock: {
      playgroundPosition: 'bottom',
    },
  },

  plugins: [
    [
      '@docusaurus/plugin-content-docs',
      {
        routeBasePath: '/',
        sidebarPath: require.resolve('./sidebars.js'),
      },
    ],
  ],
};
```

#### 🎨 Custom komponenty pro API docs
```tsx
// src/components/GraphQLExample.tsx
import React from 'react';
import CodeBlock from '@theme/CodeBlock';

interface GraphQLExampleProps {
  query: string;
  variables?: object;
  response?: object;
}

export default function GraphQLExample({ query, variables, response }: GraphQLExampleProps) {
  return (
    <div className="graphql-example">
      <div className="query-section">
        <h4>Query</h4>
        <CodeBlock language="graphql">{query}</CodeBlock>
      </div>

      {variables && (
        <div className="variables-section">
          <h4>Variables</h4>
          <CodeBlock language="json">{JSON.stringify(variables, null, 2)}</CodeBlock>
        </div>
      )}

      {response && (
        <div className="response-section">
          <h4>Response</h4>
          <CodeBlock language="json">{JSON.stringify(response, null, 2)}</CodeBlock>
        </div>
      )}
    </div>
  );
}
```

#### 📝 Markdown dokumenty s live examples
```markdown
---
sidebar_position: 1
title: Product Variants API
---

# Product Variants

Náš API podporuje sofistikovaný systém variant produktů.

## Získání produktů s variantami

<GraphQLExample
  query={`
    query GetProductsWithVariants {
      products {
        id
        name
        isVariantParent
        variants {
          id
          variantDisplayName
          priceDecimal
          flavor {
            displayValue
            colorCode
          }
        }
      }
    }
  `}
  response={{
    "data": {
      "products": [
        {
          "id": "1",
          "name": "Popping Pearls",
          "isVariantParent": true,
          "variants": [
            {
              "id": "2",
              "variantDisplayName": "Popping Pearls - Jahoda Střední",
              "priceDecimal": 250.0,
              "flavor": {
                "displayValue": "Jahoda",
                "colorCode": "#FF6B6B"
              }
            }
          ]
        }
      ]
    }
  }}
/>
```

#### 🌐 Deployment na Vercel/Netlify
```bash
# Build dokumentace
npm run build

# Deploy na Vercel
npx vercel --prod

# Deploy na Netlify
npm run build && npx netlify deploy --prod --dir=build
```

#### 💡 Tip pro lepší UX
- **Auto-refresh** při změnách v API
- **Copy-paste examples** - jednoduchý copy GraphQL queries
- **Interactive playground** - testování API přímo v docs
- **Changelog** - automatické generování z git commits
- **API status** - real-time status API endpointů

---

## ❌ Error Handling

### Základní error handling
```typescript
// utils/errorHandler.ts
export const handleGraphQLError = (error) => {
  // GraphQL chyby
  if (error.graphQLErrors?.length > 0) {
    error.graphQLErrors.forEach(({ message, locations, path }) => {
      console.log(`GraphQL error: ${message}`);
    });
  }

  // Network chyby
  if (error.networkError) {
    console.log(`Network error: ${error.networkError}`);

    // Pokud je to 401, přesměrujeme na login
    if (error.networkError.statusCode === 401) {
      localStorage.removeItem('authToken');
      window.location.href = '/login';
    }
  }
};

// Použití v komponentě
function MyComponent() {
  const { loading, error, data } = useQuery(GET_PRODUCTS);

  if (error) {
    handleGraphQLError(error);
    return <div>Nastala chyba při načítání dat</div>;
  }

  // ...zbytek komponenty
}
```

---

## 💳 Payment Errors

### Lokalizace chybových kódů
```typescript
// utils/paymentErrors.ts
const errorMessages = {
  'UNAUTHORIZED': 'Musíte být přihlášeni',
  'ORDER_NOT_FOUND': 'Objednávka nenalezena',
  'ORDER_NOT_PAYABLE': 'Objednávku nelze zaplatit',
  'PAYMENT_ALREADY_EXISTS': 'Objednávka už má aktivní platbu',
  'PAYMENT_CREATION_FAILED': 'Chyba při vytváření platby',
  'INTERNAL_ERROR': 'Došlo k chybě, zkuste to později'
};

export const getErrorMessage = (errorCode: string): string => {
  return errorMessages[errorCode] || 'Neznámá chyba';
};

// Použití při payment mutation
const PAY_ORDER = gql`
  mutation PayOrder($orderId: ID!) {
    payOrder(
      orderId: $orderId
    ) {
      success
      paymentUrl
      paymentId
      errorCode
      errors
    }
  }
`;

function PaymentButton({ orderId }) {
  const [payOrder, { loading }] = useMutation(PAY_ORDER);

  const handlePayment = async () => {
    try {
      const { data } = await payOrder({
        variables: { orderId }
      });

      if (data.payOrder.success) {
        // Přesměrujeme na platební bránu
        window.location.href = data.payOrder.paymentUrl;
      } else {
        // Zobrazíme lokalizovanou chybu podle error kódu
        const errorMessage = getErrorMessage(data.payOrder.errorCode);
        alert(errorMessage);
      }
    } catch (err) {
      alert('Chyba při zpracování platby');
    }
  };

  return (
    <button onClick={handlePayment} disabled={loading}>
      {loading ? 'Zpracováváme platbu...' : 'Zaplatit'}
    </button>
  );
}
```

### Toast notifikace pro chyby
```typescript
// Doporučuji použít react-hot-toast
import toast from 'react-hot-toast';

const handlePaymentError = (errorCode: string) => {
  const message = getErrorMessage(errorCode);

  // Různé typy toastů podle chyby
  if (errorCode === 'UNAUTHORIZED') {
    toast.error(message, {
      duration: 4000,
      icon: '🔒',
    });
  } else if (errorCode === 'PAYMENT_ALREADY_EXISTS') {
    toast.error(message, {
      duration: 4000,
      icon: '💳',
    });
  } else {
    toast.error(message);
  }
};
```

---

## 🔧 TypeScript Setup

### Automatické generování typů
```bash
# Instalace
npm install -D @graphql-codegen/cli @graphql-codegen/typescript @graphql-codegen/typescript-operations @graphql-codegen/typescript-react-apollo

# Konfigurace codegen.yml
overwrite: true
schema: "http://localhost:3000/graphql"
documents: "src/**/*.{ts,tsx}"
generates:
  src/generated/graphql.ts:
    plugins:
      - "typescript"
      - "typescript-operations"
      - "typescript-react-apollo"
    config:
      withHooks: true
```

### Použití generovaných typů
```typescript
// Po spuštění npm run codegen
import {
  useGetProductsQuery,
  useCreateOrderMutation,
  Product,
  Order
} from '../generated/graphql';

function TypedProductList() {
  // Automaticky typované!
  const { data, loading, error } = useGetProductsQuery();

  if (loading) return <div>Loading...</div>;
  if (error) return <div>Error: {error.message}</div>;

  return (
    <div>
      {data?.products.map((product: Product) => (
        <div key={product.id}>
          <h3>{product.name}</h3>
          <p>{product.priceDecimal} {product.currency}</p>
        </div>
      ))}
    </div>
  );
}
```

---

## 🎨 UI Tips

### Loading states s skeleton UI
```typescript
function ProductSkeleton() {
  return (
    <div className="animate-pulse">
      <div className="h-4 bg-gray-300 rounded w-3/4 mb-2"></div>
      <div className="h-4 bg-gray-300 rounded w-1/2 mb-2"></div>
      <div className="h-4 bg-gray-300 rounded w-1/4"></div>
    </div>
  );
}

function ProductList() {
  const { loading, data } = useGetProductsQuery();

  if (loading) {
    return (
      <div>
        {Array.from({ length: 6 }).map((_, i) => (
          <ProductSkeleton key={i} />
        ))}
      </div>
    );
  }

  return (
    <div>
      {data?.products.map(product => (
        <ProductCard key={product.id} product={product} />
      ))}
    </div>
  );
}
```

### Optimistic updates
```typescript
const [createOrder] = useMutation(CREATE_ORDER, {
  // Optimistic response - UI se aktualizuje okamžitě
  optimisticResponse: {
    createOrder: {
      order: {
        id: 'temp-id',
        totalDecimal: 999.99,
        status: 'pending',
        itemsCount: 2,
        __typename: 'Order'
      },
      errors: [],
      __typename: 'CreateOrderPayload'
    }
  },

  // Aktualizace cache
  update: (cache, { data }) => {
    const existingOrders = cache.readQuery({ query: GET_MY_ORDERS });

    if (existingOrders && data.createOrder.order) {
      cache.writeQuery({
        query: GET_MY_ORDERS,
        data: {
          myOrders: [data.createOrder.order, ...existingOrders.myOrders]
        }
      });
    }
  }
});
```

### Error Boundary komponenta
```typescript
import React from 'react';

class ErrorBoundary extends React.Component {
  constructor(props) {
    super(props);
    this.state = { hasError: false };
  }

  static getDerivedStateFromError(error) {
    return { hasError: true };
  }

  componentDidCatch(error, errorInfo) {
    console.error('Error caught by boundary:', error, errorInfo);
  }

  render() {
    if (this.state.hasError) {
      return (
        <div className="text-center p-8">
          <h2 className="text-xl font-bold mb-4">Něco se pokazilo</h2>
          <p className="text-gray-600 mb-4">
            Omlouváme se, došlo k neočekávané chybě.
          </p>
          <button
            onClick={() => window.location.reload()}
            className="bg-blue-500 text-white px-4 py-2 rounded"
          >
            Znovu načíst stránku
          </button>
        </div>
      );
    }

    return this.props.children;
  }
}

// Použití
function App() {
  return (
    <ErrorBoundary>
      <ApolloProvider client={client}>
        <MyApp />
      </ApolloProvider>
    </ErrorBoundary>
  );
}
```

---

## 💳 Payment Webhook (pro vývojáře)

### Jak funguje platební proces
1. Frontend zavolá `payOrder` mutation
2. Backend vytvoří platbu v Comgate
3. Uživatel je přesměrován na platební bránu
4. Po platbě Comgate pošle webhook na náš backend
5. Backend aktualizuje status objednávky
6. Frontend může polling/refetch pro aktuální status

### Webhook endpoint (pouze informativně)
- **URL:** `POST /webhooks/comgate`
- **Zabezpečení:** HMAC-SHA256 signature
- **Automatické:** Comgate volá sám po změně statusu

### Status mapping pro UI
```typescript
// Tyto statusy můžeš očekávat v objednávce
const paymentStatusLabels = {
  'no_payment': 'Čeká na platbu',
  'payment_pending': 'Platba probíhá...',
  'payment_completed': 'Zaplaceno ✅',
  'payment_failed': 'Platba selhala ❌',
  'payment_cancelled': 'Platba zrušena'
};

// Použití v komponentě
function PaymentStatus({ order }) {
  const statusLabel = paymentStatusLabels[order.paymentStatus] || 'Neznámý status';
  const statusColor = {
    'no_payment': 'text-gray-500',
    'payment_pending': 'text-yellow-500',
    'payment_completed': 'text-green-500',
    'payment_failed': 'text-red-500',
    'payment_cancelled': 'text-red-400'
  }[order.paymentStatus] || 'text-gray-500';

  return (
    <span className={statusColor}>
      {statusLabel}
    </span>
  );
}
```

### Polling pro aktuální status
```typescript
// Doporučený způsob pro kontrolu statusu po návratu z platby
const GET_ORDER_STATUS = gql`
  query GetOrderStatus($id: ID!) {
    order(id: $id) {
      id
      paymentStatus
      paymentPending
      paymentCompleted
      paymentFailed
      totalDecimal
    }
  }
`;

function OrderStatusChecker({ orderId }) {
  const { data, startPolling, stopPolling } = useQuery(GET_ORDER_STATUS, {
    variables: { id: orderId },
    pollInterval: 0 // Vypnuto defaultně
  });

  // Spustit polling po návratu z platby
  useEffect(() => {
    const urlParams = new URLSearchParams(window.location.search);
    const justReturnedFromPayment = urlParams.get('payment') === 'return';

    if (justReturnedFromPayment) {
      startPolling(2000); // Každé 2 sekundy

      // Zastavit po 30 sekundách nebo když je zaplaceno/selhalo
      const timeout = setTimeout(() => stopPolling(), 30000);

      if (data?.order?.paymentCompleted || data?.order?.paymentFailed) {
        stopPolling();
        clearTimeout(timeout);
      }

      return () => clearTimeout(timeout);
    }
  }, [data?.order?.paymentCompleted, data?.order?.paymentFailed]);

  return (
    <div>
      <PaymentStatus order={data?.order} />
    </div>
  );
}
```

### Testování plateb v development

#### 1. Test webhook endpoint (pro backend vývojáře)
```bash
# Test že webhook endpoint funguje
curl -X POST http://localhost:3000/webhooks/comgate \
  -H "Content-Type: application/json" \
  -d '{
    "transId": "test123",
    "refId": "1",
    "status": "PAID",
    "price": "299",
    "curr": "CZK",
    "test": "true"
  }'
```

#### 2. Simulace platebního procesu ve frontend
```typescript
// Hook pro simulaci platby v development
const useTestPayment = (orderId: string) => {
  const [payOrder] = useMutation(PAY_ORDER);

  const simulatePayment = async (status: 'PAID' | 'CANCELLED' | 'FAILED') => {
    if (process.env.NODE_ENV !== 'development') {
      console.warn('Test platby pouze v development!');
      return;
    }

    try {
      // 1. Vytvoř platbu
      const { data } = await payOrder({ variables: { orderId } });

      if (!data.payOrder.success) {
        console.error('Chyba při vytváření platby:', data.payOrder.errorCode);
        return;
      }

      // 2. Simuluj webhook po 2 sekundách
      setTimeout(async () => {
        await fetch('http://localhost:3000/webhooks/comgate', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            transId: data.payOrder.paymentId,
            refId: orderId,
            status: status,
            price: "299",
            curr: "CZK",
            test: "true"
          })
        });

        console.log(`Simulován webhook se statusem: ${status}`);
      }, 2000);

    } catch (error) {
      console.error('Chyba při simulaci platby:', error);
    }
  };

  return { simulatePayment };
};

// Použití v development komponentě
function TestPaymentButtons({ orderId }) {
  const { simulatePayment } = useTestPayment(orderId);

  if (process.env.NODE_ENV !== 'development') {
    return null;
  }

  return (
    <div className="p-4 bg-yellow-100 border border-yellow-400 rounded">
      <h3 className="font-bold mb-2">🧪 Test platby (pouze development)</h3>
      <div className="space-x-2">
        <button
          onClick={() => simulatePayment('PAID')}
          className="bg-green-500 text-white px-3 py-1 rounded"
        >
          Simulovat úspěšnou platbu
        </button>
        <button
          onClick={() => simulatePayment('FAILED')}
          className="bg-red-500 text-white px-3 py-1 rounded"
        >
          Simulovat neúspěšnou platbu
        </button>
        <button
          onClick={() => simulatePayment('CANCELLED')}
          className="bg-gray-500 text-white px-3 py-1 rounded"
        >
          Simulovat zrušenou platbu
        </button>
      </div>
    </div>
  );
}
```

### Payment Flow UX doporučení

#### 1. Loading states během platby
```typescript
function PaymentButton({ orderId }) {
  const [payOrder, { loading }] = useMutation(PAY_ORDER);
  const [isRedirecting, setIsRedirecting] = useState(false);

  const handlePayment = async () => {
    try {
      const { data } = await payOrder({ variables: { orderId } });

      if (data.payOrder.success) {
        setIsRedirecting(true);
        // Krátké zpoždění pro UX
        setTimeout(() => {
          window.location.href = data.payOrder.paymentUrl;
        }, 1000);
      }
    } catch (error) {
      setIsRedirecting(false);
    }
  };

  if (isRedirecting) {
    return (
      <div className="text-center p-4">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-500 mx-auto mb-2"></div>
        <p>Přesměrováváme na platební bránu...</p>
      </div>
    );
  }

  return (
    <button
      onClick={handlePayment}
      disabled={loading}
      className="bg-blue-500 text-white px-6 py-2 rounded disabled:opacity-50"
    >
      {loading ? 'Připravujeme platbu...' : 'Zaplatit'}
    </button>
  );
}
```

#### 2. Return URL handling
```typescript
// pages/payment-return.tsx nebo podobná komponenta
function PaymentReturn() {
  const router = useRouter();
  const { orderId } = router.query;

  const { data, loading } = useQuery(GET_ORDER_STATUS, {
    variables: { id: orderId },
    pollInterval: 2000, // Polling každé 2 sekundy
    skip: !orderId
  });

  useEffect(() => {
    if (data?.order) {
      const { paymentCompleted, paymentFailed, paymentCancelled } = data.order;

      if (paymentCompleted) {
        // Úspěšná platba
        toast.success('Platba byla úspěšně dokončena! 🎉');
        router.push(`/orders/${orderId}?success=true`);
      } else if (paymentFailed || paymentCancelled) {
        // Neúspěšná platba
        toast.error('Platba se nezdařila. Zkuste to prosím znovu.');
        router.push(`/orders/${orderId}?error=true`);
      }
    }
  }, [data?.order]);

  return (
    <div className="text-center p-8">
      <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-500 mx-auto mb-4"></div>
      <h2 className="text-xl font-bold mb-2">Zpracováváme vaši platbu</h2>
      <p className="text-gray-600">Prosím čekejte, ověřujeme stav platby...</p>
    </div>
  );
}
```

### Webhook troubleshooting

#### Časté problémy
1. **Webhook se nevolá** - Zkontroluj URL v Comgate nastavení
2. **Neplatný podpis** - Zkontroluj secret key v credentials
3. **Order nenalezen** - Zkontroluj refId mapping
4. **Status se neaktualizuje** - Zkontroluj allowed transitions

#### Debug webhook v development
```bash
# Použij ngrok pro lokální webhook testing
npx ngrok http 3000

# Pak nastav webhook URL v Comgate na:
# https://your-ngrok-url.ngrok.io/webhooks/comgate
```

---

## 🐛 Troubleshooting

### Časté problémy a řešení

#### 1. "Network error: Failed to fetch"
```typescript
// Řešení: Zkontroluj CORS a URL
const httpLink = createHttpLink({
  uri: 'http://localhost:3000/graphql', // Správná URL?
  credentials: 'include', // Pro cookies
});
```

#### 2. "You must be authenticated"
```typescript
// Řešení: Zkontroluj token
const token = localStorage.getItem('authToken');
console.log('Token:', token); // Je token v localStorage?

// Zkontroluj Authorization header
const authLink = setContext((_, { headers }) => {
  const token = localStorage.getItem('authToken');
  console.log('Sending token:', token); // Debug

  return {
    headers: {
      ...headers,
      authorization: token ? `Bearer ${token}` : "",
    }
  }
});
```

#### 3. Cache problémy
```typescript
// Vyčištění cache
client.resetStore(); // Vymaže celou cache
// nebo
client.refetchQueries({ include: 'active' }); // Znovu načte aktivní queries
```

#### 4. TypeScript chyby
```bash
# Znovu vygeneruj typy
npm run codegen

# Zkontroluj GraphQL schema
npm run graphql:schema
```

### Debug nástroje

#### Apollo DevTools
```bash
# Rozšíření pro Chrome/Firefox
# Umožňuje prohlížet queries, mutations a cache
```

#### GraphQL Playground
```typescript
// Přidej do Rails routes.rb pro development
if Rails.env.development?
  mount GraphiQL::Rails::Engine, at: "/graphiql", graphql_path: "/graphql"
end
```

---

## 📁 File Upload

### Upload produktových obrázků
```typescript
// mutations/upload.ts
const UPLOAD_PRODUCT_IMAGES = gql`
  mutation UploadProductImages($productId: ID!, $images: [Upload!]!) {
    uploadProductImages(productId: $productId, images: $images) {
      product {
        id
        name
        imageUrls
        hasImages
      }
      success
      errors
    }
  }
`;

// Použití v komponentě (pouze admin)
function ProductImageUpload({ productId }) {
  const [uploadImages, { loading }] = useMutation(UPLOAD_PRODUCT_IMAGES);
  const [selectedFiles, setSelectedFiles] = useState([]);

  const handleFileSelect = (event) => {
    const files = Array.from(event.target.files);
    if (files.length > 10) {
      alert('Maximálně 10 obrázků na produkt');
      return;
    }
    setSelectedFiles(files);
  };

  const handleUpload = async () => {
    try {
      const { data } = await uploadImages({
        variables: {
          productId,
          images: selectedFiles
        }
      });

      if (data.uploadProductImages.success) {
        alert('Obrázky nahrány úspěšně!');
        setSelectedFiles([]);
      } else {
        alert('Chyby: ' + data.uploadProductImages.errors.join(', '));
      }
    } catch (err) {
      alert('Chyba při nahrávání obrázků');
    }
  };

  return (
    <div>
      <input
        type="file"
        multiple
        accept="image/jpeg,image/png,image/gif,image/webp"
        onChange={handleFileSelect}
      />
      <button onClick={handleUpload} disabled={loading || selectedFiles.length === 0}>
        {loading ? 'Nahrávám...' : `Nahrát ${selectedFiles.length} obrázků`}
      </button>
    </div>
  );
}
```

### Upload avataru uživatele
```typescript
const UPLOAD_USER_AVATAR = gql`
  mutation UploadUserAvatar($avatar: Upload!) {
    uploadUserAvatar(avatar: $avatar) {
      user {
        id
        email
        avatarUrl
      }
      success
      errors
    }
  }
`;

function AvatarUpload() {
  const [uploadAvatar, { loading }] = useMutation(UPLOAD_USER_AVATAR);

  const handleAvatarChange = async (event) => {
    const file = event.target.files[0];
    if (!file) return;

    // Validace na frontendu
    if (file.size > 2 * 1024 * 1024) {
      alert('Avatar může mít maximálně 2 MB');
      return;
    }

    try {
      const { data } = await uploadAvatar({
        variables: { avatar: file }
      });

      if (data.uploadUserAvatar.success) {
        alert('Avatar nahrán úspěšně!');
        // Refresh user data
        window.location.reload();
      } else {
        alert('Chyby: ' + data.uploadUserAvatar.errors.join(', '));
      }
    } catch (err) {
      alert('Chyba při nahrávání avataru');
    }
  };

  return (
    <div>
      <input
        type="file"
        accept="image/jpeg,image/png,image/gif,image/webp"
        onChange={handleAvatarChange}
      />
      {loading && <p>Nahrávám avatar...</p>}
    </div>
  );
}
```

### Upload loga firmy
```typescript
const UPLOAD_COMPANY_LOGO = gql`
  mutation UploadCompanyLogo($logo: Upload!) {
    uploadCompanyLogo(logo: $logo) {
      user {
        id
        companyName
        companyLogoUrl
      }
      success
      errors
    }
  }
`;

function CompanyLogoUpload() {
  const [uploadLogo, { loading }] = useMutation(UPLOAD_COMPANY_LOGO);

  const handleLogoChange = async (event) => {
    const file = event.target.files[0];
    if (!file) return;

    // Validace na frontendu
    if (file.size > 3 * 1024 * 1024) {
      alert('Logo může mít maximálně 3 MB');
      return;
    }

    try {
      const { data } = await uploadLogo({
        variables: { logo: file }
      });

      if (data.uploadCompanyLogo.success) {
        alert('Logo nahráno úspěšně!');
        // Refresh user data
        window.location.reload();
      } else {
        alert('Chyby: ' + data.uploadCompanyLogo.errors.join(', '));
      }
    } catch (err) {
      alert('Chyba při nahrávání loga');
    }
  };

  return (
    <div>
      <input
        type="file"
        accept="image/jpeg,image/png,image/gif,image/webp,image/svg+xml,application/pdf"
        onChange={handleLogoChange}
      />
      {loading && <p>Nahrávám logo...</p>}
    </div>
  );
}
```

### Zobrazení nahraných obrázků (s Next.js optimalizací)
```typescript
import Image from 'next/image';

// Komponenta pro zobrazení produktu s obrázky
function ProductCard({ product }) {
  return (
    <div>
      <h3>{product.name}</h3>

      {product.hasImages && (
        <div style={{ display: 'flex', gap: '10px' }}>
          {product.imageUrls.map((imageUrl, index) => (
            <Image
              key={index}
              src={imageUrl}
              alt={`${product.name} - obrázek ${index + 1}`}
              width={100}
              height={100}
              style={{ objectFit: 'cover' }}
              placeholder="blur"
              blurDataURL="data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAYEBQYFBAYGBQYHBwYIChAKCgkJChQODwwQFxQYGBcUFhYaHSUfGhsjHBYWICwgIyYnKSopGR8tMC0oMCUoKSj/2wBDAQcHBwoIChMKChMoGhYaKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCj/wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAv/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFQEBAQAAAAAAAAAAAAAAAAAAAAX/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIRAxEAPwCdABmX/9k="
            />
          ))}
        </div>
      )}

      <p>{product.priceDecimal} {product.currency}</p>
    </div>
  );
}

// Komponenta pro profil uživatele s avatarem
function UserProfile({ user }) {
  return (
    <div>
      {user.avatarUrl && (
        <Image
          src={user.avatarUrl}
          alt="Avatar uživatele"
          width={50}
          height={50}
          style={{ borderRadius: '50%', objectFit: 'cover' }}
          placeholder="blur"
          blurDataURL="data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAYEBQYFBAYGBQYHBwYIChAKCgkJChQODwwQFxQYGBcUFhYaHSUfGhsjHBYWICwgIyYnKSopGR8tMC0oMCUoKSj/2wBDAQcHBwoIChMKChMoGhYaKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCj/wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAv/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFQEBAQAAAAAAAAAAAAAAAAAAAAX/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIRAxEAPwCdABmX/9k="
        />
      )}

      <h2>{user.email}</h2>

      {user.companyLogoUrl && (
        <div>
          <h3>Logo firmy:</h3>
          <Image
            src={user.companyLogoUrl}
            alt={`Logo firmy ${user.companyName}`}
            width={200}
            height={100}
            style={{ objectFit: 'contain' }}
            placeholder="blur"
            blurDataURL="data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAYEBQYFBAYGBQYHBwYIChAKCgkJChQODwwQFxQYGBcUFhYaHSUfGhsjHBYWICwgIyYnKSopGR8tMC0oMCUoKSj/2wBDAQcHBwoIChMKChMoGhYaKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCj/wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAv/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFQEBAQAAAAAAAAAAAAAAAAAAAAX/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIRAxEAPwCdABmX/9k="
          />
        </div>
      )}
    </div>
  );
}
```

### Next.js Image optimalizace - výhody
```typescript
// Next.js automaticky:
// ✅ Konvertuje do WebP/AVIF (podle support prohlížeče)
// ✅ Generuje responsive velikosti
// ✅ Lazy loading (načte jen viditelné obrázky)
// ✅ Blur placeholder pro lepší UX
// ✅ Optimalizuje velikost podle zařízení

// Konfigurace v next.config.js
/** @type {import('next').NextConfig} */
const nextConfig = {
  images: {
    // Povolené domény pro externí obrázky
    domains: ['your-app-name.railway.app', 'localhost'],

    // Formáty pro optimalizaci
    formats: ['image/webp', 'image/avif'],

    // Velikosti pro responsive images
    deviceSizes: [640, 750, 828, 1080, 1200, 1920, 2048, 3840],

    // Kvalita optimalizace (1-100)
    quality: 85,
  },
}

module.exports = nextConfig
```

### Responsive image příklad
```typescript
// Pro různé velikosti obrazovky
function ResponsiveProductImage({ product }) {
  return (
    <Image
      src={product.imageUrls[0]}
      alt={product.name}
      width={400}
      height={300}
      sizes="(max-width: 768px) 100vw, (max-width: 1200px) 50vw, 33vw"
      style={{ width: '100%', height: 'auto' }}
      priority // Pro above-the-fold obrázky
    />
  );
}
```

---

## 🚀 Produkční tipy

### 1. Caching strategie
```typescript
const client = new ApolloClient({
  link: authLink.concat(httpLink),
  cache: new InMemoryCache({
    typePolicies: {
      Query: {
        fields: {
          products: {
            // Cache na 5 minut
            merge: false,
          }
        }
      }
    }
  }),
  defaultOptions: {
    watchQuery: {
      errorPolicy: 'all',
      fetchPolicy: 'cache-and-network', // Rychlá odezva + aktuální data
    },
  },
});
```

### 2. Lazy loading
```typescript
import { lazy, Suspense } from 'react';

const OrderHistory = lazy(() => import('./OrderHistory'));

function App() {
  return (
    <Suspense fallback={<div>Načítám...</div>}>
      <OrderHistory />
    </Suspense>
  );
}
```

### 3. Monitoring chyb
```typescript
// Sentry integration
import * as Sentry from '@sentry/react';

const client = new ApolloClient({
  link: ApolloLink.from([
    new ApolloLink((operation, forward) => {
      return forward(operation).map((response) => {
        if (response.errors) {
          response.errors.forEach(error => {
            Sentry.captureException(error);
          });
        }
        return response;
      });
    }),
    authLink.concat(httpLink),
  ]),
  cache: new InMemoryCache(),
});
```

---

## 📞 Potřebuješ pomoc?

1. **Zkontroluj network tab** v DevTools
2. **Podívej se do Apollo DevTools**
3. **Zkontroluj konzoli** pro chyby
4. **Testuj query v GraphQL Playground**
5. **Zkontroluj token** v localStorage

### Užitečné příkazy
```bash
# Vygeneruj TypeScript typy
npm run codegen

# Spusti vývojový server
npm run dev

# Zkontroluj GraphQL schema (změň URL na svoji)
curl -X POST -H "Content-Type: application/json" \
  -d '{"query": "{ __schema { types { name } } }"}' \
  https://your-app-name.railway.app/graphql
```

---

## 🌐 Deployment & URLs

### Railway nasazení
```bash
# 1. Zjisti Railway URL po nasazení
# Bude vypadat jako: https://your-app-name.railway.app

# 2. Aktualizuj .env.local
NEXT_PUBLIC_GRAPHQL_URL=https://your-app-name.railway.app/graphql

# 3. Nebo přidat do Vercel environment variables
```

### CORS nastavení
Ujisti se, že backend má správně nastavený CORS pro tvoji frontend doménu:

```ruby
# V Rails config/initializers/cors.rb
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins 'https://your-frontend-domain.vercel.app', 'http://localhost:3000'

    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head]
  end
end
```

### Testování připojení
```javascript
// Rychlý test v browser konzoli
fetch('https://your-app-name.railway.app/graphql', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({
    query: '{ __schema { types { name } } }'
  })
})
.then(res => res.json())
.then(data => console.log('API funguje:', data))
.catch(err => console.error('API nefunguje:', err));
```

**Pamatuj si:** Každý error má svoje řešení. Čti chybové hlášky pozorně a používej debuggovací nástroje! 🔧

---

## 🎨 UI Tipy pro B2B Eshop

### Zásady B2B UI Design
B2B zákazníci mají jiné potřeby než B2C - preferují **funkcionalitu nad estetikou**:

#### 🏢 **Přehlednost nad krásou**
- Méně animací, více informací
- Jasná navigace s breadcrumb
- Konzistentní layout napříč stránkami
- Dobře čitelné fonty (velikost 14px+)

#### ⚡ **Rychlost nad designem**
- Hromadné akce (checkboxy pro vícenásobný výběr)
- Klávesové zkratky (Enter pro rychlé přidání)
- Shortcuts pro zkušené uživatele
- Minimální počet kliků k cíli

#### 📊 **Datová orientace**
- Tabulkové zobrazení s řazením
- Export do Excel/CSV
- Pokročilé filtry a vyhledávání
- Aggregate informace (celková cena, počet)

### Specifické UI prvky pro B2B

#### 🛒 **Quick Order Panel - Shadcn UI**
```tsx
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { useCartStore } from "@/stores/cart-store"

// Rychlé objednávání podle SKU/kódu
function QuickOrderPanel() {
  const [sku, setSku] = useState("")
  const [quantity, setQuantity] = useState(1)
  const addToCart = useCartStore((state) => state.addToCart)

  return (
    <Card>
      <CardHeader>
        <CardTitle>Rychlé objednání</CardTitle>
      </CardHeader>
      <CardContent>
        <div className="flex gap-2">
          <Input
            placeholder="SKU nebo kód produktu"
            value={sku}
            onChange={(e) => setSku(e.target.value)}
            className="flex-1"
          />
          <Input
            type="number"
            placeholder="Množství"
            value={quantity}
            onChange={(e) => setQuantity(Number(e.target.value))}
            className="w-20"
          />
          <Button onClick={() => addToCart(sku, quantity)}>
            Přidat
          </Button>
        </div>
      </CardContent>
    </Card>
  );
}
```

#### 📋 **Bulk Actions Bar - Shadcn UI**
```tsx
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { ShoppingCart, Download, Trash2 } from "lucide-react"

// Pro hromadné operace
function BulkActionsBar({ selectedItems }) {
  return (
    <div className="bg-blue-50 border-l-4 border-blue-500 p-4 rounded-r-md">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <Badge variant="secondary">
            {selectedItems.length} položek vybráno
          </Badge>
        </div>
        <div className="flex gap-2">
          <Button variant="outline" size="sm">
            <ShoppingCart className="w-4 h-4 mr-2" />
            Přidat do košíku
          </Button>
          <Button variant="outline" size="sm">
            <Download className="w-4 h-4 mr-2" />
            Exportovat
          </Button>
          <Button variant="outline" size="sm">
            <Trash2 className="w-4 h-4 mr-2" />
            Odstranit
          </Button>
        </div>
      </div>
    </div>
  );
}
```

#### 🔍 **Advanced Search Panel**
```tsx
// Pokročilé vyhledávání
function AdvancedSearchPanel() {
  return (
    <div className="border rounded-lg p-4 space-y-4">
      <h3>Pokročilé vyhledávání</h3>
      <div className="grid grid-cols-2 gap-4">
        <select className="form-select">
          <option>Všechny kategorie</option>
          <option>Popping Balls</option>
          <option>Syrups</option>
        </select>
        <input placeholder="Název produktu" />
        <input placeholder="SKU" />
        <select className="form-select">
          <option>Všechny ceny</option>
          <option>0-100 Kč</option>
          <option>100-500 Kč</option>
        </select>
      </div>
    </div>
  );
}
```

#### 📦 **Product Bulk Pricing Display - Shadcn UI**
```tsx
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"

// Zobrazení bulk cen
function BulkPricingTable({ product }) {
  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-lg">Objemové slevy</CardTitle>
      </CardHeader>
      <CardContent>
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Množství</TableHead>
              <TableHead>Jednotka</TableHead>
              <TableHead>Cena za kus</TableHead>
              <TableHead>Úspora</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            <TableRow>
              <TableCell>1 ks</TableCell>
              <TableCell>Kus</TableCell>
              <TableCell className="font-medium">25 Kč</TableCell>
              <TableCell>-</TableCell>
            </TableRow>
            <TableRow className="bg-yellow-50/50">
              <TableCell>1 bal (24 ks)</TableCell>
              <TableCell>Balení</TableCell>
              <TableCell className="font-medium">22 Kč</TableCell>
              <TableCell>
                <Badge variant="secondary">12% sleva</Badge>
              </TableCell>
            </TableRow>
            <TableRow className="bg-green-50/50">
              <TableCell>10 bal (240 ks)</TableCell>
              <TableCell>Karton</TableCell>
              <TableCell className="font-medium">19 Kč</TableCell>
              <TableCell>
                <Badge variant="default">24% sleva</Badge>
              </TableCell>
            </TableRow>
          </TableBody>
        </Table>
      </CardContent>
    </Card>
  );
}
```

#### 📊 **Order Summary Sidebar**
```tsx
// Přehledné shrnutí objednávky
function OrderSummarySidebar({ cart }) {
  return (
    <div className="bg-gray-50 p-4 rounded-lg sticky top-4">
      <h3>Shrnutí objednávky</h3>
      <div className="space-y-2 text-sm">
        <div className="flex justify-between">
          <span>Produkty ({cart.itemCount})</span>
          <span>{cart.subtotal} Kč</span>
        </div>
        <div className="flex justify-between">
          <span>DPH (21%)</span>
          <span>{cart.vat} Kč</span>
        </div>
        <div className="flex justify-between font-bold border-t pt-2">
          <span>Celkem</span>
          <span>{cart.total} Kč</span>
        </div>
      </div>
      <button className="w-full bg-green-600 text-white py-3 mt-4 rounded">
        Objednat
      </button>
    </div>
  );
}
```

### UX Best Practices pro B2B

#### 💡 **Keyboard Navigation**
- Tab indexy pro rychlou navigaci
- Enter pro potvrzení
- Escape pro zavření dialogů
- Ctrl+S pro rychlé uložení

#### 📱 **Responsive ale desktop-first**
- Optimalizuj pro desktop (hlavní použití)
- Tablet jako secondary
- Mobile jen pro urgentní situace

#### 🔄 **Loading States**
- Skeleton loading pro tabulky
- Progress bar pro dlouhé operace
- Disable buttons během loading

#### ⚠️ **Error Handling**
- Konkrétní chybové hlášky
- Možnost retry
- Contact info pro technickou podporu

### Tech Stack pro B2B Frontend

#### 🎨 **UI Framework - Shadcn UI**
Shadcn UI je ideální pro B2B - čisté, přístupné, profesionální komponenty.

```bash
# Shadcn UI komponenty pro B2B eshop
npx shadcn-ui@latest add button
npx shadcn-ui@latest add input
npx shadcn-ui@latest add table
npx shadcn-ui@latest add form
npx shadcn-ui@latest add select
npx shadcn-ui@latest add dialog
npx shadcn-ui@latest add badge
npx shadcn-ui@latest add card
npx shadcn-ui@latest add tabs
npx shadcn-ui@latest add dropdown-menu
npx shadcn-ui@latest add checkbox
npx shadcn-ui@latest add toast
```

#### 🗂️ **State Management - Zustand**
```bash
# Zustand pro state management
npm install zustand

# Pro formuláře (kompatibilní se Shadcn)
npm install react-hook-form @hookform/resolvers zod

# Pro data tables
npm install @tanstack/react-table

# Pro export do Excel
npm install xlsx
```

### 🗂️ Zustand Stores pro B2B Eshop

#### 🛒 **Cart Store**
```tsx
// stores/cart-store.ts
import { create } from 'zustand'
import { persist } from 'zustand/middleware'

interface CartItem {
  id: string
  name: string
  price: number
  quantity: number
  unit_type: 'piece' | 'box_1' | 'box_10'
}

interface CartStore {
  items: CartItem[]
  addToCart: (productId: string, quantity: number, unitType?: string) => void
  removeFromCart: (productId: string) => void
  updateQuantity: (productId: string, quantity: number) => void
  clearCart: () => void
  getTotalPrice: () => number
  getTotalItems: () => number
}

export const useCartStore = create<CartStore>()(
  persist(
    (set, get) => ({
      items: [],

      addToCart: (productId, quantity, unitType = 'piece') => {
        set((state) => {
          const existingItem = state.items.find(item =>
            item.id === productId && item.unit_type === unitType
          )

          if (existingItem) {
            return {
              items: state.items.map(item =>
                item.id === productId && item.unit_type === unitType
                  ? { ...item, quantity: item.quantity + quantity }
                  : item
              )
            }
          }

          // Zde by bylo volání API pro získání detailů produktu
          return {
            items: [...state.items, {
              id: productId,
              name: 'Product Name', // z API
              price: 100, // z API podle unitType
              quantity,
              unit_type: unitType as any
            }]
          }
        })
      },

      removeFromCart: (productId) => {
        set((state) => ({
          items: state.items.filter(item => item.id !== productId)
        }))
      },

      updateQuantity: (productId, quantity) => {
        set((state) => ({
          items: state.items.map(item =>
            item.id === productId
              ? { ...item, quantity }
              : item
          )
        }))
      },

      clearCart: () => set({ items: [] }),

      getTotalPrice: () => {
        return get().items.reduce((total, item) =>
          total + (item.price * item.quantity), 0
        )
      },

      getTotalItems: () => {
        return get().items.reduce((total, item) => total + item.quantity, 0)
      }
    }),
    {
      name: 'cart-storage'
    }
  )
)
```

#### 👤 **Auth Store**
```tsx
// stores/auth-store.ts
import { create } from 'zustand'
import { persist } from 'zustand/middleware'

interface User {
  id: string
  email: string
  companyName?: string
  vatId?: string
  role: 'customer' | 'admin'
}

interface AuthStore {
  user: User | null
  token: string | null
  isAuthenticated: boolean
  login: (email: string, password: string) => Promise<void>
  logout: () => void
  setUser: (user: User, token: string) => void
}

export const useAuthStore = create<AuthStore>()(
  persist(
    (set, get) => ({
      user: null,
      token: null,
      isAuthenticated: false,

      login: async (email, password) => {
        // GraphQL mutation zde
        const response = await fetch('/graphql', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            query: `
              mutation LoginUser($email: String!, $password: String!) {
                loginUser(email: $email, password: $password) {
                  user { id email companyName vatId role }
                  token
                  errors
                }
              }
            `,
            variables: { email, password }
          })
        })

        const data = await response.json()

        if (data.data.loginUser.errors.length === 0) {
          const { user, token } = data.data.loginUser

          // Uložíme do store i localStorage
          localStorage.setItem('authToken', token)
          set({
            user,
            token,
            isAuthenticated: true
          })

          return { success: true, errors: [] }
        } else {
          return { success: false, errors: data.data.loginUser.errors }
        }
      },

      logout: () => {
        localStorage.removeItem('authToken')
        client.clearStore() // Vyčistí Apollo cache
        set({
          user: null,
          token: null,
          isAuthenticated: false
        })
      },

      setUser: (user, token) => {
        localStorage.setItem('authToken', token)
        set({ user, token, isAuthenticated: true })
      }
    }),
    {
      name: 'auth-storage'
    }
  )
)
```

#### 🔄 **UI State Store**
```tsx
// stores/ui-store.ts
import { create } from 'zustand'

interface UIStore {
  isLoading: boolean
  selectedProducts: string[]
  searchQuery: string
  filters: {
    category?: string
    priceRange?: [number, number]
    inStock?: boolean
  }
  setLoading: (loading: boolean) => void
  toggleProductSelection: (productId: string) => void
  clearSelection: () => void
  setSearchQuery: (query: string) => void
  setFilters: (filters: Partial<UIStore['filters']>) => void
}

export const useUIStore = create<UIStore>((set) => ({
  isLoading: false,
  selectedProducts: [],
  searchQuery: '',
  filters: {},

  setLoading: (loading) => set({ isLoading: loading }),

  toggleProductSelection: (productId) => {
    set((state) => ({
      selectedProducts: state.selectedProducts.includes(productId)
        ? state.selectedProducts.filter(id => id !== productId)
        : [...state.selectedProducts, productId]
    }))
  },

  clearSelection: () => set({ selectedProducts: [] }),

  setSearchQuery: (query) => set({ searchQuery: query }),

  setFilters: (newFilters) => {
    set((state) => ({
      filters: { ...state.filters, ...newFilters }
    }))
  }
}))
```

#### 🔥 **Použití v komponentách**
```tsx
// components/ProductList.tsx
import { useCartStore } from '@/stores/cart-store'
import { useUIStore } from '@/stores/ui-store'
import { Button } from '@/components/ui/button'
import { Checkbox } from '@/components/ui/checkbox'

function ProductList({ products }) {
  const addToCart = useCartStore((state) => state.addToCart)
  const { selectedProducts, toggleProductSelection } = useUIStore()

  return (
    <div className="space-y-4">
      {products.map((product) => (
        <div key={product.id} className="flex items-center gap-4 p-4 border rounded">
          <Checkbox
            checked={selectedProducts.includes(product.id)}
            onCheckedChange={() => toggleProductSelection(product.id)}
          />
          <div className="flex-1">
            <h3>{product.name}</h3>
            <p className="text-sm text-gray-600">{product.description}</p>
          </div>
          <div className="text-right">
            <p className="font-bold">{product.price} Kč</p>
            <Button onClick={() => addToCart(product.id, 1)}>
              Přidat do košíku
            </Button>
          </div>
        </div>
      ))}
    </div>
  )
}
```

**Pamatuj si:** B2B uživatelé chtějí být efektivní, ne pobaveni. Prioritizuj funkcionalitu! 🚀