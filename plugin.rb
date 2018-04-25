# name: discourse-pm-auto-responder-for-admins
# about: Discourse Private Message Auto Responder For Admins
# version: 0.3
# authors: Muhlis Budi Cahyono (muhlisbc@gmail.com)
# url: https://github.com/muhlisbc/discourse-pm-auto-responder-for-admins

enabled_site_setting :enable_pm_auto_responder_for_admins

DiscoursePluginRegistry.serialized_current_user_fields << "mmn_auto_respond_pm"
DiscoursePluginRegistry.serialized_current_user_fields << "mmn_auto_respond_message"

after_initialize {

  module ::MmnAutoResponder
    def self.included(base)
      base.class_eval {
        after_commit :send_auto_responder, on: :create

        def send_auto_responder
          return if !SiteSetting.enable_pm_auto_responder_for_admins
          
          post_topic = topic
          
          return if !post_topic.private_message? # return if regular topic

          return if user.admin # return if message is sent by admin

          admins    = User.where("id > ?", 0).where(admin: true) # select admins
          user_ids  = post_topic.topic_allowed_users.pluck(:user_id)

          admins.each do |admin|
            if user_ids.include?(admin.id) && admin.custom_fields["mmn_auto_respond_pm"] && (admin.custom_fields["mmn_auto_respond_message"].to_s.strip.length > 0) && ((Time.now.to_i - post_topic.custom_fields["last_auto_respond_by_admin_#{admin.id}"].to_i) >= SiteSetting.delay_between_auto_responder_message_in_hour.to_i.hour.to_i)
              PostCreator.create!(admin, topic_id: post_topic.id, raw: admin.custom_fields["mmn_auto_respond_message"], skip_validation: true)
              post_topic.custom_fields["last_auto_respond_by_admin_#{admin.id}"] = Time.now.to_i
            end
          end
          post_topic.save!

        end
      }
    end
  end

  ::Post.send(:include, MmnAutoResponder)

  User.register_custom_field_type("mmn_auto_respond_pm", :boolean)
  User.register_custom_field_type("mmn_auto_respond_message", :text)

  add_to_serializer(:user, :custom_fields, false) {
    object.custom_fields || {}
  }

  module ::MmnAutoRespondPm
    class Engine < ::Rails::Engine
      engine_name "mmn_auto_respond_pm"
      isolate_namespace MmnAutoRespondPm
    end
  end

  #require_dependency "application_controller"
  class MmnAutoRespondPm::MmnController < ::ApplicationController

    def enable
      set_auto_responder(true)
    end

    def disable
      set_auto_responder(false)
    end

    def is_enabled
      render json: {is_enabled: current_user.custom_fields["mmn_auto_respond_pm"]}
    end

    private

    def set_auto_responder(bool)
      status = if SiteSetting.enable_pm_auto_responder_for_admins && current_user && current_user.admin
          current_user.custom_fields["mmn_auto_respond_pm"] = bool
          current_user.save!
          "ok"
        else
          "error"
        end

      render json: {status: status}
    end

  end

  MmnAutoRespondPm::Engine.routes.draw do
    get "/enable"        => "mmn#enable"
    get "/disable"       => "mmn#disable"
    get "/is_enabled"    => "mmn#is_enabled"
  end

  Discourse::Application.routes.append do
    mount ::MmnAutoRespondPm::Engine, at: "mmn_auto_respond_pm"
  end

}

register_asset "stylesheets/pm-auto-responder.scss"