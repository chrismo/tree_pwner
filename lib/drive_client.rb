require 'google/apis/drive_v3'
require 'googleauth'
require 'googleauth/stores/file_token_store'

require_relative 'disk_usage'
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

  def copy_file(src_file)
    file = Google::Apis::DriveV3::File.new(modified_time: src_file.modified_time.rfc3339)
    @drive.copy_file(src_file.id, file)
  end

  def trash_file(file)
    # @drive.delete_file(file.id) <- permanent delete
    params = Google::Apis::DriveV3::File.new(trashed: true)
    @drive.update_file(file.id, params)
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

  # This errors when trying it between domains:
  # - invalidSharingRequest: Bad Request. User message: "ACL change not allowed"
  #
  # This errors when trying it within the same domain, somesuch user didn't have rights
  # to do it - which makes no sense to me. But, my guess is this feature is only
  # supported for transfer within domain users, and some indications on the web
  # agree with that. Sad face.
  def transfer_ownership_to(file, email)
    recipient_permission = file.permissions.detect { |p| p.email_address == email }

    # code isn't designed to ADD a permission for this new user.
    raise "Cannot find <#{email}> in current users on file" unless recipient_permission

    # This next line doesn't work - "The resource body includes fields which are not directly writable"
    # recipient_permission.role = 'owner'
    # So - have to create a new permission instance and just set the one field.
    new_perm = Google::Apis::DriveV3::Permission.new(id: recipient_permission.id,
                                                     role: 'owner')

    @drive.update_permission(file.id, recipient_permission.id, new_perm, transfer_ownership: true)
  end

  # limited to folders and Google Docs - excludes uploaded files
  def give_file_ownership_to_email(file_id, email)
    raise 'not v3 compatible'
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
    q = DriveQuery.new("name = \"#{title}\"").and(FileCriteria.is_a_folder)
    results = search(q)
    results.length == 1 ? results.first : results
  end

  def children_in_folder(folder, q=DriveQuery.new)
    children = []
    page_token = nil
    q.and("'#{folder.id}' in parents").and(FileCriteria.not_trashed)
    begin
      result = @drive.list_files(
        q: q.to_s, page_token: page_token, fields: default_fields
      )
      result.files.each do |file|
        yield file if block_given?
        children << file
      end
      page_token = result.next_page_token
    end while page_token
    children
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

  def search(q)
    result = @drive.list_files(q: q.to_s, fields: default_fields)
    result.files
  end

  def default_fields
    'files(id,name,permissions,size,mimeType,shared,ownedByMe,modifiedTime),next_page_token'
  end

  def get_all_folders
    search FileCriteria.is_a_folder
  end

  def email_address
    @user_id
  end

  def disk_usage(folder)
    FolderData.new(self, folder).tap { |f| f.calculate_size }
  end

  private

  # from http://codereview.stackexchange.com/questions/9107/printing-human-readable-number-of-bytes
  def as_size(s)
    prefix = %W(TiB GiB MiB KiB B)
    s = s.to_f
    i = prefix.length - 1
    while s > 512 && i > 0
      s /= 1024
      i -= 1
    end
    ((s > 9 || s.modulo(1) < 0.1 ? '%d' : '%.1f') % s) + ' ' + prefix[i]
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
