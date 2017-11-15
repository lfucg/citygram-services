require 'spy_glass/registry'
require 'digest/md5'

helper = Object.new
def helper.collection_season
  2017
end

def helper.manual_message(zone, zone_id, status, comment)
  return {} unless collection_season == 2017

  # 2016 for Pending messages so that we don't accidentally send pending again
  season_id = if status == 'Pending'
    '2016'
  else
    collection_season
  end

  comment_hash = if not comment.nil?
    Digest::MD5.hexdigest(comment)
  end

  message = if not comment.nil?
    {
      message_id: "#{season_id}_#{zone_id}_#{comment_hash}",
      message: comment
    }
  end


  # if (message)
  #   message
  # else
  #   {}
  # end

  {}

end

def helper.message(zone, zone_id, status, dates, comment)
  manual = manual_message(zone, zone_id, status, comment)

  manual[:message] ? manual : { message: nil }
end

opts = {
  path: '/lexington-leaf-collection',
  cache: SpyGlass::Cache::Memory.new(expires_in: 300),
  source: 'http://maps.lexingtonky.gov/lfucggis/rest/services/leafcollection/MapServer/1/query?where=1%3D1&text=&objectIds=&time=&geometry=&geometryType=esriGeometryEnvelope&inSR=&spatialRel=esriSpatialRelIntersects&relationParam=&outFields=*&returnGeometry=true&maxAllowableOffset=&geometryPrecision=&outSR=4326&returnIdsOnly=false&returnCountOnly=false&orderByFields=&groupByFieldsForStatistics=&outStatistics=&returnZ=true&returnM=true&gdbVersion=&returnDistinctValues=false&f=pjson'
}

SpyGlass::Registry << SpyGlass::Client::JSON.new(opts) do |esri_formatted|
  features = esri_formatted['features'].map do |feature|
    zone_id = feature['attributes']['GIS_master.DBO.LeafCollectionBoundary.OBJECTID']
    status = feature['attributes']['GIS_master.DBO.LeafZoneSchedule.Status']
    dates = feature['attributes']['GIS_master.DBO.LeafZoneSchedule.Dates']
    zone = feature['attributes']['GIS_master.DBO.LeafZoneSchedule.Zone']
    comment = feature['attributes']['GIS_master.DBO.LeafZoneSchedule.Comments']
    message_object = helper.message(zone, zone_id, status, dates, comment)
    message = message_object[:message]

    if message.nil?
      nil
    else
      {
        'type' => 'Feature',
        'id' => "#{message_object[:message_id]}",
        'zone' => zone,
        'properties' => {
          'title' => message,
        },
        'geometry' => {
          type: 'Polygon',
          coordinates: feature['geometry']['rings']
         }
      }
    end
  end

  { 'type' => 'FeatureCollection', 'features' => features.compact }
end

opts[:path] = '/lexington-leaf-collection-citygram-events-format'

SpyGlass::Registry << SpyGlass::Client::JSON.new(opts) do |esri_formatted|
  features = esri_formatted['features'].map do |feature|
    object_id = feature['attributes']['GIS_master.DBO.LeafCollection.OBJECTID']
    status = feature['attributes']['GIS_master.DBO.LeafZoneSchedule.Status']
    dates = feature['attributes']['GIS_master.DBO.LeafZoneSchedule.Dates']
    # necessary if any of the statuses from this year are the same as their last status from prev year
    collection_season = '2016'
    title =  "Hello! Leaf collection begins soon. For more information please visit https://lexingtonky.gov/leaves"

    {
      'type' => 'Feature',
      'feature_id' => "#{collection_season}_#{object_id}_#{status}",
      'title' => helper.title(status, dates),
      'status' => feature['attributes']['GIS_master.DBO.LeafZoneSchedule.Zone'],
      'properties' => {
        'title' => helper.title(status, dates)
      },
      'geom' => JSON.generate({
        type: 'Polygon',
        coordinates: feature['geometry']['rings']
      })
    }
  end

  features
end