#!/usr/bin/env ruby

##################################################
## Copyright © 2010 Wei Yeh - weicool@gmail.com ##
##################################################

require 'net/http'
require 'ftools'

def make_request(url, cookies = '', redirect_depth = 10)
  raise "FAIL: too many redirects" if redirect_depth == 0
  
  headers = {
    'User-Agent' => 'Mozilla/5.0 Gecko/20100401 Firefox/3.6.3',
    'Cookie' => cookies
  }
  url = URI.parse(url)
  response = Net::HTTP.start(url.host, url.port) do |http|
    http.get(url.request_uri, headers)
  end
  
  # follow redirects
  case response
  when Net::HTTPSuccess     then response
  when Net::HTTPRedirection then make_request(response['location'], cookies, redirect_depth - 1)
  else
    response.error!
  end
  
  response.body
end

usage_text = 'USAGE: ruby fbphotoscraper.rb username c_user xs [counter [limit]]'

if ARGV.size >= 1 && ARGV[0] == 'help'
  puts usage_text
  puts """
fbphotoscraper saves all photos you're tagged in on Facebook onto your computer.

username is your Facebook username

c_user and xs are values of cookies Facebook has saved to your computer.

One way to find out these values is to use Firefox:
1. Log in to your Facebook account. IMPORTANT: make sure you choose NOT to 'Keep me logged in'.
2. Under Firefox's Preferences/Options, find the menu to 'remove individual cookies' or 'show cookies'.
3. Look up the cookie values under the facebook.com domain.
You must be logged in to Facebook for this tool to work.

counter and limit are optional, nonnegative values. counter is the starting number the first
photo is named with and defaults to 0. limit is how many photos you want to save and
defaults to no limit. fbphotoscraper always starts saving the latest photo.

Photos will be saved to the 'photos' directory under the current directory.
"""
  exit
end

if ARGV.size < 3
  puts usage_text
  exit
end

counter = 0
limit = -1  # negative number means no limit

counter = ARGV[3].to_i if ARGV.size >= 4
limit = ARGV[4].to_i if ARGV.size >= 5

photos_base_url = "http://www.facebook.com/#{ARGV[0]}?v=photos&_fb_noscript=1"
photos_per_page = 15
photos_dir = 'photos'

cookies = "c_user=#{ARGV[1]}; xs=#{ARGV[2]}"

# Find the largest page number (so=N)
begin
  base_page = make_request(photos_base_url, cookies)
  largest_page_number = base_page.scan(/(so=(\d+))+/).last.last.to_i
rescue
  puts 'FAIL: You are not logged in to Facebook; please ensure you\'ve passed in correct cookie values.'
  exit
end

File.makedirs(photos_dir) unless File.directory?(photos_dir)
num_photos_saved = 0

num_pages_of_photos = largest_page_number / photos_per_page
(0..num_pages_of_photos).each do |i|
  page_number = i * photos_per_page
  
  # request page of photos
  photos = make_request("#{photos_base_url}&so=#{page_number}", cookies)
  # get urls 
  photo_page_urls = photos.scan(/(UIPhotoGrid_TableCell"><a href="(.*?)")/).map do |url|
    url[1].gsub('amp;', '')
  end
  
  photo_page_urls.each do |photo_page_url|
    break if limit >= 0 && num_photos_saved >= limit
    
    # request a page with the photo we want
    photo_page = make_request("#{photo_page_url}&_fb_noscript=1", cookies)
    photo_url = photo_page.scan(/<img src="(.*?)" id="myphoto"/)[0][0]
    # hack to deal with broken regex -- might consume too many characters
    index_of_quote = photo_url.index('"')
    photo_url = photo_url[0...index_of_quote] if index_of_quote
    
    puts "GET #{photo_url}"
    photo = make_request(photo_url)
    File.open("#{photos_dir}/fbphoto_#{counter}.jpg", 'wb') { |file| file << photo }
    
    counter += 1
    num_photos_saved += 1
  end
  break if limit >= 0 && num_photos_saved >= limit
end

puts "DONE: saved #{num_photos_saved} photos"
