# 🍃 Lootea B2B Backend

Ruby on Rails 8.0.2 API-only application with GraphQL for B2B tea e-commerce platform.

## 🌍 Language Note

This backend API is built for Czech junior frontend developers, therefore:
- **GraphQL schema descriptions** are in Czech for better understanding
- **Frontend documentation** ([FRONTEND_GUIDE.md](FRONTEND_GUIDE.md)) is in Czech
- **Code comments and error messages** are in English (industry standard)
- **This README** is in English for international developers

## 🚀 Quick Start

### Prerequisites
- Ruby 3.2+
- PostgreSQL 14+
- Node.js (for frontend integration)

### Development Setup
> **⚠️ Opensource projekt:** Musíte si nakonfigurovat vlastní credentials!

```bash
# Clone and setup
git clone <repo-url>
cd eshop-b2b-backend

# Automatická instalace + kontrola credentials
./bin/setup

# Konfigurace credentials (POVINNÉ!)
cp config/credentials.example.yml temp_credentials.yml
# Upravte temp_credentials.yml podle potřeby, pak:
EDITOR=nano rails credentials:edit

# Start server
bin/rails server
```

### GraphQL Playground
- **Development**: http://localhost:3000/graphiql
- **Production**: Disabled for security

**📖 První kroky:** Přečtěte si [`SETUP.md`](SETUP.md) pro detailní instrukce!

## 🔧 Tech Stack

- **Backend**: Ruby 3.2, Rails 8.0.2 (API-only mode)
- **Database**: PostgreSQL with ActiveRecord
- **API**: GraphQL (graphql-ruby gem)
- **Authentication**: JWT tokens with Devise
- **Payments**: Comgate payment gateway integration
- **Code Quality**: RuboCop, Lefthook pre-commit hooks

## 📊 API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/graphql` | POST | Main GraphQL API endpoint |
| `/webhooks/comgate` | POST | Comgate payment webhooks |
| `/graphiql` | GET | GraphQL playground (dev only) |

## 🏗️ Architecture

```
app/
├── controllers/
│   ├── application_controller.rb    # Base controller with JWT auth
│   ├── graphql_controller.rb        # GraphQL endpoint
│   └── webhooks/
│       └── comgate_controller.rb    # Payment webhooks
├── graphql/
│   ├── mutations/
│   │   ├── login_user.rb           # User authentication
│   │   ├── register_user.rb        # User registration
│   │   ├── create_order.rb         # Order creation
│   │   └── pay_order.rb            # Payment initiation
│   └── types/
│       ├── user_type.rb            # User GraphQL type
│       ├── product_type.rb         # Product GraphQL type
│       └── order_type.rb           # Order GraphQL type
├── models/
│   ├── user.rb                     # User model with Devise
│   ├── product.rb                  # Product catalog
│   ├── order.rb                    # Orders with payment status
│   └── order_item.rb               # Order line items
└── services/
    ├── comgate_service/            # Modular Comgate integration
    │   ├── http_client.rb          # HTTP client functionality
    │   └── response_parser.rb      # Response parsing
    ├── comgate_service.rb          # Main payment service
    └── comgate_webhook_service.rb  # Webhook processing
```

## 🔐 Configuration

> **🚨 Bezpečnostní upozornění:** Tento projekt je opensource a neobsahuje produkční credentials. Musíte si nakonfigurovat vlastní!

### 1️⃣ Rychlé nastavení
```bash
# Zkopírujte example soubor
cp config/credentials.example.yml config/credentials.yml

# Nakonfigurujte credentials
EDITOR=nano rails credentials:edit
```

### 2️⃣ Povinná konfigurace
Podle `config/credentials.example.yml` nakonfigurujte:

**🔑 JWT Secret (povinné)**
```bash
# Vygenerujte bezpečný klíč
rails secret
# Vložte do credentials jako devise_jwt_secret_key
```

