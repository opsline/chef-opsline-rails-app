module Opsline
  module RailsApp
    module Helpers


      def get_env_value(element)
        if element.is_a?(Hash)
          if element.has_key?(node.chef_environment)
            element[node.chef_environment]
          elsif element.has_key?('default')
            element['default']
          else
            {}
          end
        else
          element
        end
      end


    end
  end
end

