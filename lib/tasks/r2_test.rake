namespace :r2 do
  desc "Test Cloudflare R2 connection and upload"
  task test: :environment do
    puts "🧪 Testing Cloudflare R2 connection..."
    
    begin
      # Test connection
      service = ActiveStorage::Blob.service
      puts "✅ Service configured: #{service.class}"
      
      # Test upload small file
      test_content = "Hello from Lootea eshop! #{Time.current}"
      test_file = StringIO.new(test_content)
      
      blob = ActiveStorage::Blob.create_and_upload!(
        io: test_file,
        filename: "test-#{Time.current.to_i}.txt",
        content_type: "text/plain"
      )
      
      puts "✅ File uploaded successfully!"
      puts "📁 Blob key: #{blob.key}"
      puts "🔗 URL: #{Rails.application.routes.url_helpers.rails_blob_url(blob)}"
      
      # Test URL access
      puts "🌐 Testing file access..."
      url = Rails.application.routes.url_helpers.rails_blob_url(blob)
      puts "📋 Public URL: #{url}"
      
      puts "\n🎉 R2 connection test SUCCESSFUL!"
      
    rescue => e
      puts "❌ R2 connection test FAILED!"
      puts "Error: #{e.message}"
      puts "Class: #{e.class}"
      
      if e.message.include?("credential")
        puts "\n💡 Check your environment variables:"
        puts "   CLOUDFLARE_ACCOUNT_ID"
        puts "   CLOUDFLARE_ACCESS_KEY_ID" 
        puts "   CLOUDFLARE_SECRET_ACCESS_KEY"
        puts "   CLOUDFLARE_BUCKET_NAME"
      end
    end
  end
  
  desc "Show R2 configuration"
  task config: :environment do
    puts "🔧 Current R2 Configuration:"
    puts "Account ID: #{ENV['CLOUDFLARE_ACCOUNT_ID']&.first(8)}..." if ENV['CLOUDFLARE_ACCOUNT_ID']
    puts "Access Key: #{ENV['CLOUDFLARE_ACCESS_KEY_ID']&.first(8)}..." if ENV['CLOUDFLARE_ACCESS_KEY_ID']
    puts "Secret Key: #{'*' * 8}..." if ENV['CLOUDFLARE_SECRET_ACCESS_KEY']
    puts "Bucket: #{ENV['CLOUDFLARE_BUCKET_NAME']}"
    puts "Environment: #{Rails.env}"
    puts "Active Storage Service: #{Rails.application.config.active_storage.service}"
  end
end 