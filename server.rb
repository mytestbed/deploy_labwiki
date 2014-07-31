require 'sinatra'
require 'json'

def update_repo(branch, new_commit_id)
  # Pull changes
  system("git checkout -f #{branch}; git pull")
  # Record commit id
  system("echo '#{new_commit_id} | #{Time.now.to_s}'>> deploy_history")
end

post '/payload' do
  push = JSON.parse(request.body.read)

  new_commit_id = push["after"]

  return if new_commit_id.nil?

  branch = push["ref"].split('/').last
  repo = push["repository"]["name"]


  EM.defer do
    Dir.chdir("/var/lib/labwiki/labwiki") do
      if repo =~ /plugin/
        Dir.chdir("/var/lib/labwiki/labwiki/plugins/#{repo}") { update_repo(branch, new_commit_id) }
      else
        update_repo(branch, new_commit_id)
      end

      Bundler.with_clean_env do
        # Bundle update
        system("bundle update")
        # Restart
        system("bundle exec rake stop")
        system("bundle exec rake start")
      end
    end

    puts "Deployed #{repo} with #{new_commit_id} at #{Time.now.to_s}"
  end

  "Received #{repo} : #{new_commit_id}"
end
