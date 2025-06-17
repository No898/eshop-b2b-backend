
# 🚀 Lootea B2B Backend – Plán vývoje

Tento dokument definuje plán vývoje backendu pro projekt **Lootea B2B**, postavený na Ruby on Rails (API-only) + GraphQL + Devise JWT.

📝 **Poznámka:**
Vše budu psát **sám** s podporou AI, abych se vše naučil a pochopil do hloubky.

---

## ✅ Dosud hotovo

### 🏗️ **Základní infrastruktura**
- Rails API-only projekt založen a nakonfigurován
- PostgreSQL napojeno s multi-database architekturou (main, cache, queue, cable)
- GraphQL kompletně nainstalováno a nakonfigurováno
- Git repo s proper .gitignore a strukturou

### 🔐 **Autentizace & Autorizace**
- **Devise + JWT** kompletně nakonfigurované (proper security, reconfirmable, password policies)
- **Pundit** pro authorization framework
- **JwtService** pro centralizovaný token management
- **Parameter filtering** (hesla, tokeny, SSN, CVV, citlivé údaje)

### 📊 **Data & Business logika**
- **Modely + migrace** (User, Product, Order, OrderItem s validacemi a enums)
- **GraphQL schema** (všechny typy, queries, mutations)
- **Login/Register flow** (s proper error handling)
- **Produkty & objednávky** (CRUD operace)
- **Platby** (Comgate integrace, payOrder mutace, webhook zpracování s HMAC ověřením)

### 🛡️ **Bezpečnost & Performance**
- **Pokročilé GraphQL zabezpečení** (introspection blocking, query complexity/depth limits)
- **Pokročilé rate limiting** (Rack::Attack s SQL injection/XSS ochranou, GraphQL-specific limits)
- **CORS kompletně nakonfigurované** pro frontend integraci
- **SSL & Security headers** pro produkci
- **Configurable security framework** (environment-based limits přes ENV)

### ⚙️ **Background Jobs & Cache**
- **Sidekiq** pro background job processing
- **Solid Queue** (Rails 8 moderní queue systém)
- **Solid Cache** (Rails 8 moderní cache systém)
- **Redis** pro rate limiting a cable connections
- **ActionJob** pro webhook processing

### 🔧 **DevOps & Monitoring**
- **Kompletní CI/CD pipeline** (GitHub Actions s testováním, linting, security scan, dependabot)
- **Deploy na Railway** (automatický z main branch)
- **Health check endpoints** (`/up` s optimalizacemi pro load balancery)
- **Structured logging** (JSON format, GraphQL query tracking, security events)
- **Production-ready konfigurace** (log levels, SSL, error handling)

### 📝 **Kód qualita & Dokumentace**
- **Code quality tools** (RuboCop, Brakeman, Lefthook)
- **Modularizace kódu** (GraphQL concerns pro lepší organizaci)
- **Kompletní dokumentace** (GRAPHQL_SECURITY.md, FRONTEND_API_GUIDE.md s Railway konfigurací)

---

## 🚀 Co můžeme ještě udělat

### 🧪 **1️⃣ Testování** (RSpec setup hotov, chybí konkrétní testy)
- **Model testy** (validace, asociace, metody, edge cases)
- **GraphQL testy** (mutations, queries, error handling)
- **Controller testy** (webhooks, autentizace, security)
- **Integration testy** (celé user flow: registrace → objednávka → platba)
- **Security testy** (rate limiting, introspection blocking, CORS)
- **Performance testy** (load testing, memory usage)

### 📊 **2️⃣ Application Monitoring** (Logging už máme skvělé)
- **APM systém** (New Relic, Datadog, nebo Skylight pro Rails)
- **Error tracking** (Sentry, Rollbar, nebo Bugsnag)
- **Metrics dashboard** (vlastní nebo přes APM)
- **Alerting** (při chybách, high load, down service)

### ⚡ **3️⃣ Performance Optimalizace**
- **Database indexy** (na často dotazované sloupce)
- **Query optimization** (N+1 problém, batch loading)
- **Connection pooling** (optimalizace pro vysoký traffic)
- **Background job monitoring** (Sidekiq Web UI, metriky)
- **Redis optimalizace** (memory usage, persistence)

### 🎯 **4️⃣ API Pokročilé funkce**
- **API versioning** (GraphQL schema versioning)
- **GraphQL subscriptions** (real-time updates přes WebSocket)
- **File upload handling** (ActiveStorage s cloud storage)
- **Bulk operations** (hromadné vytváření/úpravy záznamů)
- **Advanced filtering & sorting** (komplexní vyhledávání)
- **GraphQL Playground** (interaktivní API dokumentace)

### 🌐 **5️⃣ Frontend Integrace** (CORS už máme)
- **GraphQL schema export** (automatické generování pro frontend)
- **API response caching** (Redis cache pro často dotazovaná data)
- **Real-time notifications** (WebSocket/Cable pro live updates)
- **API rate limiting per user** (individuální limity)

### 💼 **6️⃣ Business Features**
- **Email systém** (ActionMailer templates, transactional emails)
- **Admin panel** (administrace uživatelů, objednávek, produktů)
- **Inventory management** (správa skladových zásob)
- **Discount/coupon systém** (slevové kódy, akce)
- **Reporting & Analytics** (dashboardy, exporty, statistiky)
- **Multi-tenant support** (pokud bude potřeba více klientů)

---

## 🌟 Cíle a Status

### ✅ **Dosažené cíle**
- **Naučit se psát vše ručně** - bez generovaných boilerplate repozitářů
- **Čistý, bezpečný, moderní stack** - Rails 8 + GraphQL + JWT + Sidekiq
- **Production-ready API** - které frontend (Next.js) pohodlně konzumuje
- **Robustní CI/CD pipeline** - GitHub Actions s automatickým testováním a deploy
- **Pokročilé security & rate limiting** - Rack::Attack + GraphQL security
- **Background job infrastruktura** - Sidekiq + Solid Queue pro Rails 8
- **Multi-database architektura** - oddělené DB pro cache, queue, cable

### 🔄 **Aktuální priority**
- **Kompletní test coverage** - RSpec setup hotov, chybí konkrétní testy
- **Production monitoring** - APM systém a error tracking
- **Performance optimalizace** - database indexy a query optimization
- **Email systém** - ActionMailer templates pro transactional emails

### 🎯 **Dlouhodobé cíle**
- **Advanced API features** - subscriptions, bulk operations, versioning
- **Business features** - admin panel, inventory, discount systém
- **Analytics & reporting** - dashboardy a business intelligence

---

## 📌 Pravidlo
👉 Každý krok řeším v samostatném chatu, aby byl přehledný a strukturovaný.