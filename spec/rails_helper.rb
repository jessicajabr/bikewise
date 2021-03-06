require "rails_helper"

# Assign here because only one .env file
ENV["BASE_URL"] = "http://test.host"
ENV["RAILS_ENV"] ||= "test"

require File.expand_path("../../config/environment", __FILE__)

require "rspec/rails"

require "database_cleaner"
require "sidekiq/testing"
require "vcr"

ActiveRecord::Migration.maintain_test_schema!

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[Rails.root.join("spec", "support", "**", "*.rb")].sort.each { |f| require f }

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.render_views
  # Add devise
  config.include Devise::Test::IntegrationHelpers, type: :request
  config.include Devise::Test::ControllerHelpers, type: :controller
  # Add our request spec helpers
  config.include RequestSpecHelpers, type: :request

  config.before(:each) do
    Sidekiq::Worker.clear_all
  end
end

VCR.configure do |c|
  c.ignore_request do |request|
    request.uri[/(\$zoom\$)/]
  end
  c.cassette_library_dir = "spec/cassettes"
  c.hook_into :webmock
end

# DB Cleaner metadata tags
# ========================
#
# Use the following RSpec metadata tags to tweak how the database is reset
# between tests.
#
# * `strategy: :transaction` (default)
#
# Fastest. Performs queries in a transaction and rolls back at the end of the
# test. A sensible default. The tag can be omitted.
#
# * `strategy: :deletion`
#
# Slower, but comparable in speed to :transaction for small data sets.
# Useful for testing `after_commit` callbacks.
# Does not re-create tables or indexes.
#
# * `strategy: :truncation`
#
# Slowest. Fixed-time regardless of the amount of data (hence cost-effective
# only for large or complicated data setups). Runtime grows with the number of
# tables, indexes, complexity of the db overall.
#
# * `:context_state`
#
# To skip example-wise cleaning (e.g., to share large setup between examples).
# Use sparingly.
#
# ```
# before(:all) { ... }
#
# describe "test 1", :context_state do ...
#
# describe "test 2", :context_state do ...
# ```
#
# * `:js`
#
# For acceptance / system tests (Capybara/Cucumber/Rails 5 system tests) with a
# JS driver. Enables the truncation strategy, which is slowest but most stable.
#
class DirtyDatabaseError < RuntimeError
  def initialize(meta)
    super "#{meta[:full_description]}\n\t#{meta[:location]}"
  end
end

RSpec.configure do |config|
  config.before(:suite) do
    DatabaseCleaner.clean_with(:deletion)
  end
  # TODO: once upgraded to rspec 3, remove this next line
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.before(:all, :context_state) do
    DatabaseCleaner.strategy = :truncation
    DatabaseCleaner.start
  end

  # Pulled from Bike Index - but not doing metadata right now
  # config.before(:each) do |example|
  #   next if example.metadata[:context_state]

  #   strategy =
  #     example.metadata[:strategy] ||
  #     (example.metadata[:js] ? :truncation : :transaction)

  #   DatabaseCleaner.strategy = strategy
  #   DatabaseCleaner.start
  # end

  config.after(:each) do |example|
    # next if example.metadata[:context_state]

    DatabaseCleaner.clean

    # For debugging:
    # if ModelName.count > 0
    #   raise DirtyDatabaseError.new(example.metadata)
    # end
  end

  config.after(:all, :context_state) do
    DatabaseCleaner.clean
  end
end
