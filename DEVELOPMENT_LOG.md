# 📋 Lootea B2B Backend - Development Log

Kompletní dokumentace vývoje backendu pro **Lootea B2B** projekt.

## 🚀 Přehled projektu

**Lootea B2B Backend** je REST API + GraphQL server postavený na Ruby on Rails (API-only) pro e-commerce platformu zaměřenou na B2B prodej čajů.

### 🎯 Cíle projektu
- Naučit se psát vše ručně, bez generovaných boilerplate repozitářů
- Mít čistý, bezpečný, moderní stack
- Postavit API, které frontend (Next.js) pohodlně konzumuje

---

## 🛠 Tech Stack

### Backend
- **Ruby on Rails 8.0.2** (API-only mode)
- **PostgreSQL 14** (v Docker)
- **GraphQL** (hlavní API)
- **Devise + JWT** (autentizace)
- **Pundit** (autorizace)
- **Sidekiq** (background jobs)

### Development Tools
- **RuboCop** (kód formátování + linting)
- **RSpec** (testing framework - připravený)
- **Brakeman** (security scanner - optimalizovaný)
- **Lefthook** (Git hooks)

### Infrastructure
- **Docker** (PostgreSQL databáze)
- **Railway** (plánovaný hosting)
- **GitHub Actions** (plánované CI/CD)

---

## 📁 Struktura projektu

```
lootea-b2b-backend/
├── app/
│   ├── models/
│   │   ├── user.rb              # Devise User model
│   │   ├── product.rb           # Produkty
│   │   ├── order.rb             # Objednávky
│   │   └── order_item.rb        # Položky objednávek
│   ├── graphql/                 # GraphQL schema
│   └── controllers/             # API controllers
├── db/
│   └── migrate/                 # Databázové migrace
├── config/
│   ├── database.yml             # DB konfigurace
│   └── brakeman.yml             # Brakeman security config
├── spec/                        # RSpec testy (připravené)
├── docker-compose.yml           # PostgreSQL v Docker
├── lefthook.yml                 # Git hooks konfigurace
├── .rubocop.yml                 # RuboCop linting pravidla
└── lootea_b2b_backend_plan.md   # Původní plán
```

---

## 🗄 Databázové modely

### 👤 User Model (Devise)
```ruby
# Atributy:
- email (string, unique)
- encrypted_password (string)
- role (integer, enum)
- company_name (string)
- vat_id (string)

# Associations:
has_many :orders, dependent: :destroy

# Autentizace:
- devise :database_authenticatable, :registerable
- devise :jwt_authenticatable
```

### 🫖 Product Model
```ruby
# Atributy:
- name (string, required, 2-100 znaků)
- description (text, optional)
- price_cents (integer, required, > 0)
- currency (string, default: "CZK", pouze CZK/EUR)
- available (boolean, default: true)

# Associations:
has_many :order_items, dependent: :restrict_with_error

# Scopes:
scope :available, -> { where(available: true) }

# Helper metody:
def price_decimal
  price_cents / 100.0
end
```

### 📦 Order Model
```ruby
# Atributy:
- user_id (foreign_key, required)
- total_cents (integer, required, > 0)
- currency (string, default: "CZK", pouze CZK/EUR)
- status (integer, enum, default: 0)

# Associations:
belongs_to :user
has_many :order_items, dependent: :destroy

# Status enum:
enum :status, {
  pending: 0,     # Čeká na platbu
  paid: 1,        # Zaplaceno
  shipped: 2,     # Odesláno
  delivered: 3,   # Doručeno
  cancelled: 4    # Zrušeno
}

# Helper metody:
def total_decimal
  total_cents / 100.0
end
```

### 🛍 OrderItem Model
```ruby
# Atributy:
- order_id (foreign_key, required)
- product_id (foreign_key, required)
- quantity (integer, required, > 0)
- unit_price_cents (integer, required, > 0)

# Associations:
belongs_to :order
belongs_to :product

# Unique constraint:
# Jeden produkt může být v objednávce pouze jednou

# Helper metody:
def unit_price_decimal
  unit_price_cents / 100.0
end

def total_cents
  quantity * unit_price_cents
end

def total_decimal
  total_cents / 100.0
end
```

---

## 🏗 Nastavení prostředí

### Požadavky
- Ruby 3.3.0
- Rails 8.0.2
- Docker Desktop
- PostgreSQL (v Docker)

### Spuštění projektu

#### 1. Klonování a závislosti
```bash
git clone <repo>
cd lootea-b2b-backend
bundle install
```

#### 2. Databáze (PostgreSQL v Docker)
```bash
# Spusť PostgreSQL container
docker-compose up -d postgres

# Vytvoř databázi
export DATABASE_URL="postgresql://postgres:password@localhost:5432/lootea_b2b_backend_development"
rails db:create
rails db:migrate
```

