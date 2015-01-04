#!/usr/bin/env ruby18

require "yaml"
require "rails_bundle_tools"
require "active_support/inflector"
require "#{ENV['TM_SUPPORT_PATH']}/lib/progress"
require "#{ENV['TM_SUPPORT_PATH']}/lib/current_word"

module TextMate
  class ListColumns
    include ActiveSupport::Inflector

    CACHE_DIR      = File.join(TextMate.project_directory, "tmp", "textmate")
    CACHE_FILE     = File.join(CACHE_DIR, "cache.yml")
    RELOAD_MESSAGE = "Reload database schema..."
    RAILS_REGEX    = /^Rails (\d\.?){3}(\w+)?$/

    def run!
      TextMate.exit_show_tool_tip("Place cursor on class name (or variation) to show its schema") if current_word.nil? || current_word.empty?

      klass = Inflector.singularize(Inflector.underscore(current_word))

      if cache[klass]
        display_menu(klass)
      elsif cache[klass_without_undescore = klass.split('_').last]
        display_menu(klass_without_undescore)
      else
        options = [
          @error,
          nil,
          cache.keys.map { |model_name| "Use #{Inflector.camelize(model_name)}..." }.sort,
          nil,
          RELOAD_MESSAGE
        ].flatten
        selected = TextMate::UI.menu(options)

        return if selected.nil?

        case options[selected]
        when options.first
          if @error && @error =~ /^#{TextMate.project_directory}(.+?)[:]?(\d+)/
            TextMate.open(File.join(TextMate.project_directory, $1), $2.to_i)
          else
            klass_file = File.join(TextMate.project_directory, "/app/models/#{klass}.rb")
            TextMate.open(klass_file) if File.exist?(klass_file)
          end
        when RELOAD_MESSAGE
          cache_attributes and run!
        else
          klass = Inflector.singularize(Inflector.underscore(options[selected].split[1].delete('...')))
          clone_cache(klass, current_word) and display_menu(current_word)
        end
      end
    end

   private
    def clone_cache(klass, new_word)
      cached_model = cache[klass]
      cache[new_word] = cached_model

      File.open(CACHE_FILE, 'w') { |out| out.write YAML.dump(cache) }
    end

    def display_menu(klass)
      columns      = cache[klass][:columns]
      associations = cache[klass][:associations]

      options = associations.empty? ? [] : associations + [nil]
      options += columns + [nil, RELOAD_MESSAGE]

      selected = TextMate::UI.menu(options)
      return if selected.nil?

      if options[selected] == RELOAD_MESSAGE
        cache_attributes and run!
      else
        TextMate.exit_insert_text(options[selected])
      end
    end

    def cache
      Dir.mkdir(CACHE_DIR) unless File.exists?(CACHE_DIR)
      cache_attributes if !File.exist?(CACHE_FILE)

      @cache ||= YAML.load(File.read(CACHE_FILE))
    end

    def cache_attributes
      File.delete(CACHE_FILE) if File.exists?(CACHE_FILE)

      TextMate.call_with_progress(title: "Contacting database", message: "Fetching database schema...") do
        begin
          Dir.chdir TextMate.project_directory
          %x(./bin/spring rails runner "_cache = {}; Dir.glob(Rails.root.join('app', 'models', '**/*.rb')) { |file| @error = klass = File.basename(file, '.*').camelize.constantize; _cache[klass.name.underscore] = { :associations => klass.reflections.stringify_keys.keys, :columns => klass.column_names } if klass and klass.class.is_a?(Class) and klass.ancestors.include?(ActiveRecord::Base); }; File.open(Rails.root.join('tmp', 'textmate', 'cache.yml'), 'w') { |out| out.write YAML.dump(_cache) }")
        rescue Exception => e
          @error = "Fix it: #{e.message}"
        end
      end
    end

    def current_word
      @current_word ||= Word.current_word
    end
  end
end

TextMate::ListColumns.new.run!