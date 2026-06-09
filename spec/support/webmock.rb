require "webmock/rspec"

# Non-negotiable testing rule: never stub a method's return value — stub only
# outbound HTTP. Disabling real connections forces every supplier test to go
# through a registered stub / VCR cassette built from the captured live samples.
WebMock.disable_net_connect!(allow_localhost: true)
