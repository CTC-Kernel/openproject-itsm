# frozen_string_literal: true

module Itsm
  # Portail demandeur : vue simplifiée pour les utilisateurs côté client
  # (déclarer un incident / une demande, suivre ses tickets).
  class PortalController < ::ApplicationController
    before_action :find_project_by_project_id
    before_action :authorize

    menu_item :itsm_portal

    def index
      @tickets = WorkPackage.where(project: @project,
                                   type: itsm_types,
                                   author: current_user)
                            .includes(:type, :status, :priority)
                            .order(created_at: :desc)
                            .limit(100)
    end

    def new
      @types = itsm_types
      @impact_field = WorkPackageCustomField.find_by(name: PriorityMatrix::IMPACT_FIELD_NAME)
      @urgency_field = WorkPackageCustomField.find_by(name: PriorityMatrix::URGENCY_FIELD_NAME)
    end

    def create
      type = itsm_types.find_by(id: params[:type_id])

      if type.nil? || params[:subject].blank?
        flash[:error] = t("itsm.portal.errors.missing_fields")
        return redirect_to new_itsm_portal_ticket_path(@project)
      end

      call = WorkPackages::CreateService
             .new(user: current_user)
             .call(project: @project,
                   type: type,
                   subject: params[:subject],
                   description: params[:description].to_s,
                   custom_field_values: portal_custom_field_values)

      if call.success?
        flash[:notice] = t("itsm.portal.created", id: call.result.id)
        redirect_to itsm_portal_path(@project)
      else
        flash[:error] = call.errors.full_messages.join(", ")
        redirect_to new_itsm_portal_ticket_path(@project)
      end
    end

    private

    def itsm_types
      Type.where(name: Itsm::Config.itsm_type_names)
    end

    # Reporte les choix Impact / Urgence du formulaire simplifié vers les
    # champs personnalisés, quand ils existent.
    def portal_custom_field_values
      values = {}

      { PriorityMatrix::IMPACT_FIELD_NAME => params[:impact],
        PriorityMatrix::URGENCY_FIELD_NAME => params[:urgency] }.each do |field_name, option_id|
        next if option_id.blank?

        field = WorkPackageCustomField.find_by(name: field_name)
        values[field.id] = option_id if field
      end

      values
    end
  end
end
