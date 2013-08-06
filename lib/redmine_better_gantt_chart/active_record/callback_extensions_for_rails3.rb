require 'active_support/basic_object'

module RedmineBetterGanttChart
  module ActiveRecord
    module CallbackExtensionsForRails3
      extend ActiveSupport::Concern

      module ClassMethods
        def with_callbacks_disabled(*callbacks, &block)
          callback_options={}
          callback_hash= Hash[callbacks.map{|callback|
              chain = send("_#{callback}_callbacks")
              options = Hash[chain.map{|c| [c.filter,{:options=>c.options,:per_key=>c.per_key}]}]
              callback_options.reverse_merge!(options)
              chain_hash=Hash[chain.map{|c| [c.kind, chain.collect{|ch| ch.filter if ch.kind==c.kind}.compact]}]
              [callback,chain_hash]
            }
          ]
          callback_hash.each {|callback,filters|
            filters.each{|filter,methods|
              skip_callback(callback, filter, *methods)
            }
          }
          yield
          callback_hash.each {|callback,filters|
            filters.each{|filter,methods|
              methods.each{|method|
                set_callback(callback, filter, method, callback_options[method])
              }
            }
          }
        end

        alias_method :with_callback_disabled, :with_callbacks_disabled

        def with_all_callbacks_disabled &block
          all_callbacks = [
            :create,
            :validation,
            :save,
            :update,
            :destroy
          ]
          with_callbacks_disabled *all_callbacks, &block
        end
      end
    end
  end
end
