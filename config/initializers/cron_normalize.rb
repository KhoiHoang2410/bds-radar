# Normalize cron: every 4 hours (decoupled from fetch). Registered only in the
# Sidekiq server process (not web/console/test), in its own initializer so it never
# conflicts with the fetch schedule.
Sidekiq.configure_server do
  require "sidekiq/cron"
  Sidekiq::Cron::Job.load_from_hash!(
    "normalize" => { "cron" => "0 */4 * * *", "class" => "Normalize::MasterJob", "queue" => "default" }
  )
end
