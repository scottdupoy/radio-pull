
class Track
    attr_accessor :artist, :title, :label, :position, :group

    def to_s
        if @position == nil
          @position = "Unknown"
        end
        if @artist == nil
          @artist = "Unknown"
        end
        if @title == nil
          @title = "Unknown"
        end

        result = @position.to_s + ') ' + @artist + ' - ' + @title
        if @label != nil
            result = result + ' [' + @label + ']'
        end
        if @group != nil
            result = @group + ' ' + result
        end
        result
    end
end
