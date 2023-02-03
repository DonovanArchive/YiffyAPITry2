class EmailLinkValidator
  module_function

  def generate(message, purpose, expires = nil)
    validator.generate(message, purpose: purpose, expires_in: expires)
  end

  def validate(hash, purpose)
    message = validator.verify(hash, purpose: purpose)
    return false if message.nil?
    message
  rescue
    false
  end

  def validator
    @validator ||= ActiveSupport::MessageVerifier.new(YiffyAPI.config.email_key, serializer: JSON, digest: "SHA256")
  end
end
