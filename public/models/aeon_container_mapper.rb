class AeonContainerMapper < AeonRecordMapper

  # Check this class actually loads
  Rails.logger.info("Aeon debug: mapper loaded from #{__FILE__} (timestamp: #{Time.now})")

  register_for_record_type(Container)

  # Override hide_button? to check parent resource restrictions
  def hide_button?
    # Log entry to confirm this method runs
    Rails.logger.info("Aeon debug: hide_button? called for #{@record.json['uri']}")

    # Check standard container-level restrictions first
    super_result = super
    Rails.logger.info("Aeon debug: super() returned #{super_result.inspect}")
    return true if super_result

    # Then check parent resource restriction
    return true if parent_resource_has_no_request_restriction?

    false
  end

  private

  def parent_resource_has_no_request_restriction?
    Rails.logger.info("Aeon debug: Checking container #{@record.json['uri']} for NoRequest restriction")

    resource = get_parent_resource
    Rails.logger.info("Aeon debug: Container #{@record.json['uri']} - Parent resource: #{resource ? resource['uri'] : 'NONE'}")

    return false unless resource

    # Extract restriction note types
    resource_restriction_types = extract_restriction_types_from_resource(resource)
    has_no_request = resource_restriction_types.include?(RESTRICTION_TYPE_NO_REQUEST)

    Rails.logger.info("Aeon debug: Parent resource restrictions: #{resource_restriction_types}, Has NoRequest: #{has_no_request}")
    Rails.logger.info("Aeon debug: Final result - hiding request buttons: #{has_no_request}")

    has_no_request
  end

  def get_parent_resource
    json = @record.json || {}

    # Prefer 'collection' array; fall back to legacy 'created_for_collection'
    resource_ref =
      if json['collection'].is_a?(Array) &&
         json['collection'].first.is_a?(Hash) &&
         json['collection'].first['ref'].is_a?(String)
        json['collection'].first['ref']
      else
        json['created_for_collection']
      end

    Rails.logger.info("Aeon debug: resolved parent resource ref: #{resource_ref || 'NONE'}")

    return nil unless resource_ref

    begin
      resource_response = archivesspace.get_record(resource_ref)
      return resource_response if resource_response && resource_response['json']
    rescue => e
      Rails.logger.error("Aeon Fulfillment Plugin") { "Failed to fetch parent resource #{resource_ref}: #{e.message}" }
    end

    nil
  end

  def extract_restriction_types_from_resource(resource)
    resource_json = resource['json'] || {}

    (resource_json['notes'] || [])
      .select { |n| n['type'] == 'accessrestrict' && n.has_key?('rights_restriction') }
      .map { |n| n['rights_restriction']['local_access_restriction_type'] }
      .flatten
      .uniq
  end
end