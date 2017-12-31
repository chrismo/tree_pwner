require 'ostruct'

require File.expand_path('../../lib/drive_client', __FILE__)

describe DriveClient do
  def make_fake_result_with_error(msg)
    OpenStruct.new(data: {'error' => {'message' => msg}})
  end
end
