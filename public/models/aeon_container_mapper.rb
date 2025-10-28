class AeonContainerMapper < AeonRecordMapper
  register_for_record_type(Container)

  # Override hide_button? to check parent resource restrictions
  def hide_button?
    # First check the standard restrictions on the container itself
    return true if super
    
    # For containers, also check if the parent resource has "No Request" restriction
    return true if parent_resource_has_no_request_restriction?
    
    false
  end

private

  def parent_resource_has_no_request_restriction?
    Rails.logger.info("Aeon debug: Checking container #{@record.json['uri']} for NoRequest restriction")

    # Get the parent resource from the container
    resource = get_parent_resource
    Rails.logger.info("Aeon debug: Container #{@record.json['uri']} - Parent resource: #{resource ? resource['uri'] : 'NONE'}")

    return false unless resource
    
    # Check if the resource has "No Request" restriction in its access restrict notes
    resource_restriction_types = extract_restriction_types_from_resource(resource)
    has_no_request = resource_restriction_types.include?(RESTRICTION_TYPE_NO_REQUEST)
    
    Rails.logger.info("Aeon debug: Parent resource restrictions: #{resource_restriction_types}, Has NoRequest: #{has_no_request}")
    Rails.logger.info("Aeon debug: Final result - hiding request buttons: #{has_no_request}")
    
    has_no_request
  end

  def get_parent_resource
    # For containers, the parent resource is referenced in created_for_collection
    collection_uri = @record.json['created_for_collection']
    return nil unless collection_uri
    
    begin
      # Fetch the resource record
      resource_response = archivesspace.get_record(collection_uri)
      return resource_response if resource_response && resource_response['json']
    rescue => e
      Rails.logger.error("Aeon Fulfillment Plugin") { "Failed to fetch parent resource #{collection_uri}: #{e.message}" }
      return nil
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