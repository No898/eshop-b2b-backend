# 🎯 Frontend API Průvodce - Jednoduchý návod pro začátečníky

Kompletní návod jak používat naše GraphQL API ve frontend aplikaci. Každý příklad je ready-to-use!

---

## 📋 Obsah
- [🚀 Quick Start](#-quick-start)
- [🔐 Autentizace](#-autentizace)
- [📊 Získávání dat (Queries)](#-získávání-dat-queries)
- [✏️ Změny dat (Mutations)](#️-změny-dat-mutations)
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
- Backend je nasazený na Railway/Heroku
- Frontend je nasazený na Vercel/Netlify

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

### Registrace nového uživatele
```typescript
// mutations/auth.ts
import { gql } from '@apollo/client';

const REGISTER_USER = gql`
  mutation RegisterUser($email: String!, $password: String!, $companyName: String) {
    registerUser(input: {
      email: $email
      password: $password
      companyName: $companyName
    }) {
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
          companyName: formData.companyName
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

### Přihlášení
```typescript
const LOGIN_USER = gql`
  mutation LoginUser($email: String!, $password: String!) {
    loginUser(input: {
      email: $email
      password: $password
    }) {
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
`;

// Jednoduchá login komponenta
function LoginForm() {
  const [loginUser, { loading }] = useMutation(LOGIN_USER);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');

  const handleLogin = async (e) => {
    e.preventDefault();

    try {
      const { data } = await loginUser({
        variables: { email, password }
      });

      if (data.loginUser.errors.length === 0) {
        // Uložíme token
        localStorage.setItem('authToken', data.loginUser.token);
        window.location.href = '/dashboard';
      } else {
        alert('Chyba: ' + data.loginUser.errors.join(', '));
      }
    } catch (err) {
      alert('Chyba při přihlašování');
    }
  };

  return (
    <form onSubmit={handleLogin}>
      <input
        type="email"
        value={email}
        onChange={(e) => setEmail(e.target.value)}
        placeholder="Email"
        required
      />
      <input
        type="password"
        value={password}
        onChange={(e) => setPassword(e.target.value)}
        placeholder="Heslo"
        required
      />
      <button type="submit" disabled={loading}>
        {loading ? 'Přihlašujeme...' : 'Přihlásit'}
      </button>
    </form>
  );
}
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
    createOrder(input: {
      items: $items
    }) {
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
    payOrder(input: {
      orderId: $orderId
    }) {
      payment {
        id
        status
        paymentUrl
      }
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

      if (data.payOrder.errors.length === 0) {
        // Přesměrujeme na platební bránu
        window.location.href = data.payOrder.payment.paymentUrl;
      } else {
        // Zobrazíme lokalizovanou chybu
        const errorMessage = data.payOrder.errors
          .map(error => getErrorMessage(error))
          .join(', ');
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

const handlePaymentError = (errors: string[]) => {
  errors.forEach(errorCode => {
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
  });
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

# 3. Nebo přidat do Vercel/Netlify environment variables
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