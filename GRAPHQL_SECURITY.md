# 🔒 GraphQL Security Configuration

Kompletní senior-level zabezpečení GraphQL API s konfigurovateními limity a monitoring.

## 🚨 Bezpečnostní opatření

### 1. **Introspection Protection**
```ruby
# V produkci je introspection vypnutý - nikdo neuvidí strukturu API
disable_introspection_entry_points unless Rails.env.development?
```

**Proč:**
- Útočník nemůže získat kompletní schema
- Zákazníci nevidí admin-only mutations
- Skryje business logic a relationships

### 2. **Query Complexity Limits**
```ruby
# Každý field má "cost" - celková query nesmí přesáhnout limit
max_complexity 200  # production
```

**Prevence DoS útoků:**
```graphql
# Tato query by měla vysokou complexity
query ExpensiveQuery {
  products {           # cost: 10
    orders {          # cost: 20 (N+1)
      orderItems {    # cost: 50 (N+1+1)
        product {     # cost: 100 (N+1+1+1)
          orders {    # BLOCKED - příliš náročné!
            # ...
          }
        }
      }
    }
  }
}
```

### 3. **Query Depth Limits**
```ruby
max_depth 10  # maximální vnořenost
```

**Prevence nested bomb útoků:**
```graphql
# Tato query by byla příliš deep
{
  user {
    orders {
      items {
        product {
          category {
            products {
              # BLOCKED na depth 10!
            }
          }
        }
      }
    }
  }
}
```

### 4. **Enhanced Error Handling**
- **Development:** Plné error detaily pro debugging
- **Production:** Bezpečné chybové hlášky v češtině
- **Security logging:** Všechny podezřelé aktivity

### 5. **Request Monitoring**
```ruby
# Logování podezřelých queries
Rails.logger.warn("Introspection query attempt from IP: 192.168.1.1")
Rails.logger.warn("High complexity query: 250 (threshold: 200)")
```

## ⚙️ Konfigurace

### Environment Variables

```bash
# Production limits (Railway/Heroku)
GRAPHQL_MAX_COMPLEXITY=200
GRAPHQL_MAX_DEPTH=10
GRAPHQL_MAX_TOKENS=5000
GRAPHQL_MAX_PAGE_SIZE=50

# Development limits
GRAPHQL_MAX_COMPLEXITY_DEV=1000
GRAPHQL_MAX_DEPTH_DEV=15
GRAPHQL_MAX_TOKENS_DEV=10000
GRAPHQL_MAX_PAGE_SIZE_DEV=100

# Warning thresholds
GRAPHQL_COMPLEXITY_WARNING=150
GRAPHQL_DEPTH_WARNING=8

# Security features
GRAPHQL_ENABLE_INTROSPECTION=false        # Emergency introspection v produkci
GRAPHQL_LOG_SECURITY=true                 # Logovat security events
GRAPHQL_LOG_REQUESTS=false                # Logovat všechny requests (v prod false)
GRAPHQL_DETAILED_ERRORS=false             # Detailní errors v produkci
```

### Doporučené nastavení pro Railway:

```bash
# V Railway Dashboard -> Variables:
GRAPHQL_MAX_COMPLEXITY=200
GRAPHQL_MAX_DEPTH=10
GRAPHQL_LOG_SECURITY=true
GRAPHQL_LOG_REQUESTS=false
GRAPHQL_DETAILED_ERRORS=false
```

## 🛡️ Security Features

### 1. **Authorization Protection**
```ruby
def self.object_from_id(global_id, query_ctx)
  # Automatická kontrola - user může přistupovat jen ke svým objektům
  unless object.user_id == query_ctx[:current_user].id || query_ctx[:current_user].admin?
    Rails.logger.warn("Unauthorized access attempt via GlobalID: #{global_id}")
    return nil
  end
end
```

### 2. **IP Monitoring**
```ruby
# Každý request se loguje s IP adresou
Rails.logger.info("GraphQL Request: 192.168.1.1 - User: 123")
Rails.logger.warn("Introspection query attempt from IP: 192.168.1.1")
```

### 3. **Secure Error Messages**
```ruby
# Production - bezpečné hlášky
"Požadovaný záznam nebyl nalezen"
"Neplatný nebo expirovaný přístupový token"
"Nemáte oprávnění k této operaci"

# Development - detailní info
"ActiveRecord::RecordNotFound: Couldn't find User with 'id'=999"
```

## 📊 Monitoring & Alerting

### 1. **Security Events to Monitor**
```bash
# Vyhledej v logách
grep "Introspection query attempt" production.log
grep "High complexity GraphQL query" production.log
grep "Deep GraphQL query detected" production.log
grep "Unauthorized access attempt" production.log
```

### 2. **Performance Monitoring**
```bash
# Sleduj výkon
grep "GraphQL Request:" production.log | wc -l  # Počet requestů
grep "complexity_value" production.log           # Náročné queries
```

### 3. **Railway Log Monitoring**
```bash
# V Railway CLI
railway logs --filter="GraphQL"
railway logs --filter="Introspection"
railway logs --filter="complexity"
```

## 🚀 Testing Security

### 1. **Test Introspection (should fail in production)**
```graphql
query IntrospectionQuery {
  __schema {
    types {
      name
    }
  }
}
```

**Expected response v produkci:**
```json
{
  "errors": [
    {
      "message": "Field '__schema' doesn't exist on type 'Query'"
    }
  ]
}
```

### 2. **Test Complex Query (should be limited)**
```graphql
query ComplexQuery {
  products {
    name
    # Přidej více nested fieldů dokud nedosáhneš limitu
  }
}
```

### 3. **Test Deep Query (should be limited)**
```graphql
query DeepQuery {
  # Vnořuj více úrovní dokud nedosáhneš depth limitu
}
```

## 🔧 Customization

### Pro specifické potřeby můžeš upravit:

```ruby
# config/application.rb
config.graphql.max_complexity_production = 300  # Vyšší limit
config.graphql.enable_introspection_in_production = true  # Emergency
config.graphql.detailed_errors_in_production = true  # Debug v produkci
```

## 📚 Best Practices

### 1. **Monitoring**
- ✅ Sleduj security logy denně
- ✅ Nastav alerting pro podezřelé aktivity
- ✅ Monitoruj performance metrics

### 2. **Limits**
- ✅ Začni s konzervativními limity
- ✅ Postupně zvyšuj podle potřeby
- ✅ Testuj na staging prostředí

### 3. **Security**
- ✅ Nikdy nepovoluj introspection v produkci
- ✅ Loguj všechny security events
- ✅ Používej bezpečné error messages

### 4. **Performance**
- ✅ Sleduj query complexity
- ✅ Optimalizuj náročné queries
- ✅ Používej DataLoader pro N+1 queries

## 🆘 Emergency Procedures

### Pokud je API pod útokem:

```bash
# 1. Ihned sniž limity
export GRAPHQL_MAX_COMPLEXITY=50
export GRAPHQL_MAX_DEPTH=5

# 2. Povolej detailní logging
export GRAPHQL_LOG_REQUESTS=true
export GRAPHQL_LOG_SECURITY=true

# 3. Restartuj aplikaci
railway up --detach

# 4. Sleduj logy
railway logs --follow
```

### IP Blocking (Railway):
```bash
# Přidej podezřelé IP do firewall rules
# Railway Dashboard > Settings > Network
```

---

**🎯 Výsledek:** Tvé GraphQL API je teď zabezpečené na senior úrovni s kompletním monitoringem a konfigurovatelností pro všechny edge cases!