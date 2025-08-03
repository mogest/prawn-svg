#
# This element base class is used for elements that render directly to the Prawn canvas.
#
# Initially when I wrote prawn-svg, I was expecting to have multiple renderers and thought separating the codebase
# from the Prawn renderer would be a good idea.  However, it turns out that the Prawn renderer was the only one
# that was targeted, and it ended up being tightly coupled with the Prawn library.
#
# This class is probably how I should have written it.  Direct render is required to do text rendering properly
# because we need to know the width of all the things we print.  As of the time of this comment it's the only
# system that uses DirectRenderBase in prawn-svg.
#
class Prawn::SVG::Elements::DirectRenderBase < Prawn::SVG::Elements::Base
  # Called by Renderer when it finds the svg:render call added below.
  def render(prawn, renderer); end

  protected

  def parse_and_apply
    parse_standard_attributes
    parse
    apply_calls_from_standard_attributes
    @parent_calls << ['svg:render', [self], [], []] unless computed_properties.display == 'none'
  rescue SkipElementQuietly
  rescue SkipElementError => e
    @document.warnings << e.message
  end
end
