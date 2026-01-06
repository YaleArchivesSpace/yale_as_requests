class AeonContainerMapper < AeonRecordMapper

  # Confirm this mapper is loaded
  Rails.logger.info(
    "Aeon debug: AeonContainerMapper loaded from #{__FILE__} at #{Time.now}"
  )

  register_for_record_type(Container)

  # Decide whether to hide the request button for a top container
  def hide_button?
    Rails.logger.info(
      "Aeon debug: hide_button? triggered for #{@record.json['uri']}"
    )

    # Step 1: Run default Aeon logic
    super_result = super
    Rails.logger.info(
      "Aeon debug: super() returned #{super_result.inspect}"
    )
    return true if super_result

    # Step 2: Check container-level active_restrictions
    if container_has_no_request_restriction?
      Rails.logger.info(
        "Aeon debug: Container has NoRequest via active_restrictions — hiding button."
      )
      return true
    end

    # Step 3: Check parent resource restrictions
    if parent_resource_has_no_request_restriction?
      Rails.logger.info(
        "Aeon debug: Parent resource has NoRequest — hiding button."
      )
      return true
    end

    # Default: allow request button
    Rails.logger.info(
      "Aeon debug: No restrictions found — showing request button."
    )
    false
  end

  private

  # ---- Container-level restriction check ----
  def container_has_no_request_restriction?
    restrictions = @record.json['active_restrictions'] || []

    Rails.logger.info(
      "Aeon debug: Container #{@record.json['uri']} active_restrictions count: #{restrictions.length}"
    )

    restrictions.each do |restriction|
      types = restriction['local_access_restriction_type'] || []

      Rails.logger.info(
        "Aeon debug: Container restriction types: #{types.inspect}"
      )

      return true if types.include?(RESTRICTION_TYPE_NO_REQUEST)
    end

    false
  end

  # ---- Parent resource restriction check ----
  def parent_resource_has_no_request_restriction?
    Rails.logger.info(
      "Aeon debug: Checking parent resource for #{@record.json['uri']}"
    )

    resource = get_parent_resource

    Rails.logger.info(
      "Aeon debug: Resolved parent resource: #{resource ? resource['uri'] : 'NONE'}"
    )

    return false unless resource

    restriction_types = extract_restriction_types_from_resource(resource)
    Rails.logger.info(
      "Aeon debug: Resource restriction types: #{restriction_types.inspect}"
    )

    restriction_types.include?(RESTRICTION_TYPE_NO_REQUEST)
  end

  def get_parent_resource
    json = @record.json || {}

    resource_ref =
      if json['collection'].is_a?(Array) &&
         json['collection'].first.is_a?(Hash) &&
         json['collection'].first['ref'].is_a?(String)
        json['collection'].first['ref']
      else
        json['created_for_collection']
      end

    Rails.logger.info(
      "Aeon debug: Resolved resource_ref: #{resource_ref || 'NONE'}"
    )

    return nil unless resource_ref

    begin
      resource_response = archivesspace.get_record(resource_ref)
      return resource_response if resource_response && resource_response['json']
    rescue => e
      Rails.logger.error(
        "Aeon error: Failed to fetch resource #{resource_ref}: #{e.message}"
      )
    end

    nil
  end

  def extract_restriction_types_from_resource(resource)
    resource_json = resource['json'] || {}

    (resource_json['notes'] || [])
      .select do |note|
        note['type'] == 'accessrestrict' &&
        note.key?('rights_restriction')
      end
      .map do |note|
        note['rights_restriction']['local_access_restriction_type']
      end
      .flatten
      .uniq
  end
end