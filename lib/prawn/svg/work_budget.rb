# Bounds the time and memory a render can take, so small hostile input can't run away with either.  A unit is
# roughly an element, a drawing call recorded or copied, a character of text, a few hundred bytes of loaded data or
# 25 elements checked against a simple CSS selector.
# The budget is shared by the whole render, including nested documents.
class Prawn::SVG::WorkBudget
  # +max_work+ is a positive integer, or false for no limit.
  def initialize(max_work)
    @max_work = @remaining = max_work
  end

  def record(units)
    return unless @remaining

    @remaining -= units
    raise Prawn::SVG::Document::WorkLimitExceeded, 'The SVG needs too much work to render; see the :max_work option' if @remaining.negative?
  end

  def reset
    @remaining = @max_work
  end
end
