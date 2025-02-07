# frozen_string_literal: true

module Instructeurs
  class ProceduresController < InstructeurController
    before_action :ensure_ownership!, except: [:index, :order_positions, :update_order_positions]
    before_action :ensure_not_super_admin!, only: [:download_export, :exports]

    ITEMS_PER_PAGE = 100
    BATCH_SELECTION_LIMIT = 500

    def index
      all_procedures = current_instructeur
        .procedures
        .kept

      all_procedures_for_listing = all_procedures
        .with_attached_logo

      dossiers = current_instructeur.dossiers
        .joins(groupe_instructeur: :procedure)
        .where(procedures: { hidden_at: nil })

      # .uniq is much more faster than a distinct on a joint column
      procedures_dossiers_en_cours = dossiers.joins(:revision).en_cours.pluck(ProcedureRevision.arel_table[:procedure_id]).uniq

      @procedures = all_procedures.order(closed_at: :desc, unpublished_at: :desc, published_at: :desc, created_at: :desc)
      publiees_or_closes_with_dossiers_en_cours = all_procedures_for_listing.publiees.or(all_procedures.closes.where(id: procedures_dossiers_en_cours))
      current_instructeur.ensure_instructeur_procedures_for(publiees_or_closes_with_dossiers_en_cours)
      @procedures_en_cours = publiees_or_closes_with_dossiers_en_cours.order_by_position_for(current_instructeur).page(params[:page]).per(ITEMS_PER_PAGE)
      closes_with_no_dossier_en_cours = all_procedures.closes.excluding(all_procedures.closes.where(id: procedures_dossiers_en_cours))
      @procedures_closes = closes_with_no_dossier_en_cours.order(created_at: :desc).page(params[:page]).per(ITEMS_PER_PAGE)
      @procedures_draft = all_procedures_for_listing.brouillons.order(created_at: :desc).page(params[:page]).per(ITEMS_PER_PAGE)
      @procedures_en_cours_count = publiees_or_closes_with_dossiers_en_cours.count
      @procedures_draft_count = all_procedures_for_listing.brouillons.count
      @procedures_closes_count = closes_with_no_dossier_en_cours.count

      @dossiers_count_per_procedure = dossiers.by_statut('tous').group('groupe_instructeurs.procedure_id').reorder(nil).count
      @dossiers_a_suivre_count_per_procedure = dossiers.by_statut('a-suivre').group('groupe_instructeurs.procedure_id').reorder(nil).count
      @dossiers_termines_count_per_procedure = dossiers.by_statut('traites').group('groupe_instructeurs.procedure_id').reorder(nil).count
      @dossiers_expirant_count_per_procedure = dossiers.by_statut('expirant').group('groupe_instructeurs.procedure_id').count

      groupe_ids = current_instructeur.groupe_instructeurs.pluck(:id)
      @followed_dossiers_count_per_procedure = current_instructeur
        .followed_dossiers
        .joins(:groupe_instructeur)
        .en_cours
        .where(groupe_instructeur_id: groupe_ids)
        .visible_by_administration
        .group('groupe_instructeurs.procedure_id')
        .reorder(nil)
        .count

      @all_dossiers_counts = {
        'a-suivre' => @dossiers_a_suivre_count_per_procedure.sum { |_, v| v },
        'suivis' => @followed_dossiers_count_per_procedure.sum { |_, v| v },
        'traites' => @dossiers_termines_count_per_procedure.sum { |_, v| v },
        'tous' => @dossiers_count_per_procedure.sum { |_, v| v },
        'expirant' => @dossiers_expirant_count_per_procedure.sum { |_, v| v }
      }

      @procedure_ids_en_cours_with_notifications = current_instructeur.procedure_ids_with_notifications(:en_cours)
      @procedure_ids_termines_with_notifications = current_instructeur.procedure_ids_with_notifications(:termine)
      @statut = params[:statut]
      @statut.blank? ? @statut = 'en-cours' : @statut = params[:statut]
    end

    def order_positions
      @procedures = Procedure.where(id: params[:collection_ids]).order_by_position_for(current_instructeur)
      render layout: "empty_layout"
    end

    def update_order_positions
      current_instructeur.update_instructeur_procedures_positions(ordered_procedure_ids_params)
      redirect_to instructeur_procedures_path, notice: "L'ordre des démarches a été mis à jour."
    end

    def show
      @procedure = procedure
      # Technically, procedure_presentation already sets the attribute.
      # Setting it here to make clear that it is used by the view
      @procedure_presentation = procedure_presentation

      @current_filters = procedure_presentation.filters_for(statut)
      @counts = current_instructeur
        .dossiers_count_summary(groupe_instructeur_ids)
        .symbolize_keys
      @can_download_dossiers = (@counts[:tous] + @counts[:archives]) > 0 && !instructeur_as_manager?

      dossiers = Dossier.where(groupe_instructeur_id: groupe_instructeur_ids)
      dossiers_count = @counts[statut.underscore.to_sym]

      @followed_dossiers_id = current_instructeur
        .followed_dossiers
        .en_cours
        .merge(dossiers.visible_by_administration)
        .pluck(:id)

      notifications = current_instructeur.notifications_for_groupe_instructeurs(groupe_instructeur_ids)
      @has_en_cours_notifications = notifications[:en_cours].present?
      @has_termine_notifications = notifications[:termines].present?
      @not_archived_notifications_dossier_ids = notifications[:en_cours] + notifications[:termines]

      @has_export_notification = notify_exports?
      @last_export = last_export_for(statut)
      @filtered_sorted_ids = DossierFilterService.filtered_sorted_ids(dossiers, statut, procedure_presentation.filters_for(statut), procedure_presentation.sorted_column, current_instructeur, count: dossiers_count)
      page = params[:page].presence || 1

      @dossiers_count = @filtered_sorted_ids.size
      @archived_dossiers_count = if statut == 'tous'
        @counts[:archives]
      else
        0
      end

      @filtered_sorted_paginated_ids = Kaminari
        .paginate_array(@filtered_sorted_ids)
        .page(page)
        .per(ITEMS_PER_PAGE)

      @projected_dossiers = DossierProjectionService.project(@filtered_sorted_paginated_ids, procedure_presentation.displayed_columns)
      @disable_checkbox_all = @projected_dossiers.all? { _1.batch_operation_id.present? }

      @batch_operations = BatchOperation.joins(:groupe_instructeurs)
        .where(groupe_instructeurs: current_instructeur.groupe_instructeurs.where(procedure_id: @procedure.id))
        .where(seen_at: nil)
        .distinct

      cache_show_procedure_state # don't move in callback, inherited by Instructeurs::DossiersController
    end

    def deleted_dossiers
      @procedure = procedure
      @deleted_dossiers = @procedure
        .deleted_dossiers
        .order(:dossier_id)
        .page params[:page]

      @a_suivre_count, @suivis_count, @traites_count, @tous_count, @archives_count, @supprimes_count, @expirant_count = current_instructeur
        .dossiers_count_summary(groupe_instructeur_ids)
        .fetch_values('a_suivre', 'suivis', 'traites', 'tous', 'archives', 'supprimes', 'expirant')
      @can_download_dossiers = (@tous_count + @archives_count) > 0 && !instructeur_as_manager?

      notifications = current_instructeur.notifications_for_groupe_instructeurs(groupe_instructeur_ids)
      @has_en_cours_notifications = notifications[:en_cours].present?
      @has_termine_notifications = notifications[:termines].present?

      @statut = 'supprime'
    end

    def download_export
      groupe_instructeurs = current_instructeur
        .groupe_instructeurs
        .where(procedure: procedure)

      export = Export.find_or_create_fresh_export(export_format, groupe_instructeurs, current_instructeur, **export_options)

      @procedure = procedure
      @statut = export_options[:statut]
      @dossiers_count = export.count

      @last_export = last_export_for(@statut)

      if export.available?
        respond_to do |format|
          format.turbo_stream do
            flash.notice = t('instructeurs.procedures.export_available_html', file_format: export.format, file_url: export.file.url)
          end

          format.html do
            redirect_to url_from(export.file.url)
          end
        end
      else
        respond_to do |format|
          format.turbo_stream do
            if !params[:no_progress_notification]
              flash.notice = t('instructeurs.procedures.export_pending_html', url: exports_instructeur_procedure_path(procedure))
            end
          end
          format.html do
            redirect_to exports_instructeur_procedure_path(procedure), notice: t('instructeurs.procedures.export_pending_html', url: exports_instructeur_procedure_path(procedure))
          end
        end
      end
    end

    def polling_last_export
      @statut = statut
      @last_export = last_export_for(@statut)
      if @last_export.available?
        flash.notice = t('instructeurs.procedures.export_available_html', file_format: @last_export.format, file_url: @last_export.file.url)
      else
        flash.notice = t('instructeurs.procedures.export_pending_html', url: exports_instructeur_procedure_path(procedure))
      end
    end

    def email_notifications
      @procedure = procedure
      @assign_to = assign_tos.first
    end

    def update_email_notifications
      assign_tos.each do |assign_to|
        assign_to.update!(assign_to_params)
      end
      flash.notice = 'Vos notifications sont enregistrées.'
      redirect_to instructeur_procedure_path(procedure)
    end

    def stats
      @procedure = procedure
      @usual_traitement_time = @procedure.stats_usual_traitement_time
      @dossiers_funnel = @procedure.stats_dossiers_funnel
      @termines_states = @procedure.stats_termines_states
      @termines_by_week = @procedure.stats_termines_by_week
      @usual_traitement_time_by_month = @procedure.stats_usual_traitement_time_by_month_in_days
    end

    def exports
      @procedure = procedure
      @exports = Export.for_groupe_instructeurs(groupe_instructeur_ids).ante_chronological
      cookies.encrypted[cookies_export_key] = {
        value: DateTime.current,
        expires: Export::MAX_DUREE_GENERATION + Export::MAX_DUREE_CONSERVATION_EXPORT,
        httponly: true,
        secure: Rails.env.production?
      }

      respond_to do |format|
        format.turbo_stream
        format.html
      end
    end

    def export_templates
      @procedure = procedure
      @export_templates = current_instructeur.export_templates_for(@procedure).includes(:groupe_instructeur)
    end

    def email_usagers
      @procedure = procedure
      @bulk_messages = BulkMessage.where(procedure: procedure)
      @bulk_message = current_instructeur.bulk_messages.build

      instructeur_groupe_ids = current_instructeur.groupe_instructeurs.where(procedure: procedure).ids
      @dossiers_count = procedure.dossiers.state_brouillon.where(groupe_instructeur_id: instructeur_groupe_ids).count
    end

    def create_multiple_commentaire
      @procedure = procedure
      errors = []
      bulk_message = current_instructeur.bulk_messages.build(bulk_message_params)
      instructeur_groupe_ids = current_instructeur.groupe_instructeurs.where(procedure: procedure).ids

      dossiers = procedure.dossiers.state_brouillon.where(groupe_instructeur_id: instructeur_groupe_ids)

      dossiers.each do |dossier|
        commentaire = CommentaireService.create(current_instructeur, dossier, bulk_message_params.except(:targets))
        if commentaire.errors.empty?
          commentaire.dossier.touch(:last_commentaire_updated_at)
        else
          errors << dossier.id
        end
      end

      valid_dossiers_count = dossiers.count - errors.count
      bulk_message.assign_attributes(
        dossier_count: valid_dossiers_count,
        dossier_state: Dossier.states.fetch(:brouillon),
        sent_at: Time.zone.now,
        instructeur_id: current_instructeur.id,
        procedure_id: @procedure.id
      )
      bulk_message.save!

      if errors.empty?
        flash[:notice] = "Tous les messages ont été envoyés avec succès"
      else
        flash[:alert] = "Envoi terminé. Cependant #{errors.count} messages n'ont pas été envoyés"
      end
      redirect_to instructeur_procedure_path(@procedure)
    end

    def administrateurs
      @procedure = procedure
      @administrateurs = procedure.administrateurs
    end

    def apercu
      @procedure = procedure
      @dossier = procedure.active_revision.dossier_for_preview(current_user)
      DossierPreloader.load_one(@dossier)
    end

    private

    def assign_to_params
      params.require(:assign_to)
        .permit(:instant_expert_avis_email_notifications_enabled, :instant_email_dossier_notifications_enabled, :instant_email_message_notifications_enabled, :daily_email_notifications_enabled, :weekly_email_notifications_enabled)
    end

    def assign_tos
      @assign_tos ||= current_instructeur
        .assign_to
        .joins(:groupe_instructeur)
        .where(groupe_instructeur: { procedure_id: procedure_id })
    end

    def groupe_instructeur_ids
      @groupe_instructeur_ids ||= assign_tos
        .map(&:groupe_instructeur_id)
    end

    def statut
      @statut ||= (params[:statut].presence || 'a-suivre')
    end

    def export_format
      @export_format ||= params[:export_format].presence || export_template&.kind
    end

    def export_template
      @export_template ||= ExportTemplate.find(params[:export_template_id]) if params[:export_template_id].present?
    end

    def export_options
      @export_options ||= {
        time_span_type: params[:time_span_type],
        statut: params[:statut],
        export_template:,
        include_archived: params[:include_archived],
        procedure_presentation: params[:statut].present? ? procedure_presentation : nil
      }.compact
    end

    def procedure_id
      params[:procedure_id]
    end

    def procedure
      Procedure
        .with_attached_logo
        .find(procedure_id)
        .tap { Sentry.set_tags(procedure: _1.id) }
    end

    def ensure_ownership!
      if !current_instructeur.procedures.include?(procedure)
        flash[:alert] = "Vous n’avez pas accès à cette démarche"
        redirect_to root_path
      end
    end

    def redirect_to_avis_if_needed
      if current_instructeur.procedures.count == 0 && current_instructeur.avis.count > 0
        redirect_to instructeur_all_avis_path
      end
    end

    def procedure_presentation
      @procedure_presentation ||= begin
        procedure_presentation, errors = current_instructeur.procedure_presentation_and_errors_for_procedure_id(procedure_id)

        if errors.present?
          msg = "Votre affichage a dû être réinitialisé en raison du problème suivant : " + errors.full_messages.join(', ')
          if request.get?
            flash.now[:alert] = msg
          else
            flash[:alert] = msg
          end
        end

        procedure_presentation
      end
    end

    def bulk_message_params
      params.require(:bulk_message).permit(:body)
    end

    def notify_exports?
      last_seen_at = begin
                       DateTime.parse(cookies.encrypted[cookies_export_key])
                     rescue
                       nil
                     end

      scope = Export.generated.for_groupe_instructeurs(groupe_instructeur_ids)
      scope = scope.where(updated_at: last_seen_at...) if last_seen_at

      scope.exists?
    end

    def last_export_for(statut)
      Export.where(user_profile: current_instructeur, statut: statut, updated_at: 1.hour.ago..).last
    end

    def cookies_export_key
      "exports_#{@procedure.id}_seen_at"
    end

    def ordered_procedure_ids_params
      params.require(:ordered_procedure_ids)
    end

    def cache_show_procedure_state
      cache = Cache::ProcedureDossierPagination.new(procedure_presentation:, statut:)

      cache.save_context(ids: @filtered_sorted_paginated_ids, incoming_page: params[:page])
    end
  end
end
