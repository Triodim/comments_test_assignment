# frozen_string_literal: true

class ApplicationService
  def self.call(...)
    new(...).call
  end

  def success?
    errors.empty?
  end

  def errors
    @errors ||= []
  end
end
