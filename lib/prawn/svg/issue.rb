module Prawn::SVG
  Issue = Struct.new(:category, :message, keyword_init: true) do
    def initialize(**)
      super
      freeze
    end
  end
  Issue::CATEGORIES = %i[unsupported unknown invalid resource].freeze

  class IssueError < Error
    attr_reader :issues

    def initialize(issues)
      @issues = issues
      super(issues.map(&:message).join("\n"))
    end
  end
end
