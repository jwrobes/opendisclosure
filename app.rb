require 'sinatra'
require 'sinatra/content_for'
require 'active_record'
require 'haml'

# Load ActiveRecord models (and connect to the database)
ENV['DATABASE_URL'] ||= "postgres://localhost/postgres"
ActiveRecord::Base.establish_connection
Dir['./backend/models/*.rb'].each { |f| require f }

configure do
  set :public_folder, 'assets'
end

# The homepage
get '/' do

  # This renders the file views/index.haml inside of the 'yield' in
  # views/layout.haml:
  haml :index, locals: {
    organizations: Party.mayoral_candidates
  }
end

# TODO: Rename to /candidate/:slug ?
#
# This is the candidate page, i.e. the page which summarizes each candidate's
# overall financial status.
get '/party/:id' do |id|
  party         = Party.find(id)
  contributions = Contribution
                    .where(recipient_id: party)
                    .includes(:contributor)

  # This renders the file views/party.haml inside of the 'yield' in
  # views/layout.haml:
  haml :party, locals: {
    party: party,
    contributions: contributions,
    summary: party.summary,
  }
end

# This is page of contributions from an individual/company to various campaigns.
get '/party/:id/contributions' do |id|
  party         = Party.find(id)
  contributions = Contribution
                    .where(contributor_id: party)
                    .includes(:recipient)

  # This renders the file views/contributor.haml inside of the 'yield' in
  # views/layout.haml:
  haml :contributor, locals: {
    party: party,
    contributions: contributions,
  }
end

# Below here are some API endpoints for the frontend JS to use to fetch data.
# This uses a special ActiveRecord syntax for converting models to JSON. It is
# documented here:
#   http://apidock.com/rails/ActiveRecord/Serialization/to_json
get '/api/candidates' do
  headers 'Content-Type' => 'application/json'
  fields = {
    only: %w[id name committee_id received_contributions_count contributions_count received_contributions_from_oakland small_donations],
    methods: [
      :summary,
      :short_name,
      :profession,
      :party_affiliation,
    ],
  }

  Party.mayoral_candidates.to_json(fields)
end

get '/api/contributions' do
  headers 'Content-Type' => 'application/json'
  fields = {
    only: %w[amount date],
    include: [
      { recipient: { methods: :short_name } },
      { contributor: { methods: :short_name } },
    ],
  }

  Contribution
    .where(recipient_id: Party.mayoral_candidates.to_a)
    .includes(:recipient, :contributor)
    .to_json(fields)
end

get '/api/employer_contributions' do
  headers 'Content-Type' => 'application/json'

  EmployerContribution.all.to_json
end

get '/api/category_contributions' do
  headers 'Content-Type' => 'application/json'
  CategoryContribution.all.to_json;
end

get '/api/whales' do
  headers 'Content-Type' => 'application/json'
  fields = {
    only: %[amount],
    include: [:contributor],
  }
  Whale.includes(:contributor).to_json(fields);
end

get '/api/party/:id' do |id|
  # TODO: Include names of the people contributing?
  headers 'Content-Type' => 'application/json'

  fields = {
    only: %w[id name committee_id received_contributions_count contributions_count received_contributions_from_oakland small_donations],
    include: {
      received_contributions: { },
      contributions: { }
    }
  }

  Party.find(id).to_json(fields)
end

after do
  ActiveRecord::Base.connection.close
end
