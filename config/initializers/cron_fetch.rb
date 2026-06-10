# Fetch cron: every 6 hours. Registered only in the Sidekiq server process, in its
# own initializer so it never conflicts with the normalize schedule.
Sidekiq.configure_server do
  require "sidekiq/cron"
  Sidekiq::Cron::Job.load_from_hash!(
    "fetch" => { "cron" => "0 */6 * * *", "class" => "Fetch::MasterJob", "queue" => "default" }
  )
end
