# frozen_string_literal: true

class EditableChamp::SiretComponent < EditableChamp::EditableChampBaseComponent
  def dsfr_input_classname
    'fr-input'
  end

  def hint_id
    dom_id(@champ, :siret_info)
  end

  def hintable?
    true
  end

  def update_path
    validate = @champ.prefilled? ? :prefill : nil
    champs_siret_path(@champ.dossier, @champ.stable_id, row_id: @champ.row_id, validate:)
  end
end
