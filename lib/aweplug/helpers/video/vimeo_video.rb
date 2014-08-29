require 'aweplug/helpers/video/video_base'
require 'aweplug/helpers/searchisko_social'
require 'aweplug/helpers/searchisko'
require 'ostruct'

module Aweplug
  module Helpers
    module Video
      # Internal: Data object to hold and parse values from the Vimeo API.
      class VimeoVideo < ::Aweplug::Helpers::Video::VideoBase
        include Aweplug::Helpers::SearchiskoSocial

        attr_reader :fetch_failed

        def provider
          'vimeo'
        end

        def url
          @video['urls']['url'].first['_content']
        end

        def thumb_url
          if @video['thumbnails']
            @video["thumbnails"]["thumbnail"][1]["_content"]
          else
            ""
          end
        end

        def duration
          t = Integer @video["duration"]
          Time.at(t).utc.strftime("%T")
        end

        def duration_in_seconds
          a = @video["duration"].split(":").reverse
          (a.length > 0 ? a[0].to_i : 0) + (a.length > 1 ? a[1].to_i * 60 : 0) + (a.length > 2 ? a[2].to_i * 60 : 0)
        end

        def duration_iso8601
          t = Integer @video["duration"]
          Time.at(t).utc.strftime("PT%HH%MM%SS")
        end

        def detail_url
          "#{@site.base_url}/video/vimeo/#{id}"
        end

        def author
          cast[0]
        end

        def cast
          unless @cast
            load_cast
          end
          @cast
        end

        def load_cast
          @cast = []
          unless @video['cast'].nil? || @video['cast']['member'].nil?
            members = [@video['cast']['member']].flatten
            searchisko = Aweplug::Helpers::Searchisko.new({:base_url => @site.dcp_base_url, 
                                              :authenticate => true, 
                                              :searchisko_username => ENV['dcp_user'], 
                                              :searchisko_password => ENV['dcp_password'], 
                                              :cache => @site.cache,
                                              :logger => @site.log_faraday,
                                              :searchisko_warnings => @site.searchisko_warnings})
            members.each do |member|
              unless member['username'] == 'jbossdeveloper'
                searchisko.normalize('contributor_profile_by_vimeo_username', member['username']) do |contributor|
                  if !contributor['sys_contributor'].nil?
                    @cast << add_social_links(contributor['contributor_profile'])
                  elsif !member['display_name'].nil? && !member['display_name'].strip.empty?
                    @cast << OpenStruct.new({:sys_title => member['display_name']})
                  end
                end
            end
            end 
          end 
        end

        def searchisko_payload
          cast = []
          unless @fetch_failed
            excludes = contributor_exclude
            if @video['cast']['member'].is_a? Array
              @video['cast']['member'].each do |m|
                if m['username'] != 'jbossdeveloper'
                  cast << m['username'] unless excludes.include? m['username']
                end
              end
            elsif @video['cast']['member'] && @video['cast']['member']['username'] != 'jbossdeveloper'
              cast << @video['cast']['member']['username'] unless excludes.include? @video['cast']['member']['username']
            end
            author = cast.length > 0 ? cast[0] : nil
            {
              :sys_title => title,
              :sys_description => description,
              :sys_url_view => "#{@site.base_url}/video/vimeo/#{id}",
              :author => author,
              :contributors => cast.empty? ? nil : cast,
              :sys_created => upload_date_iso8601,
              :sys_last_activity_date => modified_date_iso8601,
              :duration => duration_in_seconds,
              :thumbnail => thumb_url,
              :tags => tags
            }.reject{ |k,v| v.nil? }
          end
        end
      end
    end
  end
end

