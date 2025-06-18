# 🔗 GraphQL API Reference

Kompletní dokumentace GraphQL API pro Lootea B2B Backend. Tato příručka obsahuje všechny dostupné queries, mutations a types s praktickými příklady.

## 📋 Obsah
- [🚀 Quick Start](#-quick-start)
- [🔐 Autentizace](#-autentizace)
- [📊 Queries](#-queries)
- [✏️ Mutations](#-mutations)
- [🏷️ Types](#-types)
- [💳 Payment Integration](#-payment-integration)
- [🧪 Testing](#-testing)

---

## 🚀 Quick Start

### GraphQL Endpoint
- **Development:** `http://localhost:3000/graphql`
- **GraphiQL Playground:** `http://localhost:3000/graphiql`
- **Production:** `https://your-app.railway.app/graphql`

### Základní request
```bash
curl -X POST http://localhost:3000/graphql \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "query": "{ products { id name priceDecimal } }"
  }'
```

---

## 🔐 Autentizace

### JWT Token v Headers
```javascript
// Všechny authenticated requests musí obsahovat:
{
  "Authorization": "Bearer eyJhbGciOiJIUzI1NiJ9..."
}
```

### Login Mutation
```graphql
mutation LoginUser {
  loginUser(
    email: "user@example.com"
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
```

---

## 📊 Queries

### Products
```graphql
# Seznam všech produktů
query GetProducts {
  products {
    id
    name
    description
    priceDecimal
    priceCents
    currency
    available
    hasImages
    imageUrls
    inStock
    quantity

    # Bulk pricing
    hasBulkPricing
    priceTiers {
      tierName
      minQuantity
      maxQuantity
      priceDecimal
    }

    # Variants
    isVariantParent
    hasVariants
    variants {
      id
      name
      variantDisplayName
      priceDecimal
    }
  }
}

# Jeden produkt
query GetProduct($id: ID!) {
  product(id: $id) {
    id
    name
    description
    priceDecimal
    # ... všechna pole jako výše
  }
}
```

### Orders
```graphql
# Moje objednávky
query MyOrders {
  myOrders {
    id
    totalDecimal
    currency
    status
    paymentStatus
    createdAt

    orderItems {
      id
      quantity
      unitPriceDecimal
      totalDecimal

      product {
        id
        name
        imageUrls
      }
    }
  }
}

# Jedna objednávka
query GetOrder($id: ID!) {
  order(id: $id) {
    id
    totalDecimal
    status
    paymentStatus
    # ... všechna pole
  }
}
```

### User Info
```graphql
# Aktuální uživatel
query CurrentUser {
  currentUser {
    id
    email
    role
    companyName
    vatId
    avatarUrl
    companyLogoUrl

    # Adresy
    addresses {
      id
      addressType
      companyName
      street
      city
      postalCode
      country
      isDefault
    }
  }
}
```

---

## ✏️ Mutations

### User Management
```graphql
# Registrace
mutation RegisterUser {
  registerUser(
    email: "user@example.com"
    password: "password123"
    passwordConfirmation: "password123"
    companyName: "Firma s.r.o."
    vatId: "CZ12345678"
  ) {
    user {
      id
      email
      companyName
    }
    token
    errors
  }
}

# Login
mutation LoginUser {
  loginUser(
    email: "user@example.com"
    password: "password123"
  ) {
    user { id email role }
    token
    errors
  }
}
```

### Order Management
```graphql
# Vytvoření objednávky
mutation CreateOrder {
  createOrder(
    items: [
      { productId: "1", quantity: 2 },
      { productId: "3", quantity: 1 }
    ]
    currency: "CZK"
  ) {
    order {
      id
      totalDecimal
      status

      orderItems {
        quantity
        unitPriceDecimal
        product { name }
      }
    }
    errors
  }
}

# Platba objednávky
mutation PayOrder {
  payOrder(orderId: "123") {
    paymentUrl
    success
    errors
  }
}
```

### File Uploads
```graphql
# Upload product images (admin only)
mutation UploadProductImages($productId: ID!, $images: [Upload!]!) {
  uploadProductImages(productId: $productId, images: $images) {
    product {
      id
      imageUrls
      hasImages
    }
    success
    errors
  }
}

# Upload user avatar
mutation UploadUserAvatar($avatar: Upload!) {
  uploadUserAvatar(avatar: $avatar) {
    user {
      id
      avatarUrl
    }
    success
    errors
  }
}
```

---

## 🏷️ Types

### ProductType
```graphql
type Product {
  id: ID!
  name: String!
  description: String
  priceDecimal: Float!
  priceCents: Int!
  currency: String!
  available: Boolean!

  # Images
  hasImages: Boolean!
  imageUrls: [String!]!

  # Inventory
  inStock: Boolean!
  quantity: Int!

  # Bulk Pricing
  hasBulkPricing: Boolean!
  priceTiers: [ProductPriceTierType!]!
  priceForQuantity(quantity: Int!): Float!

  # Variants
  isVariantParent: Boolean!
  hasVariants: Boolean!
  variants: [Product!]!
  variantDisplayName: String!
}
```

### OrderType
```graphql
type Order {
  id: ID!
  totalDecimal: Float!
  totalCents: Int!
  currency: String!
  status: String!
  paymentStatus: String!
  createdAt: String!

  # Computed fields
  isPending: Boolean!
  isPaid: Boolean!
  itemsCount: Int!

  # Relations
  user: User!
  orderItems: [OrderItem!]!
}
```

### UserType
```graphql
type User {
  id: ID!
  email: String!
  role: String!
  companyName: String
  vatId: String

  # Files
  avatarUrl: String
  companyLogoUrl: String

  # Relations
  orders: [Order!]!
  addresses: [Address!]!
}
```

---

## 💳 Payment Integration

### Comgate Flow
1. **Vytvoř objednávku:** `createOrder` mutation
2. **Inicializuj platbu:** `payOrder` mutation → vrátí `paymentUrl`
3. **Redirect uživatele** na `paymentUrl`
4. **Webhook zpracování:** Comgate pošle výsledek na `/webhooks/comgate`
5. **Poll order status:** Frontend kontroluje `order.paymentStatus`

### Payment Status Values
```graphql
enum PaymentStatus {
  PENDING    # Čeká na platbu
  PAID       # Zaplaceno
  CANCELLED  # Zrušeno
  FAILED     # Neúspěšné
}
```

---

## 🧪 Testing

### GraphiQL Playground
```graphql
# Test basic query
{
  products {
    id
    name
    priceDecimal
  }
}

# Test with variables
query GetProduct($id: ID!) {
  product(id: $id) {
    name
    priceDecimal
  }
}

# Variables:
{
  "id": "1"
}
```

### cURL Examples
```bash
# Basic query
curl -X POST http://localhost:3000/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "{ products { id name } }"}'

# Authenticated query
curl -X POST http://localhost:3000/graphql \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"query": "{ currentUser { email } }"}'

# Mutation with variables
curl -X POST http://localhost:3000/graphql \
  -H "Content-Type: application/json" \
  -d '{
    "query": "mutation($email: String!, $password: String!) { loginUser(email: $email, password: $password) { token errors } }",
    "variables": {"email": "user@example.com", "password": "password123"}
  }'
```

---

## 🔗 Related Documentation
- **[Authentication Guide](../components/auth.md)** - Frontend JWT setup
- **[Error Handling](../components/errors.md)** - Error handling patterns
- **[Security Guide](./security.md)** - GraphQL security best practices

---

*Dokumentace aktualizována: 18.6.2025*