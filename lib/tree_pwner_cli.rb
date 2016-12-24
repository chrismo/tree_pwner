require_relative 'tree_pwner'

class TreePwnerCli
  attr_reader :tp

  def initialize(*args)
    super
    @tp = TreePwner.new
    # To get these, you have to download a client_secret.json from Dev Tools and
    # all - see
    # https://developers.google.com/drive/v3/web/quickstart/ruby#step_1_turn_on_the_api_name
    @tp.connect_source('the.chrismo@gmail.com')
    @tp.connect_target('chrismo@clabs.org')
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

  def help
    puts 'help                   -- Display this help'
    puts 'connect_source [email] -- Connect source to email account'
    puts 'connect_target [email] -- Connect target to email account'
    puts 'open [folder name]     -- Show folders in [folder name]. Use "root" name to go back to the top.'
    puts 'scan [folder name]     -- Scan folder name hierarchy for files to transfer ownership of.'
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

  def open_source_root
    @current_root = 'root'
    load_current_root_sub_folders(@tp.source_client)
  end

  def open_target_root
    @current_root = 'root'
    load_current_root_sub_folders(@tp.target_client)
  end

  def source_disk_usage(folder_name=@current_root)
    folder = get_folder_obj(folder_name, @tp.source_client)
    @tp.source_client.disk_usage(folder)
  end

  def target_disk_usage(folder_name=@current_root)
    folder = get_folder_obj(folder_name, @tp.target_client)
    @tp.target_client.disk_usage(folder)
  end

  def scan(folder_name)
    unless changed_mind_after_detected_trashed_files
      @tp.copy_and_replace_all_files_owned_by_source folder_name
    end
    self
  end

  def changed_mind_after_detected_trashed_files
    trashed = @tp.source_client.search(FileCriteria.trashed)
    if trashed.length > 0
      print "#{trashed.length} files in #{client_email(@tp.source_client)} Trash. Continue? (y/N): "
      !(gets.chomp =~ /y/)
    else
      false
    end
  end

  private

  def load_current_root_sub_folders(client=@tp.target_client)
    folder = get_folder_obj(@current_root, client)

    @sub_folders = []
    q = DriveQuery.new(FileCriteria.is_a_folder).and(FileCriteria.not_trashed)
    client.children_in_folder(folder, q) do |child_folder|
      @sub_folders << child_folder
    end
  end

  def get_folder_obj(folder_name, client=@tp.target_client)
    if folder_name == 'root' # special alias
      folder = client.root
    else
      q = DriveQuery.new(FileCriteria.is_a_folder).and(FileCriteria.not_trashed)
      q.and("name = '#{folder_name}'")
      folder = client.search(q).first
    end
    folder
  end
end
