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

        def detail_url
          "#{@site.base_url}/video/vimeo/#{id}"
        end

        def cast
          unless @cast
            @cast = []
            excludes = contributor_exclude
            if @video['cast']['member'].is_a? Array
              @video['cast']['member'].each do |m|
                @cast << m unless excludes.include? m['username']
              end
            elsif @video['cast']['member'] && @video['cast']['member']['username'] != 'jbossdeveloper'
              @cast << @video['cast']['member'] unless excludes.include? @video['cast']['member']['username']
            end
          end
          @cast
        end

        def contributor_exclude
          super + ['jbossdeveloper']
        end

      end
    end
  end
end

