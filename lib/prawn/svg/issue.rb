module Prawn::SVG
  Issue = Struct.new(:category, :message)
  Issue::CATEGORIES = %i[unsupported unknown invalid resource].freeze

  class IssueError < StandardError
    attr_reader :issues

    def initialize(issues)
      @issues = issues
      super(issues.map(&:message).join("\n"))
    end
  end
end
