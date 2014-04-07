require 'google/api_client'
require 'google/api_client/auth/file_storage'
require 'google/api_client/auth/installed_app'

require File.expand_path('../file_criteria', __FILE__)

class DriveClient
  # http://www.krautcomputing.com/blog/2013/12/17/how-to-access-your-google-drive-files-with-ruby/
  def initialize(name)
    credentials_file = File.expand_path("../../tmp/google_api_credentials.#{name}.json", __FILE__)
    credentials_storage = ::Google::APIClient::FileStorage.new(credentials_file)
    @client = ::Google::APIClient.new(
      application_name: 'TreePwner',
      application_version: '1.0.0'
    )
    @client.authorization = credentials_storage.authorization || begin
      installed_app_flow = ::Google::APIClient::InstalledAppFlow.new(
        client_id: '537356659579-njv3rplj01rknispaercptnk5n91n2go.apps.googleusercontent.com',
        client_secret: 'jdV-7Kde8Yd00MB4qPiv9MGP',
        scope: 'openid email https://www.googleapis.com/auth/drive'
      )
      installed_app_flow.authorize(credentials_storage)
    end

    if @client.authorization.refresh_token &&
      @client.authorization.expired?
      puts 'refreshing access token'
      @client.authorization.fetch_access_token!
    end

    @drive = @client.discovered_api('drive', 'v2')
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
      puts "An error occurred making copies: #{result.data['error']['message']}"
    end
  end

  def trash_file(file)
    result = @client.execute(
      :api_method => @drive.files.trash,
      :parameters => {'fileId' => file.id})
    if result.status == 200
      result.data
    else
      puts "An error occurred trashing original: #{result.data['error']['message']}"
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

  def children_in_folder(folder, q=nil)
    page_token = nil
    begin
      parameters = {'folderId' => folder.id}
      if page_token.to_s != ''
        parameters['pageToken'] = page_token
      end
      parameters.merge!('q' => q) if q
      result = @client.execute(
        :api_method => @drive.children.list,
        :parameters => parameters)
      if result.status == 200
        children = result.data
        children.items.each do |child_ref|
          result = @client.execute(
            :api_method => @drive.files.get,
            :parameters => {'fileId' => child_ref.id})
          child = result.data
          yield child
        end
        page_token = children.next_page_token
      else
        raise ["An error occurred: #{result.data['error']['message']}", result.data.to_hash].join("\n")
      end
    end while page_token.to_s != ''
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
    result = @client.execute(
      api_method: @drive.files.list,
      parameters: {
        q: q,
        maxResults: max
      }
    )
    if result.status == 200
      result.data['items']
    else
      raise [result.data['error']['message'], result.data.to_hash].join("\n")
    end
  end

  def get_all_folders
    search FileCriteria.is_a_folder
  end

  def about
    # email not in here, even with it in scope. needs user endpoint somewhere ...
    @client.execute(api_method: @drive.about.get).data
  end
end