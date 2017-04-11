require 'sinatra'
require 'open-uri'
require 'json'
require "base64"
require "net/https"

require_relative "lib/pr_functions"

configure do
  set :server, :puma
  set :bind, "0.0.0.0"
  set :protection, except: [:frame_options, :json_csrf]
  set :root, File.dirname(__FILE__)

  # this added in attempt to "forbidden" response when clicking on links
  #set :protection, :except => :ip_spoofing
  #set :protection, :except => :json
end

if settings.development?
  require 'pry'
end

get '/' do

end

get '/new' do
  erb :new
end

post '/create' do
  id = @params[:id]
  title = @params[:title]
  type = @params[:type]

  data = {
    "@context": "http://scta.info/api/core/1.0/people/context.json",
    "@id": "http://scta.info/resource/#{id}",
    "@type": "http://scta.info/resource/person",
    "dc:title": "#{title}",
    "sctap:personType": "http://scta.info/resource/#{type}",
    "sctap:shortId": "#{id}"
  }

  content = Base64.encode64(JSON.pretty_generate(data))

  wrapper =
  {
  "message": "New entry for #{id}",
  "committer": {
    "name": "Jeffrey C. Witt",
    "email": "jeffreycwitt@gmail.com"
  },
  "content": content,
  "branch": "develop"
  }
  wrapped_content = JSON.pretty_generate(wrapper)

  uri = URI.parse("https://api.github.com/repos/scta/scta-people/contents/graphs/#{id}.jsonld")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
	req = Net::HTTP::Put.new(uri.request_uri, 'Content-Type' => 'application/json')
  req.basic_auth("jeffreycwitt", ENV['GITHUB_AUTH_TOKEN'])
	req.body = wrapped_content
  @res = http.request(req)

  ## begin pull request
  submit_pr(id)
  erb :created
end

post '/update' do
  id = @params[:id]
  title = @params[:title]
  persontype = @params["sctap:personType"]
  sha = @params[:sha]

  data = {
    "@context": "http://scta.info/api/core/1.0/people/context.json",
    "@id": "http://scta.info/resource/#{id}",
    "@type": "http://scta.info/resource/person",
    "dc:title": "#{title}",
    "sctap:personType": persontype,
    "sctap:shortId": "#{id}"
  }

  content = Base64.encode64(JSON.pretty_generate(data))

  wrapper =
  {
  "message": "Update for #{id}",
  "committer": {
    "name": "Jeffrey C. Witt",
    "email": "jeffreycwitt@gmail.com"
  },
  "content": content,
  "sha": sha,
  "branch": "develop"
  }
  wrapped_content = JSON.pretty_generate(wrapper)

  uri = URI.parse("https://api.github.com/repos/scta/scta-people/contents/graphs/#{id}.jsonld")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
	req = Net::HTTP::Put.new(uri.request_uri, 'Content-Type' => 'application/json')
  req.basic_auth("jeffreycwitt", ENV['GITHUB_AUTH_TOKEN'])
	req.body = wrapped_content
  @res = http.request(req)

  ## begin pull request
  submit_pr(id)

  erb :updated



end
get '/:shortid' do |shortid|
  @edit_branch_title = if params[:branch] then params[:branch] else "master" end

 begin
  file = open("https://api.github.com/repos/scta/scta-people/contents/graphs/#{shortid}.jsonld", http_basic_authentication: ["jeffreycwitt", ENV['GITHUB_AUTH_TOKEN']]).read
 rescue OpenURI::HTTPError
   @data = false
 else
   @data = JSON.parse(file)
   @content = JSON.parse(Base64.decode64(@data["content"]))
 end



  branch_file = open("https://api.github.com/repos/scta/scta-people/contents/graphs/#{shortid}.jsonld?ref=develop", http_basic_authentication: ["jeffreycwitt", ENV['GITHUB_AUTH_TOKEN']]).read
  @branch_data = JSON.parse(branch_file)
  @branch_content = JSON.parse(Base64.decode64(@branch_data["content"]))

  @edit_branch_content =
  if params[:branch] == "master" || params[:branch].nil? then
    if @data != false
      @content
    else
      @branch_content
    end
  else
    @branch_content
  end
  erb :people_editor
end
