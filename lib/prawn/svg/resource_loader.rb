# Loads URLs for a document, charging the work budget.  Requests for non-data URLs are charged whether or not they
# succeed, so fan-out can't make endless requests.  Web responses, including failures, are shared by every document in
# the render so that repeated references fetch only once.
class Prawn::SVG::ResourceLoader
  REQUEST_WORK = 1000
  BYTES_PER_WORK_UNIT = 256

  def initialize(url_loader, work_budget, web_url_loader = url_loader, web_responses = {})
    @url_loader = url_loader
    @work_budget = work_budget
    @web_url_loader = web_url_loader
    @web_responses = web_responses
  end

  # For a nested document, whose URL loader can't read files but which shares the render's budget and web loading.
  def with_url_loader(url_loader)
    self.class.new(url_loader, @work_budget, @web_url_loader, @web_responses)
  end

  def load(url)
    @work_budget.record(REQUEST_WORK) unless url.match?(/\Adata:/i)
    data = Prawn::SVG::UrlLoader.web_url?(url) ? load_web_url(url) : @url_loader.load(url)
    data.tap { @work_budget.record(data.bytesize / BYTES_PER_WORK_UNIT) }
  end

  private

  def load_web_url(url)
    result = @web_responses[url] ||= begin
      @web_url_loader.load(url)
    rescue Prawn::SVG::UrlLoader::Error => e
      e
    end
    result.is_a?(Exception) ? raise(result) : result
  end
end
