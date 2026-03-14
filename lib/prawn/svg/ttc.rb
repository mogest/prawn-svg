class Prawn::SVG::TTC
  TTC_TAG = 'ttcf'.freeze

  attr_reader :fonts

  def initialize(filename)
    @fonts = []
    load_data_from_file(filename)
  end

  private

  def load_data_from_file(filename)
    File.open(filename, 'rb') do |f|
      tag = f.read(4)
      next unless tag == TTC_TAG

      _major, _minor = f.read(4).unpack('nn')
      font_count = f.read(4).unpack1('N')
      offsets = f.read(font_count * 4).unpack('N*')

      offsets.each_with_index do |offset, index|
        result = Prawn::SVG::TTF.read_name_table(f, offset)
        next unless result

        family, subfamily = result
        next unless family

        weight_class = Prawn::SVG::TTF.read_weight_class(f, offset)
        @fonts << { family: family, subfamily: subfamily, index: index, weight_class: weight_class }
      end
    end
  rescue Errno::ENOENT
  end
end
