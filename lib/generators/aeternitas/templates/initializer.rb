# Configure Aeternitas
Aeternitas.configure do |config|
  config.redis = {host: "localhost", port: 6379} # this is the default Redis config which should work in most cases.
end
