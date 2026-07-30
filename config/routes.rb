# frozen_string_literal: true

OpenProject::Application.routes.draw do
  scope "projects/:project_id" do
    get "itsm", to: "itsm/dashboards#show", as: :project_itsm_dashboard

    scope "itsm" do
      # Helpers générés : itsm_sla_policies, new_itsm_sla_policy,
      # edit_itsm_sla_policy, itsm_sla_policy (1er argument : le projet).
      resources :sla_policies,
                controller: "itsm/sla_policies",
                as: :itsm_sla_policies,
                except: %i[show]

      get  "portal",     to: "itsm/portal#index",  as: :itsm_portal
      get  "portal/new", to: "itsm/portal#new",    as: :new_itsm_portal_ticket
      post "portal",     to: "itsm/portal#create", as: :itsm_portal_tickets
    end
  end

  get "itsm", to: "itsm/global_dashboards#show", as: :itsm_global_dashboard
end
