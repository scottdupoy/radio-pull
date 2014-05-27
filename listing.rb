# encoding: utf-8

class Listing
    attr_accessor \
        :id,
        :dj,
        :station,
        :short_description,
        :long_description,
        :hash,
        :date,
        :raw_file_name
 
    def lookup_string
        result = @station + " : " + @dj + " : " + @short_description
    end

    def details_string
      result = lookup_string + "|" + hash + "|" + date + "|" + raw_file_name
    end

    def raw_file_path
      raw_file_name.chomp
    end

    def mp3_file_path
      "./" + get_file_name + ".mp3"
    end

    def nas_file_path
      "/Volumes/Public/iTunes/iTunes Media/Automatically Add to iTunes.localized/" + get_file_name + ".mp3"
    end

    def to_s()
        result =
            @id + " : " +
            @station + " : " +
            @dj + " : " +
            @short_description + " : " +
            @long_description
    end

    def get_file_name
        clean_dj = sanitise_string(@dj).sub(/^BBC_Radio_1s_/, "").sub(/\s-\s\S+day/, "")
        clean_description = sanitise_string(@short_description)
        f = @date + "-" + clean_dj
        if !/\D+/.match(clean_description).nil?
            f = f + "-" + clean_description
        end
        f
    end

private

    def sanitise_string(s)
        s = s.gsub(/['.,"!^#£$?\\\/]/, "")
        s = s.gsub(/[&]/, "and")
        s.gsub(/\s/, "_")
    end

end

