# frozen_string_literal: true

class My::NotificationSoundForm < ApplicationForm
  NotificationSoundFormModel = Data.define(:enabled, :sound)

  form do |f|
    f.fieldset_group(title: helpers.t("my_account.notifications.sound.title"),
                     description: helpers.t("my_account.notifications.sound.description"), mt: 3) do |fg|
      fg.check_box(name: :enabled, label: helpers.t("my_account.notifications.sound.enabled"))
      fg.select_list(name: :sound, label: helpers.t("my_account.notifications.sound.sound"), include_blank: false) do |list|
        %w[chime double_chime soft].each do |sound|
          list.option(label: helpers.t("my_account.notifications.sound.options.#{sound}"), value: sound)
        end
      end
      fg.submit(name: :submit, label: helpers.t("my_account.notifications.sound.submit"), scheme: :default)
    end
  end
end
