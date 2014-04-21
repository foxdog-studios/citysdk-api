# -*- encoding: utf-8 -*-

module CitySDK
  def render_select(*args)
    SelectRenderer.new(*args).html
  end # def

  module_function :render_select

  private

  class SelectRenderer
    attr_reader :html

    def initialize(name, select_options, options = {})
      @name = name
      @select_options = select_options
      @options = options
      @html = render
    end # def

    private

    def render
      render_parts_list.join('')
    end # def

    def render_parts_list
      [
        render_tag_open,
        render_options,
        render_tag_close
      ]
    end # def

    def render_tag_open
      %(<select name="#{@name}">)
    end # def

    def render_options
      render_options_list.join('')
    end # def

    def render_options_list
      @select_options.map { |value, text| render_option(value, text) }
    end # def

    def render_option(value, text)
      %(<option value="#{value}"#{render_selected(value)}>#{text}</option>)
    end # def

    def render_selected(value)
      # The space before 'selected' is required by render_option.
      selected?(value) ? ' selected' : ''
    end # def

    def selected?(value)
      @options.key?(:selected) && value == @options[:selected]
    end # def

    def render_tag_close
      '</select>'
    end # def
  end # class
end # module

