require 'ostruct'

require File.expand_path('../../lib/drive_client', __FILE__)

describe DriveClient do
  def make_fake_result_with_error(msg)
    OpenStruct.new(data: {'error' => {'message' => msg}})
  end

  it 'should handle rate limit error' do
    c = DriveClient.new(nil, nil)
    result = make_fake_result_with_error('Rate Limit Exceeded')
    expect { c.handle_error('foo', result) }.to raise_error RateLimitExceeded
  end

  it 'should just output other error' do
    c = DriveClient.new(nil, nil)
    result = make_fake_result_with_error('other error')
    expect { c.handle_error('foo', result) }.to_not raise_error
  end
end
