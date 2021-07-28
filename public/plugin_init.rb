Plugins::extend_aspace_routes(File.join(File.dirname(__FILE__), "routes.rb"))

## Register our custom page action
record_types = AppConfig.has_key?(:aeon_fulfillment_record_types) ? AppConfig[:aeon_fulfillment_record_types]
                                                                  : ['archival_object', 'accession', 'resource']

button_position = AppConfig.has_key?(:aeon_fulfillment_button_position) ? AppConfig[:aeon_fulfillment_button_position] : nil

Plugins::add_record_page_action_erb(record_types,
                                    'aeon/aeon_request_action',
                                    button_position)

Rails.application.config.after_initialize do
  begin
    StatusUpdater
  rescue
    # asam isn't active so fake StatusUpdater
    class StatusUpdater
      def self.method_missing(meth, *args)
        Rails.logger.debug("asam not active, so ignoring: StatusUpdater: ##{meth}(#{args.join(', ')})")
      end
    end
  end


  AeonRecordMapper.class_eval do
    class << self
      alias_method(:mapper_for_original, :mapper_for)
    end

    def self.mapper_for(record)
      begin
        mapper_for_original(record)
      rescue => e
        StatusUpdater.update('Yale Aeon Errors', :bad, e.message)
        raise e
      end
    end
  end
end
