module RedmineBetterGanttChart
  module ActiveRecord
    module CallbackExtensionsForRails2

      def self.included(base) #:nodoc:
        base.extend ClassMethods

        base.class_eval do
          alias_method_chain :callback, :switch
          class_inheritable_accessor :disabled_callbacks
          self.disabled_callbacks = []  # set default to empty array
        end
      end

      # overloaded callback method with hook to disable callbacks
      def callback_with_switch(method)
        self.disabled_callbacks ||= []  # FIXME: this is a hack required because we don't inherit the default [] from AR::Base properly?!
        if self.disabled_callbacks.include?( method.to_s ) # disable hook
          return true
        else
          callback_without_switch(method)
        end
      end

      module ClassMethods
        def with_callbacks_disabled(*callbacks, &block)
          self.disabled_callbacks = [*callbacks.map(&:to_s)]
          yield
          self.disabled_callbacks = [] # old_value
        end

        alias_method :with_callback_disabled, :with_callbacks_disabled

        def with_all_callbacks_disabled &block
          all_callbacks = %w[
            before_create
            before_validation
            before_validation_on_create
            before_validation_on_update
            before_save
            before_update
            before_destroy
            after_create
            after_validation
            after_validation_on_create
            after_validation_on_update
            after_save
            after_update
            after_destroy
          ]
          with_callbacks_disabled *all_callbacks, &block
        end
      end
    end
  end
end
