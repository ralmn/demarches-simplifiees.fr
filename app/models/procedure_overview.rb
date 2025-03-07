# frozen_string_literal: true

class ProcedureOverview
  attr_accessor :procedure,
    :created_dossiers_count,
    :dossiers_en_instruction_count,
    :old_dossiers_en_instruction,
    :dossiers_en_construction_count,
    :old_dossiers_en_construction

  def initialize(procedure, start_date, groups)
    @start_date = start_date
    @procedure = procedure

    dossiers = procedure.dossiers.where(groupe_instructeur: groups).visible_by_administration

    @dossiers_en_instruction_count = dossiers.state_en_instruction.count
    @old_dossiers_en_instruction = dossiers
      .state_en_instruction
      .where(en_instruction_at: ...1.week.ago)

    @dossiers_en_construction_count = dossiers.state_en_construction.count
    @old_dossiers_en_construction = dossiers
      .state_en_construction
      .where(depose_at: ...1.week.ago)

    @created_dossiers_count = dossiers
      .where(created_at: start_date..Time.zone.now)
      .count
  end

  def had_some_activities?
    [
      @dossiers_en_instruction_count,
      @dossiers_en_construction_count,
      @created_dossiers_count
    ].reduce(:+) > 0
  end

  def dossiers_en_construction_description
    case @dossiers_en_construction_count
    when 0
      nil
    when 1
      'dossier suivi en construction'
    else
      'dossiers suivis en construction'
    end
  end

  def dossiers_en_instruction_description
    case @dossiers_en_instruction_count
    when 0
      nil
    when 1
      "dossier est en cours d’instruction"
    else
      "dossiers sont en cours d’instruction"
    end
  end

  def created_dossier_description
    formated_date = I18n.l(@start_date, format: '%d %B %Y')

    case @created_dossiers_count
    when 0
      nil
    when 1
      "nouveau dossier a été déposé depuis le #{formated_date}"
    else
      "nouveaux dossiers ont été déposés depuis le #{formated_date}"
    end
  end
end
