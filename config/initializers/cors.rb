# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin Ajax requests.

# Read more: https://github.com/cyu/rack-cors

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # Povolit všechny origins pro development a testování
    # V produkci byste měli specifikovat konkrétní domény
    origins '*'

    # Pro produkci použijte konkrétní domény:
    # origins ['https://your-frontend-domain.com', 'https://localhost:3000', 'http://localhost:3000']

    resource '*',
             headers: :any,
             methods: %i[get post put patch delete options head],
             credentials: false
  end
end
