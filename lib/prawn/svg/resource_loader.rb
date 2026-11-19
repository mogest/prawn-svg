# Loads URLs for a document, charging the work budget.  Requests for non-data URLs are charged whether or not they
# succeed, so fan-out can't make endless requests.  Web URLs are loaded by the root document's URL loader, so nested
# documents share its responses and failures.
class Prawn::SVG::ResourceLoader
  REQUEST_WORK = 1000
  BYTES_PER_WORK_UNIT = 256

  def initialize(url_loader, work_budget, web_url_loader = url_loader)
    @url_loader = url_loader
    @work_budget = work_budget
    @web_url_loader = web_url_loader
  end

  # For a nested document, whose URL loader can't read files but which shares the render's budget and web loading.
  def with_url_loader(url_loader)
    self.class.new(url_loader, @work_budget, @web_url_loader)
  end

  def load(url)
    @work_budget.record(REQUEST_WORK) unless url.match?(/\Adata:/i)
    data = (Prawn::SVG::UrlLoader.web_url?(url) ? @web_url_loader : @url_loader).load(url)
    data.tap { @work_budget.record(data.bytesize / BYTES_PER_WORK_UNIT) }
  end
end
