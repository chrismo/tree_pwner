require 'google/apis/drive_v3'
require 'googleauth'
require 'googleauth/stores/file_token_store'

require_relative 'file_criteria'

class RateLimitExceeded < RuntimeError
end

class DriveClient
  OOB_URI = 'urn:ietf:wg:oauth:2.0:oob'

  def self.connect(name, user_id)
    tmp_dir = File.expand_path('../tmp', __dir__)
    credentials_file = File.join(tmp_dir, "client_secret.#{user_id}.json")
    client_id = ::Google::Auth::ClientId.from_file(credentials_file)
    token_store = Google::Auth::Stores::FileTokenStore.new(:file => File.join(tmp_dir, 'tokens.yaml'))
    scope = Google::Apis::DriveV3::AUTH_DRIVE
    authorizer = Google::Auth::UserAuthorizer.new(client_id, scope, token_store)

    credentials = authorizer.get_credentials(user_id)
    if credentials.nil?
      url = authorizer.get_authorization_url(base_url: OOB_URI)
      puts "Open #{url} in your browser and enter the resulting code:"
      code = gets
      credentials = authorizer.get_and_store_credentials_from_code(
        user_id: user_id, code: code, base_url: OOB_URI)
    end

    drive = Google::Apis::DriveV3::DriveService.new
    drive.client_options.application_name = 'TreePwner'
    drive.authorization = credentials

    self.new(drive, user_id)
  end

  attr_reader :root

  def initialize(drive, user_id)
    @drive = drive
    @root = @drive.get_file('root')
    @user_id = user_id
  end

  def copy_file(origin_file)
    copied_file = @drive.files.copy.request_schema.new(
      {
        'title' => origin_file.title,
        'modifiedDate' => origin_file.to_hash['modifiedDate']
      })
    result = @client.execute(
      :api_method => @drive.files.copy,
      :body_object => copied_file,
      :parameters => {'fileId' => origin_file.id})
    if result.status == 200
      return result.data
    else
      handle_error("copying file #{origin_file.title}", result)
    end
  end

  def trash_file(file)
    result = @client.execute(
      :api_method => @drive.files.trash,
      :parameters => {'fileId' => file.id})
    if result.status == 200
      result.data
    else
      handle_error("trashing file #{file.title}", result)
    end
  end

  def handle_error(description, result)
    if result.data['error'] && result.data['error']['message']
      message = result.data['error']['message']
      if message =~ /Rate Limit Exceeded/
        raise RateLimitExceeded, result.data, caller
      else
        raise "An error occurred #{description}: #{message}"
      end
    else
      # some calling methods check for status 200 only, but other 2xx can be
      # returned with no ['error']['message']
      raise ["An unexpected result status occurred <#{result.status}>", result.data.to_hash].join("\n")
    end
  end

  # limited to folders and Google Docs - excludes uploaded files
  def give_file_ownership_to_email(file_id, email)
    hash = {
      'value' => email,
      'type' => 'user',
      'role' => 'owner'
    }
    new_permission = @drive.permissions.insert.request_schema.new(hash)
    result = @client.execute(
      :api_method => @drive.permissions.insert,
      :body_object => new_permission,
      :parameters => {'fileId' => file_id})
    if result.status == 200
      result.data
    else
      puts "An error occurred: #{result.data['error']['message']}"
    end
  end

  def find_folder_by_title(title)
    results = search("title = \"#{title}\" and #{FileCriteria.is_a_folder}")
    results.length == 1 ? results.first : results
  end

  def children_in_folder(folder, q=DriveQuery.new)
    page_token = nil
    q.and("'#{folder.id}' in parents")
    begin
      result = @drive.list_files(
        q: q.to_s, page_token: page_token,
        fields: 'files(id,name),next_page_token'
      )
      result.files.each { |file| yield file }
      page_token = result.next_page_token
    end while page_token
  end

  def remove_root_parent_from_all_folders
    all_folders = get_all_folders
    puts "Found #{all_folders.length} folders"
    all_folders.each { |folder| remove_root_parent_if_other_parent_exists(folder) }
  end

  def remove_root_parent_if_other_parent_exists(folder)
    if folder.parents.map(&:isRoot).include?(true) && folder.parents.length > 1
      root_parent = folder.parents.detect { |f| f.isRoot }
      result = @client.execute(
        :api_method => @drive.parents.delete,
        :parameters => {
          'fileId' => folder.id,
          'parentId' => root_parent.id})
      if result.status > 299
        puts "An error occurred removing parent folder: #{result.data['error']['message']}"
      end
      puts "#{folder.title} no longer child of root"
    else
      puts "#{folder.title} is not a child of root"
    end
  end

  def search(q, max=1000)
    result = @drive.list_files(q: q.to_s, fields: 'files(id,name),next_page_token')
    result.files
  end

  def get_all_folders
    search FileCriteria.is_a_folder
  end

  def email_address
    @user_id
  end
end

class DriveQuery
  def initialize(q='')
    @query = q
    self
  end

  def and(q)
    @query.empty? ? @query = q : @query << " and #{q}"
    self
  end

  def to_s
    @query
  end
end
