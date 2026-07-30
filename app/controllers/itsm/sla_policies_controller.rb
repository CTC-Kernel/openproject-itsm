# frozen_string_literal: true

module Itsm
  class SlaPoliciesController < ::ApplicationController
    before_action :find_project_by_project_id
    before_action :authorize
    before_action :find_policy, only: %i[edit update destroy]

    menu_item :itsm_dashboard

    def index
      @policies = Itsm::SlaPolicy.where(project: @project)
                                 .includes(:priority)
                                 .order(:priority_id)
    end

    def new
      @policy = Itsm::SlaPolicy.new(project: @project)
    end

    def create
      @policy = Itsm::SlaPolicy.new(policy_params.merge(project: @project))

      if @policy.save
        flash[:notice] = t(:notice_successful_create)
        redirect_to itsm_sla_policies_path(@project)
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @policy.update(policy_params)
        flash[:notice] = t(:notice_successful_update)
        redirect_to itsm_sla_policies_path(@project)
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @policy.destroy
      flash[:notice] = t(:notice_successful_delete)
      redirect_to itsm_sla_policies_path(@project)
    end

    private

    def find_policy
      @policy = Itsm::SlaPolicy.where(project: @project).find(params[:id])
    end

    def policy_params
      params.require(:itsm_sla_policy)
            .permit(:name, :priority_id, :response_minutes, :resolution_minutes,
                    :support_24_7, :day_start, :day_end, :working_days,
                    :holiday_dates, :active)
    end
  end
end
