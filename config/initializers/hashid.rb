Hashid::Rails.configure do |config|
  config.secret = ENV["AWS_SECRET_ACCESS_KEY"] || 'my secret'
  config.length = 8
end
