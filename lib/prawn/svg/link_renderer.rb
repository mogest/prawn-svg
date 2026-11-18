class Prawn::SVG::LinkRenderer
  include Prawn::SVG::PDFMatrix

  def initialize(href, bounding_box)
    @href = href
    @bounding_box = bounding_box
  end

  def render(prawn)
    box = transformed_bounding_box(prawn) or return

    prawn.link_annotation(box, {
      Border: [0, 0, 0],
      A:      { Type: :Action, S: :URI, URI: PDF::Core::LiteralString.new(href) }
    })
  end

  private

  attr_reader :href, :bounding_box

  def transformed_bounding_box(prawn)
    x0, y0, x1, y1 = bounding_box

    matrix = load_matrix(prawn.current_transformation_matrix_with_translation(*prawn.bounds.anchor))

    corners = [
      matrix * Vector[x0, y0, 1.0],
      matrix * Vector[x0, y1, 1.0],
      matrix * Vector[x1, y0, 1.0],
      matrix * Vector[x1, y1, 1.0]
    ]

    # Nested transforms can make the box too large to represent.
    return unless corners.flat_map(&:to_a).all?(&:finite?)

    xs = corners.map { |c| c[0] }
    ys = corners.map { |c| c[1] }

    tx0, tx1 = xs.minmax
    ty0, ty1 = ys.minmax

    [tx0, ty0, tx1, ty1]
  end
end
