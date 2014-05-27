# encoding: utf-8

require 'fileutils'
require './target.rb'
require './gip.rb'
require './listing_target_filter.rb'

class Retriever

    def initialize()
        @gip = Gip.new()
    end

    def retrieve(level)
        ensure_directories();
        if ARGV.count > 0 then
            retrieve_by_id(ARGV[0], level)
        else
            retrieve_by_search(level)
        end
    end

private

    def retrieve_by_id(listing_id, level)
        puts "Retrieving by id: " + listing_id
        listings = @gip.get_listings_by_id(listing_id)
        handle_listings(listings, level)
    end

    def retrieve_by_search(level)
        puts "Retrieving via search"
        targetedListings = get_targeted_listings();
        handle_listings(targetedListings, level)
    end

    def convert_to_mp3(listing)
        puts "Converting m4a to mp3"

        artist = listing.dj;
        title = listing.date + " - " + listing.dj + " - " + listing.short_description;
        album = "BBC - " + listing.dj;
        genre = "Dance";

        # Essential mixes
        if /Essential.Mix/.match(listing.dj) then
            artist = listing.short_description
            album = "BBC - Essential Mix"
            title = listing.date + " - Essential Mix: " + listing.short_description
        end

        puts "  artist: " + artist
        puts "  title:  " + title
        puts "  album:  " + album
        puts "  genre:  " + genre

        # worked out the metadata, so convert to mp3
        puts "Calling ffmpeg"
        output = `ffmpeg -i "#{listing.raw_file_path}" -ab 128k -metadata artist="#{artist}" -metadata title="#{title}" -metadata album="#{album}" -metadata genre="#{genre}" "#{listing.mp3_file_path}" 2>&1`
        if !File.exists? listing.mp3_file_path
            puts output
            abort("ERROR: ffmpeg m4a to mp3 conversion failed")
        end
    end

    def ensure_directories()
        puts "Ensuring directories exists"
        ensure_directory('./data')
        puts
    end

    def ensure_directory(dir)
        if !File.exists?(dir) || !File.directory?(dir)
            FileUtils.mkdir(dir)
        end
    end

    def get_targeted_listings()
        listings = @gip.get_listings()
        filter = ListingTargetFilter.new(get_targets())
        filtered_listings = Array.new()
        listings.each() do |listing|
            if filter.is_target_listing(listing)
                filtered_listings.push(listing)
            end
        end
        filtered_listings
    end

    def handle_listings(listings, level)
        listings.each() do |listing|
          handle_listing(listing, level)
          puts
        end
    end

    def handle_listing(listing, level)
        puts "Checking listing: #{listing}"

        ensure_listing_downloaded(listing, level)
        if listing.raw_file_name.nil? || listing.date.nil? || listing.hash.nil?
          puts "Download failed, stopping"
          return
        end

        puts "  hash:          #{listing.hash}"
        puts "  date:          #{listing.date}"
        puts "  raw_file_name: #{listing.raw_file_name}"

        if File.exists?('./data/download-completed.txt') && File.readlines('./data/download-completed.txt').grep(/#{listing.hash}/).size > 0
            puts "File processing completed for #{listing.hash}, stopping"
            cleanup_files(listing)
            return
        end

        if !File.exists?(listing.raw_file_path)
            abort("ERROR: raw file does not exist: [" + listing.raw_file_path + "]")
        end

        if !File.exists?(listing.mp3_file_path)
            convert_to_mp3(listing)
        end

        move_to_nas(listing)
        cleanup_files(listing)

        open('./data/download-completed.txt', 'a') do |f|
            f.puts listing.hash
        end
    end

    def cleanup_files(listing)
        cleanup_file(listing.raw_file_path)
        cleanup_file(listing.mp3_file_path)
    end

    def cleanup_file(file)
        if File.exists?(file)
            puts "Deleting file: " + file
            File.delete(file)
        end
    end

    def ensure_listing_downloaded(listing, level)
        listing_lookup_string = listing.lookup_string

        if File.exists?('./data/download-details.txt')
            File.open('./data/download-details.txt', 'r') do |file_handle|
                file_handle.each_line do |line|
                    lookup, hash, date, raw_file_name = line.split('|')
                    if !lookup.nil? && !hash.nil? && !raw_file_name.nil? && !date.nil? && lookup == listing_lookup_string
                        listing.hash = hash
                        listing.date = date
                        listing.raw_file_name = raw_file_name
                    end
                end
            end
        end

        if !listing.hash.nil? && !listing.raw_file_name.nil?
            puts "Already downloaded: #{listing.hash}"
            return
        end

        puts "Downloading: " + listing.to_s()

        download_output = @gip.download_listing(listing, level)

        if !download_output.nil? 
            download_output.split(/\n/).each() do |line|
            line_match = /^INFO: Recorded .*\/([^\/]*)\s*$/.match(line)
            if !line_match.nil?
                listing.raw_file_name = "./" + line_match[1]
                hash_match = /_([^_]+)_default.m4a$/.match(listing.raw_file_name)
                if !hash_match.nil?
                    listing.hash = hash_match[1]
                end
            end

            line_match = /©nam .+(\d{2}) (\d{2}) (\d{4})\s*$/.match(line)
                if !line_match.nil?
                    listing.date = line_match[3].sub(/^0*/,"") + "-" + line_match[2].sub(/^0*/,"").rjust(2, "0") + "-" + line_match[1].sub(/^0*/,"").rjust(2, "0")
                end
            end
        end

        if listing.raw_file_name.nil? || listing.date.nil? || listing.hash.nil?
            puts "FAILED"
        else
            puts "SUCCEEDED"
            puts "Writing to ./data/download-details.txt"
            open('./data/download-details.txt', 'a') do |f|
                f.puts listing.details_string
            end
        end

    end

    def move_to_nas(listing)
        puts "Copying file across network"
        puts "  From: " + listing.mp3_file_path
        puts "  To:   " + listing.nas_file_path
        FileUtils.cp(listing.mp3_file_path, listing.nas_file_path)
    end

    def get_targets()
        results = Array.new()
        File.open('./data/targets.txt', 'r') do |file_handle|
          file_handle.each_line do |line|
            pattern, name = line.split('|')
            if !name.nil? && !pattern.nil?
              pattern = pattern.chomp
              puts "Target: #{pattern} => #{name}"
              results.push(Target.new(name, pattern));
            end
          end
        end
        puts
        results
    end
end

