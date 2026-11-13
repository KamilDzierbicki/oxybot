# Integrations call URLs an admin typed (a self-hosted Mattermost server). In production those must resolve to
# public addresses, so the server cannot be pointed at itself, the cloud metadata service or the internal network.
# A self-hosted server on a private network is allowed with ALLOW_PRIVATE_INTEGRATION_HOSTS=true.
module Integration::OutboundUrl
  PRIVATE_RANGES = %w[0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12 192.168.0.0/16
                      ::1/128 fc00::/7 fe80::/10].map { |range| IPAddr.new(range) }.freeze

  class Blocked < StandardError; end

  module_function

  def private_allowed?
    ENV.fetch("ALLOW_PRIVATE_INTEGRATION_HOSTS") { Rails.env.production? ? "false" : "true" } == "true"
  end

  def allowed?(url)
    uri = URI.parse(url.to_s)
    return false unless uri.is_a?(URI::HTTP) && uri.host.present?
    return true if private_allowed?

    addresses = Resolv.getaddresses(uri.host)
    addresses.any? && addresses.none? { |address| PRIVATE_RANGES.any? { |range| range.include?(IPAddr.new(address)) } }
  rescue URI::InvalidURIError, IPAddr::InvalidAddressError
    false
  end

  # Checked again right before each request, so a DNS change after saving does not get around it
  def check!(url)
    raise Blocked, "#{URI.parse(url.to_s).host} is not an allowed address" unless allowed?(url)
  end
end
