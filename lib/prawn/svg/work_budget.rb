# Bounds the time and memory a render can take, so small hostile input can't run away with either.  A unit is
# roughly an element, a drawing call recorded or copied, a character of text, a few hundred bytes of loaded data or
# 25 elements checked against a simple CSS selector.
# The budget is shared by the whole render, including nested documents.
class Prawn::SVG::WorkBudget
  attr_accessor :used

  # +max_work+ is a positive integer, or false for no limit.
  def initialize(max_work)
    @max_work = max_work
    @used = 0
  end

  def record(units)
    @used += units
    raise Prawn::SVG::WorkLimitExceeded, 'The SVG needs too much work to render; see the :max_work option' if @max_work && @used > @max_work
  end
end
