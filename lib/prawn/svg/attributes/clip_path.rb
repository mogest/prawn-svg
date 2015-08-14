module Prawn::SVG::Attributes::ClipPath
  def parse_clip_path_attribute_and_call
    return unless clip_path = attributes['clip-path']

    if (matches = clip_path.strip.match(/\Aurl\(#(.*)\)\z/)).nil?
      document.warnings << "Only clip-path attributes with the form 'url(#xxx)' are supported"
    elsif (clip_path_element = @document.elements_by_id[matches[1]]).nil?
      document.warnings << "clip-path ID '#{matches[1]}' not defined"
    elsif clip_path_element.source.name != "clipPath"
      document.warnings << "clip-path ID '#{matches[1]}' does not point to a clipPath tag"
    else
      add_call_and_enter 'save_graphics_state'
      add_calls_from_element clip_path_element
      add_call "clip"
    end
  end
end
