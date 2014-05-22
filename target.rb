class Target
    attr_accessor :name, :search_field

    def initialize(name, search_field)
        @name = name
        @search_field = search_field
    end

    def to_s
        result = @name + " (" + @search_field + ")"
    end
end

