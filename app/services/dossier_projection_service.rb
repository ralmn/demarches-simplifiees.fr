# frozen_string_literal: true

class DossierProjectionService
  def self.project(dossiers_ids, columns)
    to_include = columns.map(&:table).uniq.map(&:to_sym).map do |sym|
      case sym
      when :self
        nil
      when :type_de_champ
        :champs
      when :user
        [:user, :individual]
      when :individual
        :individual
      when :etablissement
        :etablissement
      when :groupe_instructeur
        :groupe_instructeur
      when :followers_instructeurs
        :followers_instructeurs
      when :avis
        :avis
      when :dossier_labels
        :labels
      end
    end.flatten.uniq

    Dossier.includes(:corrections, :pending_corrections, :traitements, *to_include).find(dossiers_ids)
  end
end
