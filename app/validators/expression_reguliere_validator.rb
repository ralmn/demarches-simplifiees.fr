
class ExpressionReguliereValidator < ActiveModel::Validator
  def validate(record)
    if record.value.present?
      begin
        if !record.value.match?(Regexp.new(record.expression_reguliere, timeout: 5.0))
          record.errors.add(:value, I18n.t('errors.messages.invalid_regexp', expression_reguliere_error_message: record.expression_reguliere_error_message))
        end
      rescue Regexp::TimeoutError
        record.errors.add(:expression_reguliere, I18n.t('errors.messages.evil_regexp'))
      end
    end
  end
end
