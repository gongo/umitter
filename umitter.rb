#! /usr/bin/ruby -Ku
# -*- coding: utf-8 -*-

ROOT = Dir::pwd

require 'rubygems'
require 'yaml'
require 'open-uri'
require 'nokogiri'
require 'rubytter'

class Umitter
  def initialize
    @config = YAML.load_file("#{ROOT}/config.yml")
    @message = YAML.load_file("#{ROOT}/message.yml")
    @rubytter = rubytter_setup(@config)
  end

  def write
    twitter_write(analyze_whether)
  end

  def analyze_whether
    info, link = get_whether_info_from_rss

    info_str = ""
    info.each_pair do |k, v|
      info_str += "#{@message[k]} : #{v} " if @message.include?(k)
    end

    info_str
  end

  private

  def rubytter_setup(config)
    consumer = OAuth::Consumer.new(config[:consumer_key], config[:consumer_secret],
                                   :site => "http://twitter.com/",
                                   :proxy => config[:proxy])
    token = OAuth::AccessToken.new(consumer,
                                   config[:access_token_key],
                                   config[:access_token_secret])
    OAuthRubytter.new(token)
  end

  def twitter_write(msg)
    @rubytter.update(msg)
  end

  #
  # 那覇(47930)の天気情報を RSS Feed から取得する
  #
  # return converted_info :: Hash that keys are whether info
  #                            (example: Temperature, Wind Speed, etc..)
  # return link :: 
  #
  def get_whether_info_from_rss
    xml = Nokogiri::XML(open(<<-NAHA_FEED.strip).read)
            http://rss.wunderground.com/auto/rss_full/global/stations/47930.xml
          NAHA_FEED

    item = (xml/'item')[0]
    link = (item/'link').text
    desc = (item/'description').text

    converted_info = convert_rss2string(desc)

    return converted_info, link
  end
  
  #
  # 天気の各情報(気温、風向等)を調べ、
  # 必要な情報を抽出、変換、出力する
  #
  # return converted_info :: Hash that keys are whether info
  #                            (example: Temperature, Wind Speed, etc..)
  # 
  def convert_rss2string(info)
    info_list = Hash.new
    
    info.split(' | ').each do |d|
      key, value = d.split(': ')

      case key
      when 'Temperature'
        convert_value = "#{value.split(' / ').last.sub('&#176;', "°")}"
      when 'Wind Speed'
        speed_kmh = rm_html_tag(value.split(' / ').last).gsub(/km\/h/, "")
        speed_ms = speed_kmh.to_i * 1000 / 3600
        convert_value = "#{speed_ms} m/s"
      when 'Conditions'
        convert_value = @message[value]
      when 'Wind Direction'
        convert_value = value.split('').collect { |c| @message[c] }
      else
        convert_value = value
      end

      info_list[key] = convert_value
    end

    info_list
  end

  #
  # HTML 削除
  #
  def rm_html_tag(str)
    str.gsub(/<[^<>]*>/,"")
  end
end
