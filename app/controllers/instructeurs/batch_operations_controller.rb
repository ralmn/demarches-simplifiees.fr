module Instructeurs
  class BatchOperationsController < ApplicationController
    before_action :set_procedure
    before_action :ensure_ownership!

    def create
      BatchOperation.safe_create!(batch_operation_params.merge(instructeur: current_instructeur))
      redirect_back(fallback_location: instructeur_procedure_url(@procedure.id))
    end

    private

    def batch_operation_params
      params.require(:batch_operation)
        .permit(:operation, dossier_ids: [])
    end

    def set_procedure
      @procedure = Procedure.find(params[:procedure_id])
    end

    def ensure_ownership!
      if !current_instructeur.procedures.exists?(@procedure.id)
        flash[:alert] = "Vous n’avez pas accès à cette démarche"
        redirect_to root_path
      end
    end
  end
end
