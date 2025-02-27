# frozen_string_literal: true

class Champs::DropDownListChamp < Champ
  store_accessor :value_json, :other, :referentiel
  THRESHOLD_NB_OPTIONS_AS_RADIO = 5
  THRESHOLD_NB_OPTIONS_AS_AUTOCOMPLETE = 20
  OTHER = '__other__'
  delegate :options_without_empty_value_when_mandatory, to: :type_de_champ
  validate :validate_value_is_in_options, if: -> { validate_champ_value? && !(value.blank? || drop_down_other?) }
  before_save :store_referentiel, if: :referentiel_mode?

  def render_as_radios?
    drop_down_options.size <= THRESHOLD_NB_OPTIONS_AS_RADIO
  end

  def render_as_combobox?
    drop_down_options.size >= THRESHOLD_NB_OPTIONS_AS_AUTOCOMPLETE
  end

  def html_label?
    !render_as_radios?
  end

  def legend_label?
    render_as_radios?
  end

  def selected
    other? ? OTHER : value
  end

  def other?
    drop_down_other? && (other || value_from_user?)
  end

  def value_from_user?
    value.present? && !value_is_in_options?
  end

  def value=(value)
    if value == OTHER
      self.other = true
      write_attribute(:value, nil)
    else
      self.other = false
      write_attribute(:value, value)
    end
  end

  def store_referentiel
    if other?
      self.referentiel = nil
    else
      self.referentiel = referentiel_from(value)
    end
  end

  def value_other=(value)
    if other?
      write_attribute(:value, value)
    end
  end

  def value_other
    other? ? value : ""
  end

  def referentiel_item_selected?
    referentiel&.dig('data', 'row').present?
  end

  def referentiel_item_value(path)
    referentiel&.dig('data', 'row', path)
  end

  def referentiel_item_column_values
    return [] if referentiel.nil?
    referentiel_headers.map { |(header, path)| [header, referentiel_item_value(path)] }
  end

  def referentiel_item_first_column_value
    return nil if referentiel.nil?
    path = referentiel_headers&.first&.second
    referentiel_item_value(path)
  end

  private

  def referentiel_headers
    headers = referentiel&.dig('data', 'headers') || []
    headers.map { [_1, Referentiel.header_to_path(_1)] }
  end

  def referentiel_from(value)
    if value.present?
      referentiel_item = type_de_champ.referentiel.items.find(value)
      headers = referentiel_item.referentiel.headers
      { data: referentiel_item.data.merge(headers:) }
    end
  end

  def validate_value_is_in_options
    return if value_is_in_options?
    errors.add(:value, :not_in_options)
  end

  def value_is_in_options?
    options_for_select.any? { _1.last == value }
  end
end
