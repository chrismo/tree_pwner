require_relative 'tree_pwner'
require_relative 'trash_manager'

class TreePwnerCli
  attr_reader :tp

  def initialize(*args)
    super
    @tp = TreePwner.new
    @tp.connect_source('chrismo@clabs.org')
    @tp.connect_target('the.chrismo@gmail.com')
  end

  def pretty_inspect
    puts "Source: #{client_email(@tp.source_client)}"
    puts "Target: #{client_email(@tp.target_client)}"
    if @current_root && @sub_folders
      puts @current_root
      @sub_folders.sort { |a, b| a.name <=> b.name }.each { |f| puts "+- #{f.name}" }
    end
    ['hello!', "Type help if you're lost"].sample
  end

  def client_email(client)
    client.nil? ? 'No client connected' : client.email_address
  end

  def commands
    puts 'commands                                  -- Display this help'
    puts 'open [folder name]                        -- Show folders in [folder name]. Use "root" name to go back to the top.'
    puts '                                             Use forward slash to denote an arbitrary path of folders'
    puts 'open_source_root                          -- Open source/target account root folder'
    puts 'open_target_root'
    puts 'open_source [folder]                      -- Open source/target account folder by name. If multiple '
    puts 'open_target [folder]                         folders have same name, result is not deterministic.'
    puts 'source_disk_usage                         -- Returns a FolderData root of all of the space used in the'
    puts 'target_disk_usage                            source/target folder.'
    puts 'make_target_owner_of_current_folder_files -- Self-explanatory.'
    puts '--'
    puts 'connect_source [email] -- Connect source to email account. Automatically done on initialize.'
    puts 'connect_target [email] -- Connect target to email account. Automatically done on initialize.'
  end

  def connect_source(user_id)
    @tp.connect_source(user_id)
  end

  def connect_target(user_id)
    @tp.connect_target(user_id)
  end

  def open(folder_name)
    @current_root = folder_name
    load_current_root_sub_folders
    self
  end

  def open_source(folder_name)
    @current_root = folder_name
    load_current_root_sub_folders(@tp.source_client)
    self
  end

  def open_source_root
    @current_root = 'root'
    load_current_root_sub_folders(@tp.source_client)
  end

  def open_target_root
    @current_root = 'root'
    load_current_root_sub_folders(@tp.target_client)
  end

  def source_disk_usage
    @tp.source_client.disk_usage(@current_folder)
  end

  def target_disk_usage
    @tp.target_client.disk_usage(@current_folder)
  end

  # children_in_folder doesn't filter on owner, so either client will do
  def current_folder_files
    @tp.source_client.children_in_folder(@current_folder).map(&:name)
  end

  def make_target_owner_of_current_folder_files
    unless changed_mind_after_detected_trashed_files
      @tp.copy_and_replace_all_files_owned_by_source @current_folder
    end
    self
  end

  def changed_mind_after_detected_trashed_files
    trashed = @tp.source_client.search(FileCriteria.trashed, non_pagination_ack: true)
    if trashed.length > 0
      print "#{trashed.length} files in #{client_email(@tp.source_client)} Trash. Continue? (y/N): "
      !(gets.chomp =~ /y/)
    else
      false
    end
  end

  def verify_source_trash_found_in_target(safe_perma_delete: false)
    TrashManager.new(@tp.source_client, @tp.target_client).
      cleanup_trash_with_target_copy(safe_perma_delete: safe_perma_delete)
  end

  private

  def load_current_root_sub_folders(client=@tp.target_client)
    @sub_folders = []
    q = DriveQuery.new(FileCriteria.is_a_folder).and(FileCriteria.not_trashed)
    client.children_in_folder(@current_folder = get_folder_obj(@current_root, client), q) do |child_folder|
      @sub_folders << child_folder
    end
    @current_root = @current_folder.name
  end

  def get_folder_obj(folder_name, client=@tp.target_client)
    client.get_folder_by_name_path(folder_name)
  end
end
