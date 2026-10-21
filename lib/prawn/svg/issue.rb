module Prawn::SVG
  # +category+ is one of :unsupported, :unknown, :invalid or :resource
  Issue = Struct.new(:category, :message)

  class IssueError < StandardError
    attr_reader :issues

    def initialize(issues)
      @issues = issues
      super(issues.map(&:message).join("\n"))
    end
  end
end
