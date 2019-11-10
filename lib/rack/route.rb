# frozen_string_literal: true

module Rack
  class Route
    attr_accessor :request_method, :pattern, :app, :constraints, :name

    PATH_INFO = 'PATH_INFO'
    DEFAULT_WILDCARD_NAME = :paths
    WILDCARD_PATTERN = %r{/\*(.*)}.freeze
    NAMED_SEGMENTS_PATTERN = %r{/([^/]*):([^:$/]+)}.freeze
    DOT = '.'

    def initialize(request_method, pattern, app, options = {})
      if pattern.to_s.strip.empty?
        raise ArgumentError, 'pattern cannot be blank'
      end

      raise ArgumentError, 'app must be callable' unless app.respond_to?(:call)

      @request_method = request_method
      @pattern = pattern
      @app = app
      @constraints = options && options[:constraints]
      @name = options && options[:as]
    end

    def regexp
      @regexp ||= compile
    end

    def compile
      src = if (pattern_match = pattern.match(WILDCARD_PATTERN))
              @wildcard_name = if pattern_match[1].to_s.strip.empty?
                                 DEFAULT_WILDCARD_NAME
                               else
                                 pattern_match[1].to_sym
                               end
              pattern.gsub(WILDCARD_PATTERN, '(?:/(.*)|)')
            else
              p = if (pattern_match = pattern.match(NAMED_SEGMENTS_PATTERN))
                    pattern.gsub(NAMED_SEGMENTS_PATTERN, '/\1(?<\2>[^.$/]+)')
                  else
                    pattern
                  end
              p + '(?:\.(?<format>.*))?'
            end

      Regexp.new("\\A#{src}\\Z")
    end

    def match(request_method, path)
      return nil unless request_method == self.request_method

      raise ArgumentError, 'path is required' if path.to_s.strip.empty?

      return nil unless (path_match = path.match)

      params =
        if @wildcard_name
          { @wildcard_name => path_match[1].to_s.split('/') }
        else
          Hash[path_match.names.map(&:to_sym).zip(path_match.captures)]
        end

      params.delete(:format) if params.key?(:format) && params[:format].nil?

      params if meets_constraints(params)
    end

    def meets_constraints(params)
      constraints&.all? do |param, constraint|
        params[param].to_s.match(constraint)
      end
    end

    def eql?(o)
      o.is_a?(self.class) &&
        o.request_method == request_method &&
        o.pattern == pattern &&
        o.app == app &&
        o.constraints == constraints
    end
    alias == eql?

    def hash
      request_method.hash ^ pattern.hash ^ app.hash ^ constraints.hash
    end
  end
end
