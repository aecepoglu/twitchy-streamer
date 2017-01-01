Rails.application.configure do
  config.lograge.enabled = true

  config.lograge.custom_options = lambda do |ev|
    {:time => ev.time}
  end
end

