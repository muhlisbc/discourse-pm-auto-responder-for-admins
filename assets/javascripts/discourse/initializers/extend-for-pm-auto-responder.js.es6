import { withPluginApi } from 'discourse/lib/plugin-api';
import { ajax } from 'discourse/lib/ajax';

function toggleAutoRespondPm(user) {
  const path      = user.get("is_auto_responder_enabled") ? "disable" : "enable";

  user.toggleProperty("is_auto_responder_enabled");
  $(".pm-auto-responder-icon").toggleClass("mmn-icon-active");

  ajax(`/mmn_auto_respond_pm/${path}`)
    .catch(e => {
      console.log(e);
    }).then(result => {
      if (result.status != "ok") {
        user.toggleProperty("is_auto_responder_enabled");
        $(".pm-auto-responder-icon").toggleClass("mmn-icon-active");
      }
    });
}

function initializeWithApi(api, siteSetting) {

  if (!siteSetting.enable_pm_auto_responder_for_admins) { return; }

  let currentUser = api.getCurrentUser();

  if (currentUser && currentUser.get('admin')) {

    ajax("/mmn_auto_respond_pm/is_enabled")
      .catch(e => {
        console.log(e);
      }).then(result => {
        const is_enabled = (result.is_enabled == "t" || result.is_enabled == true) ? true : false;
        currentUser.set("is_auto_responder_enabled", is_enabled);

        let iconClass = "";
        let iconLabel;

        if (is_enabled) {
          iconClass = "mmn-icon-active";
          iconLabel = "disable";
        } else {
          iconLabel = "enable";
        }

        api.addUserMenuGlyph({
          label: `mmn_auto_respond_pm.${iconLabel}`,
          className: `pm-auto-responder-icon ${iconClass}`,
          icon: 'power-off',
          action: "toggleAutoRespondPm"
        });
      });
  }

  api.attachWidgetAction("user-menu", 'toggleAutoRespondPm', function() {
    const { currentUser, siteSettings } = this;
    if (!siteSettings.enable_pm_auto_responder_for_admins) { return; }
    toggleAutoRespondPm(currentUser);
  });

}

export default {
  name: 'extend-for-pm-auto-responder',
  initialize(c) {
    const siteSetting = c.lookup('site-settings:main');
    withPluginApi('0.1', api => {
      initializeWithApi(api, siteSetting);
    });
  }
}