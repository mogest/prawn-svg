#
# Unfortunately, prawn mutates arguments passed in to it.
# When we make a copy of one of the call stacks, we need to make a deep
# duplicate of it so that the first time prawn mutates the arguments, it
# won't affect the subsequent calls.
#
module Prawn::SVG::Elements::CallDuplicator
  private

  def duplicate_calls(calls)
    duplicate_array(calls)
  end

  def duplicate_array(array)
    # Calls can also be nested in other calls' arguments.
    document.work_budget.record(copied_call_work(*array)) if call?(array)

    array.map do |value|
      case value
      when Array then duplicate_array(value)
      when Hash  then duplicate_hash(value)
      else            value
      end
    end
  end

  def call?(array)
    array.length == 4 && array[0].is_a?(String) && array[1].is_a?(Array) && array[2].is_a?(Hash) && array[3].is_a?(Array)
  end

  def copied_call_work(name, arguments, kwarguments, _children)
    name == 'svg:render' ? arguments.first.work : call_work(name, kwarguments)
  end

  # Roughly how much drawing a call costs, compared with an ordinary call.
  def call_work(name, kwarguments)
    # Each stop becomes several PDF objects every time a gradient is drawn.
    name.to_s == 'svg:render_gradient' ? kwarguments[:stops].length * 3 : 1
  end

  def duplicate_hash(hash)
    hash.each.with_object({}) do |(key, value), result|
      result[key] = case value
                    when Array then duplicate_array(value)
                    when Hash  then duplicate_hash(value)
                    else            value
                    end
    end
  end
end
