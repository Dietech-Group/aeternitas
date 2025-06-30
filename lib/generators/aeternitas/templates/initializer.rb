# Aeternitas is configured with sensible defaults. You can override them here if needed.
Aeternitas.configure do |config|
  # Configure source storage (default is Rails.root.join("storage", "aeternitas"))
  # config.storage_adapter_config = {
  #   directory: File.join(Rails.root, 'public', 'sources')
  # }

  # Configure metrics collection (default is disabled)
  # config.metrics_enabled = true

  # Change how long metric data is kept (default is 90 days)
  # config.metric_retention_period = 180.days
end
