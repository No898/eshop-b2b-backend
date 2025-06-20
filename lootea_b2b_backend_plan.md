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
- **File upload systém** (Active Storage + GraphQL Upload Type s validacemi)
- **Image handling** (produktové obrázky, avatary, firemní loga s různými validacemi)
- **Inventory Management** (quantity tracking, low stock alerts, thread-safe stock operations)
- **Product Specifications** (weight/volume, ingredients, liquid/solid classification)
- **Address Management** (billing/shipping adresy, české B2B specifika - IČO/DIČ/PSČ validace)
- **Bulk Pricing System** (množstevní slevy 1ks/1bal/10bal, dynamické ceny podle množství)
- **Product Variants System** (varianty produktů s atributy - příchuť, velikost, barva)

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
- **Kompletní dokumentace** (GRAPHQL_SECURITY.md, FRONTEND_GUIDE.md, ADDRESS_SYSTEM.md, INVENTORY_SYSTEM.md, BULK_PRICING_SYSTEM.md, PRODUCT_VARIANTS_SYSTEM.md)

---

## 🚀 Co můžeme ještě udělat

### 🎯 **PRIORITY 1 - Základní B2B funkce**
- ✅ **Inventory management** - HOTOVO (quantity tracking, stock reservations, low stock alerts)
- ✅ **Product specifications** - HOTOVO (weight/volume, ingredients pro sirupy/nádoby)
- ✅ **Address Management** - HOTOVO (billing/shipping adresy, české IČO/DIČ/PSČ validace)
- ✅ **Bulk Pricing System** - HOTOVO (množstevní slevy 1ks/1bal/10bal, real-time pricing)
- ✅ **Product Variants System** - HOTOVO (varianty s příchutěmi/velikostmi, automatic SKU generation)

### 🧪 **PRIORITY 2 - Testování** (RSpec setup hotov, chybí konkrétní testy)
- **Model testy** (validace, asociace, metody, edge cases)
- **GraphQL testy** (mutations, queries, error handling)
- **Controller testy** (webhooks, autentizace, security)
- **Integration testy** (celé user flow: registrace → objednávka → platba)
- **Security testy** (rate limiting, introspection blocking, CORS)

### 📊 **PRIORITY 3 - Monitoring & Performance**
- **APM systém** (New Relic, Datadog, nebo Skylight pro Rails)
- **Error tracking** (Sentry, Rollbar, nebo Bugsnag)
- **Database indexy** (na často dotazované sloupce)
- **Query optimization** (N+1 problém, batch loading)
- **Background job monitoring** (Sidekiq Web UI, metriky)

### 🎯 **BUDOUCÍ PLÁN - Pokročilé funkce**
- **Email systém** (ActionMailer templates, transactional emails)
- **Admin panel** (administrace uživatelů, objednávek, produktů)
- **GraphQL subscriptions** (real-time updates)
- **Advanced filtering & sorting** (komplexní vyhledávání)
- **Bulk operations** (hromadné vytváření/úpravy záznamů)

### 📈 **POZDĚJI - Analytics & Business Intelligence**
- **Reporting & Analytics** (dashboardy, exporty, statistiky)
- **Zákaznická segmentace** (VIP, bulk buyers, atd.)
- **Prodejní reporty** (top produkty, trendy, předpovědi)
- **Business metrics** (conversion rates, AOV, retention)

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

### 🔄 **Aktuální priority (PRIORITY 2)**
- **Testování** - RSpec testy pro modely, GraphQL, controllers a integration

### ✅ **Nedávno dokončeno**
- **Product Variants System** - varianty produktů s atributy, automatic SKU, GraphQL API
- **Bulk Pricing System** - množstevní slevy s real-time pricing a GraphQL integrací
- **Address Management** - fakturační/doručovací adresy s českými B2B specifiky (IČO/DIČ/PSČ)
- **Inventory management** - kompletní skladové hospodářství s thread-safe operacemi
- **Product specifications** - hmotnost/objem (kg/g/l/ml) a složení pro produkty

### 🎯 **Střednědobé cíle**
- **Test coverage** - RSpec setup hotov, chybí konkrétní testy
- **Production monitoring** - APM systém a error tracking
- **Performance optimalizace** - database indexy a query optimization
- **Email systém** - ActionMailer templates pro transactional emails

### 📈 **Dlouhodobé cíle**
- **Admin panel** - administrace uživatelů, objednávek, produktů
- **Advanced API features** - subscriptions, bulk operations
- **Analytics & reporting** - dashboardy a business intelligence (až bude prodávat)

---

## 📌 Pravidlo
👉 Každý krok řeším v samostatném chatu, aby byl přehledný a strukturovaný.