module Support
  def http_response(net_class, body: nil, code: nil, message: nil)
    instance_double(net_class, body: body, code: code, message: message).tap do |response|
      allow(response).to receive(:is_a?) { |klass| net_class <= klass }
    end
  end
end
