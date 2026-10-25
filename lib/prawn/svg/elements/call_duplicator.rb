#
# Unfortunately, prawn mutates arguments passed in to it.
# When we make a copy of one of the call stacks, we need to make a deep
# duplicate of it so that the first time prawn mutates the arguments, it
# won't affect the subsequent calls.
#
module Prawn::SVG::Elements::CallDuplicator
  # Patterns, markers, masks and clip paths copy their content's calls wherever they're used, and can be nested.
  MAX_DUPLICATED_VALUES_PER_RENDER = 20_000_000

  private

  def duplicate_calls(calls)
    duplicate_array(calls)
  end

  def duplicate_array(array)
    count_duplicated_values(array.length)

    array.map do |value|
      case value
      when Array then duplicate_array(value)
      when Hash  then duplicate_hash(value)
      else            value
      end
    end
  end

  def duplicate_hash(hash)
    count_duplicated_values(hash.length)

    hash.each.with_object({}) do |(key, value), result|
      result[key] = case value
                    when Array then duplicate_array(value)
                    when Hash  then duplicate_hash(value)
                    else            value
                    end
    end
  end

  def count_duplicated_values(count)
    return if (document.root_document.duplicated_value_count += count) <= MAX_DUPLICATED_VALUES_PER_RENDER

    raise Prawn::SVG::Elements::Base::SkipElementError, 'too much pattern, marker, mask or clip path content is rendered'
  end
end
