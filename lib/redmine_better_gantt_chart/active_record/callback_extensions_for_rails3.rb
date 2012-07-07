require 'active_support/basic_object'

module RedmineBetterGanttChart
  module ActiveRecord
    module CallbackExtensionsForRails3
      extend ActiveSupport::Concern

      module ClassMethods
        def with_callbacks_disabled(*callbacks, &block)
          self.skip_callback callbacks
          yield
          self.set_callback callbacks
        end

        alias_method :with_callback_disabled, :with_callbacks_disabled

        def with_all_callbacks_disabled &block
          all_callbacks = [
            :before_create,
            :before_validation,
            :before_validation_on_create,
            :before_validation_on_update,
            :before_save,
            :before_update,
            :before_destroy,
            :after_create,
            :after_validation,
            :after_validation_on_create,
            :after_validation_on_update,
            :after_save,
            :after_update,
            :after_destroy
          ]
          with_callbacks_disabled *all_callbacks, &block
        end
      end
    end
  end
end
