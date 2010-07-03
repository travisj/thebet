#!/usr/bin/ruby

require 'yaml'
require 'json'
require 'net/http'
require 'grit'
require 'twitter'
require 'bitly'

class TheBet
	attr_reader :dir

	def initialize(options)
		@dir = options['dir'] || './'
		@game = options['game']
		@url = 'http://espn.go.com/mlb/standings/_/year/2010/seasontype/2'
		@scores = Hash.new
		@specifics = Hash.new
		@date = DateTime::now.strftime("%Y-%m-%d")
		@config = YAML.load_file("config.yaml")

		load_json_configs
		get_current_standings
		write_files
		send_to_git
		update_twitter
	end

	private 

	def score_changed?
		@history[@date].to_json != @todays_score.to_json
		total = 0
		@history[@date].each {|o,s| total += s}
		@todays_score.each {|o,s| total -= s}

		total != 0
		true
	end

	def load_json_configs
		@teams = JSON.parse(IO.read(@dir + '/_json/teams.json'))
		@picks = JSON.parse(IO.read(@dir + '/_json/picks.json'))
		@players = JSON.parse(IO.read(@dir + '/_json/players.json'))
		@history = JSON.parse(IO.read(@dir + '/_json/history.json'))

		@todays_score = @history[@date]

		@players.each do |key, value|
			@scores[key] = 0
		end
	end

	def get_current_standings
		resp = Net::HTTP.get_response(URI.parse(@url))
		resp.body.scan(/<a href="http:\/\/espn.go.com\/mlb\/team\/_\/name\/(.*?)\/(.*?)">(.*?)<\/a><\/td><td>(.*?)<\/td><td>(.*?)<\/td>/) do |match|
			owner = @picks[match[0]]['owner'] if !@picks[match[0]].nil?
			if owner
				choice = @picks[match[0]]['choice'] == 'l' ? 4 : 3
				@scores[owner] += Integer(match[choice])
				@specifics[match[0]] = Integer(match[choice])
			end
		end
	end

	def write_files
		return unless score_changed?

		@history[@date] = Hash.new
		page = "---\nlayout: post\n"
		@scores.each do |owner, score|
			@history[@date][owner] = score
			page += owner + ': ' + score.to_s + "\n"
		end
		@specifics.each do |team, score|
			page += "#{team}: #{score}\n"
		end
		page += "---\n"

		File.open(@dir + '/_posts/' + @date + '-Results.markdown', 'w') {|f| f.write(page)}
		File.open(@dir + '/_json/history.json', 'w') {|f| f.write(@history.to_json)}
	end

	def send_to_git
		return unless score_changed?

		g = Grit::Repo.new(@dir)
		g.add('.')
		g.commit_index('commit')
		g.git.run('', "push origin gh-pages", '', {}, "")
	end

	def update_twitter
		return unless score_changed?

		status = [] 
		@history[@date].each do |owner, score|
			status << "#{@players[owner]['name']}: #{score}"
		end

		msg = status.join(' & ')

		begin
			httpauth = Twitter::HTTPAuth.new(get_config('twitter_user'), get_config('twitter_pass'))
			base = Twitter::Base.new(httpauth)

			bitly = Bitly.new(get_config('bitly_user'), get_config('bitly_pass'))
			u = bitly.shorten(get_config('base_url') + '/' + DateTime::now.strftime('%Y/%m/%d') + '/Results.html')
			base.update(msg + ' ' + u.short_url)
		rescue
			# do nothing
		end
	end

	def get_config(name)
		@config[@game][name]
	end
end



if __FILE__ == $0
	require 'optparse'
	options = Hash.new
	optparse = OptionParser.new do|opts|
		opts.on("-d", "--dir=[ARG]", "pages directory") do |opt|
			options['dir'] = opt
		end
		opts.on("-g", "--game=[ARG]", "which game") do |opt|
			options['game'] = opt
		end
	end
	optparse.parse!(ARGV)
	thebet = TheBet.new(options)
end
