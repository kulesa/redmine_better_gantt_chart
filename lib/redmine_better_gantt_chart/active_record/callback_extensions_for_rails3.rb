require 'active_support/basic_object'

module RedmineBetterGanttChart
  module ActiveRecord
    module CallbackExtensionsForRails3
      extend ActiveSupport::Concern

      module ClassMethods
        def with_callbacks_disabled(*callbacks, &block)
          callbacks.each {|callback|
            self.skip_callback(callback)
          }
          yield
          callbacks.each {|callback|
            self.set_callback(callback)
          }
        end

        alias_method :with_callback_disabled, :with_callbacks_disabled

        def with_all_callbacks_disabled &block
          all_callbacks = [
            :create,
            :validation,
            :save,
            :update,
            :destroy,
          ]
          with_callbacks_disabled *all_callbacks, &block
        end
      end
    end
  end
end