**💳 Comgate pro platby (povinné pro platby)**
- `merchant_id`: Vaše Comgate merchant ID
- `secret`: Váš Comgate secret klíč
- Získáte na [Comgate portálu](https://portal.comgate.cz)

### 3️⃣ Alternative: Environment Variables
```bash
# .env file pro development
JWT_SECRET_KEY=your_jwt_secret_key
COMGATE_MERCHANT_ID=your_merchant_id
COMGATE_SECRET=your_secret_key
```

### 🆘 Troubleshooting
- **Chyba JWT**: Zkontrolujte `devise_jwt_secret_key` v credentials
- **Chyba Comgate**: Ověřte merchant_id a secret v Comgate portálu
- **Permission denied**: Spusťte `chmod +x bin/setup`

## 🧪 Testing

### Run Tests
```bash
# RSpec tests (when implemented)
bundle exec rspec

# Code quality checks
bundle exec rubocop

# Pre-commit hooks
bundle exec lefthook run pre-commit
```

### Manual API Testing
```bash
# Test GraphQL endpoint
curl -X POST http://localhost:3000/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "{ products { id name priceDecimal } }"}'

# Test webhook endpoint
curl -X POST http://localhost:3000/webhooks/comgate \
  -H "Content-Type: application/json" \
  -d '{"transId":"test123","refId":"1","status":"PAID","price":"299","curr":"CZK","test":"true"}'
```

## 📖 Documentation

- **[Frontend Guide](FRONTEND_GUIDE.md)** - Complete guide for frontend developers with UI tips (in Czech)
- **GraphQL Schema** - Available at `/graphiql` in development
- **Webhook Documentation** - Included in Frontend Guide

## 🔄 Payment Flow

1. **Order Creation**: Frontend creates order via `createOrder` mutation
2. **Payment Initiation**: Frontend calls `payOrder` mutation
3. **Redirect**: User is redirected to Comgate payment gateway
4. **Webhook Processing**: Comgate sends payment status to `/webhooks/comgate`
5. **Status Update**: Order status is automatically updated
6. **Frontend Polling**: Frontend can poll for updated order status

## 🚀 Deployment

### Railway Deployment
```bash
# Install Railway CLI
npm install -g @railway/cli

# Login and deploy
railway login
railway link
railway up
```

### Environment Setup
- Set `RAILS_MASTER_KEY` environment variable
- Configure database URL
- Set Comgate credentials
- Configure CORS for frontend domain

### Production Checklist
- [ ] Rails credentials configured
- [ ] Database migrations run
- [ ] CORS configured for frontend domain
- [ ] Webhook URL configured in Comgate dashboard
- [ ] SSL certificate enabled
- [ ] Error monitoring setup (optional)

## 🛠️ Development

### Code Quality
- **RuboCop**: Enforces Ruby style guide
- **Lefthook**: Pre-commit hooks for quality checks
- **Senior-level patterns**: Proper error handling, logging, validation

### Adding New Features
1. Create migration if needed: `rails g migration AddFieldToModel`
2. Update GraphQL types and mutations
3. Add service classes for business logic
4. Update frontend documentation
5. Run quality checks: `bundle exec rubocop`

### Database Schema
```ruby
# Key models and relationships
User (email, role, company_name)
├── has_many :orders

Product (name, description, price_cents, currency)

Order (total_cents, currency, status, payment_status)
├── belongs_to :user
├── has_many :order_items
└── has_many :products, through: :order_items

OrderItem (quantity, unit_price_cents)
├── belongs_to :order
└── belongs_to :product
```

## 🤝 Contributing

1. Fork the repository
2. Create feature branch: `git checkout -b feature/new-feature`
3. Make changes following code quality standards
4. Run tests and quality checks
5. Commit with descriptive messages
6. Push and create Pull Request

## 📞 Support

For questions about:
- **Backend API**: Check this README and code comments
- **Frontend Integration**: See [FRONTEND_API_GUIDE.md](FRONTEND_API_GUIDE.md)
- **Payment Issues**: Check Comgate service logs and webhook documentation

## 📄 License

This project is proprietary software for Lootea B2B platform.

---

**Built with ❤️ for Czech junior developers learning modern web development**
