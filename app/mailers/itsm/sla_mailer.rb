# frozen_string_literal: true

module Itsm
  class SlaMailer < ::ApplicationMailer
    # kind: :response (prise en charge) ou :resolution
    def breach_alert(user, sla_state, kind)
      @user = user
      @sla_state = sla_state
      @work_package = sla_state.work_package
      @kind = kind
      @due_at = kind == :response ? sla_state.response_due_at : sla_state.resolution_due_at

      subject = I18n.t("itsm.mailer.breach_subject.#{kind}",
                       id: @work_package.id,
                       subject: @work_package.subject)

      mail to: user.mail, subject: subject
    end
  end
end