#### 3. Spuštění serveru
```bash
rails server
```

#### 4. GraphQL endpoint
- **URL:** `http://localhost:3000/graphql`
- **GraphiQL:** `http://localhost:3000/graphiql` (development)

---

## 📊 Databázová struktura

### Migrace (v pořadí)
1. **20250615105856** - `devise_create_users`
2. **20250615105948** - `add_role_company_vat_id_to_users`
3. **20250615123105** - `create_products`
4. **20250615133538** - `create_orders`
5. **20250615134826** - `create_order_items`

### Indexy pro optimalizaci
```sql
-- Products
CREATE INDEX index_products_on_available ON products (available);

-- Orders
CREATE INDEX index_orders_on_status ON orders (status);
CREATE INDEX index_orders_on_user_id_and_created_at ON orders (user_id, created_at);

-- OrderItems
CREATE UNIQUE INDEX index_order_items_on_order_id_and_product_id ON order_items (order_id, product_id);
```

---

## 🔌 GraphQL API příklady

### Základní queries
```graphql
# Seznam všech produktů
query GetProducts {
  products {
    id
    name
    description
    priceCents
    priceDecimal
    currency
    available
  }
}

# Jeden produkt podle ID
query GetProduct($id: ID!) {
  product(id: $id) {
    id
    name
    description
    priceDecimal
    currency
  }
}

# Aktuální uživatel (pokud je přihlášen)
query CurrentUser {
  currentUser {
    id
    email
    role
    companyName
    vatId
  }
}

# Moje objednávky
query MyOrders {
  myOrders {
    id
    totalDecimal
    currency
    status
    isPending
    isPaid
    itemsCount
    createdAt
    orderItems {
      id
      quantity
      unitPriceDecimal
      totalDecimal
      product {
        name
      }
    }
  }
}
```

### Autentizace mutations
```graphql
# Registrace nového uživatele
mutation RegisterUser {
  registerUser(
    email: "tomas@example.com"
    password: "password123"
    passwordConfirmation: "password123"
    companyName: "Lootea s.r.o."
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

# Přihlášení
mutation LoginUser {
  loginUser(
    email: "tomas@example.com"
    password: "password123"
  ) {
    user {
      id
      email
      role
    }
    token
    errors
  }
}
```

### Order management
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
      currency
      status
      orderItems {
        quantity
        totalDecimal
        product {
          name
        }
      }
    }
    errors
  }
}
```

### Autentizace headers
```
Authorization: Bearer <jwt_token_zde>
Content-Type: application/json
```

---

## 🧪 Testování v Rails konzoli

### Vytvoření testovacích dat
```ruby
# Uživatel
user = User.create!(email: "test@example.com", password: "password123")

# Produkt
product = Product.create!(
  name: "Lootea Premium",
  description: "Nejlepší čaj na světě",
  price_cents: 29900,
  currency: "CZK"
)

# Objednávka
order = Order.create!(
  user: user,
  total_cents: 59900,
  currency: "CZK"
)

# Položka objednávky
order_item = OrderItem.create!(
  order: order,
  product: product,
  quantity: 2,
  unit_price_cents: product.price_cents
)
```

### Testování funkcionalit
```ruby
# Product
product.available?          # => true
product.price_decimal       # => 299.0
Product.available.count     # => 1

# Order
order.pending?              # => true
order.paid!                 # změní status
order.total_decimal         # => 599.0
user.orders.count          # => 1

# OrderItem
order_item.total_decimal    # => 598.0
order.order_items.count    # => 1
product.order_items.count  # => 1
```

---

## ✅ Hotové části (Kroky 1-2/5)

### 1️⃣ Modely + migrace ✅
- ✅ Product model (name, description, price_cents, currency, available)
- ✅ Order model (user, total_cents, currency, status enum)
- ✅ OrderItem model (order, product, quantity, unit_price_cents)
- ✅ Všechny associations správně propojené
- ✅ Validace a constraints
- ✅ Optimalizační indexy

### 2️⃣ GraphQL typy + queries + mutace ✅
- ✅ ProductType s cenami v centech i decimálních
- ✅ UserType s bezpečnými fieldy (bez hesla)
- ✅ OrderType s computed fields (items_count, is_paid)
- ✅ OrderItemType s kalkulacemi (total_cents, total_decimal)
- ✅ Query: products, product(id), current_user, my_orders
- ✅ Mutation: login_user (email, password → user, token)
- ✅ Mutation: register_user (plná registrace → okamžité přihlášení)
- ✅ Mutation: create_order (items[] → order s transaction safety)
- ✅ JWT autentizace v GraphQL kontextu
- ✅ Authorization header parsing ("Bearer <token>")

### Development tooling ✅
- ✅ RuboCop konfigurace + autofix
- ✅ RSpec setup (připravený k použití)
- ✅ Brakeman security scanner optimalizace
- ✅ Lefthook Git hooks (pre-commit, pre-push)
- ✅ Performance optimalizace pro rychlý vývoj

---

## 🚧 Plánované kroky

### 3️⃣ Platby
- [ ] Service objekt pro Comgate integraci
- [ ] Mutation `payOrder` → vrací URL pro redirect
- [ ] Webhook route pro Comgate callback → job zpracuje výsledek

### 4️⃣ Background joby
- [ ] ActiveJob na webhook zpracování
- [ ] Příprava na mailing (např. potvrzení objednávky)

### 5️⃣ CI/CD + hosting
- [ ] Deploy na Railway
- [ ] GitHub Actions pipeline
- [ ] Env proměnné pro JWT, DB apod.

---

## 🎓 Získané znalosti

### Rails 8 specifika
- **Nová enum syntaxe:** `enum :status, { pending: 0 }`
- **API-only mode** - čistá separace backend/frontend
- **Modern Rails practices**

### Databázový design
- **Ceny v centech** - přesnost bez float problémů
- **Foreign keys a constraints** - data integrity
- **Indexy pro optimalizaci** - rychlé dotazy
- **Audit trail** - unit_price_cents pamatuje historické ceny

### Docker integrace
- **PostgreSQL v Docker** - eliminace lokálních problémů
- **docker-compose.yml** pro snadné spouštění
- **Environment variables** pro konfiguraci

### API design principles
- **Backend = data, Frontend = formátování**
- **Raw data přes API** (price_cents, currency)
- **Rozšiřitelnost** pro budoucí změny

### GraphQL + JWT architektura
- **Schema-first development** - typy jako smlouva s frontendem
- **Resolver patterns** - business logika oddělená od typu definice
- **Context-based autentizace** - JWT token v request headers
- **Helper fields** - price_decimal pro UX, zatímco price_cents pro přesnost
- **Computed fields** - items_count, is_paid dynamicky kalkulované
- **Transaction safety** - CreateOrder s rollback při chybě
- **Input validation** - validace na úrovni GraphQL i modelu
- **Error handling** - strukturované error messages

### JWT best practices
- **Bearer token format** - standardní Authorization header
- **Payload minimalism** - jen user ID, žádná citlivá data
- **Rails integration** - Devise JWT + custom controller parsing
- **Security considerations** - token expiry, algoritmus HS256

---

## 🔧 Užitečné příkazy

### Docker
```bash
# Spuštění PostgreSQL
docker-compose up -d postgres

# Zastavení
docker-compose down

# Připojení k DB
docker exec -it lootea_postgres psql -U postgres -d lootea_b2b_backend_development
```

### Rails
```bash
# Migrace
rails db:migrate

# Konzole
rails console

# Server
rails server

# GraphiQL
open http://localhost:3000/graphiql
```

### Debugging
```bash
# Restart při změnách modelů
spring stop
rails console

# Kontrola routes
rails routes | grep graphql
```

### Development nástroje
```bash
# RuboCop kontrola
bundle exec rubocop

# RuboCop autofix
bundle exec rubocop -a

# Brakeman security scan (rychlý)
bundle exec brakeman --config-file config/brakeman.yml

# RSpec testy (až budou hotové)
bundle exec rspec
```

### Git hooks (Lefthook)
```bash
# Pre-commit: RuboCop + trailing whitespace cleanup
git commit -m "tvoje zpráva"

# Pre-push: Brakeman security scan (vypnutý pro rychlý vývoj)
git push origin main
```

---

## ⚡ Performance optimalizace

### Brakeman rychlost
- **Problém:** Původně trval 5+ minut na malém projektu
- **Řešení:** Vlastní config v `config/brakeman.yml`
- **Výsledek:** 0.1 sekundy místo 5 minut
- **Pro vývoj:** Dočasně vypnutý v lefthook
- **Zapnutí zpět:** Odkomentovat v `lefthook.yml` až bude více kódu

### Development tipy
- **Docker PostgreSQL:** Rychlejší než lokální instalace
- **Spring preloader:** Automatické accelerace Rails příkazů
- **GraphiQL:** Rychlé testování queries bez Postman
- **Rails console:** Okamžité testování business logiky

---

## 📞 Kontakt a poznámky

**Datum vytvoření:** 15. června 2025
**Autor:** Tomáš (s AI mentorem)
**Stav:** Dokončen krok 2/5 - GraphQL API + Development tooling
**Další krok:** Platby (Comgate integrace)

**Poznámka:** Všechny kroky se dělají postupně pro lepší pochopení a učení se Rails best practices. Development prostředí je optimalizované pro rychlý vývoj.