require File.expand_path('../../lib/tree_pwner', __FILE__)

class TreePwnerCli
  attr_reader :tp

  def initialize(*args)
    super
    @tp = TreePwner.new
    open('root')
  end

  def pretty_inspect
    puts @current_root
    @sub_folders.sort { |a, b| a.title <=> b.title }.each { |f| puts "+- #{f.title}" }
    ['hello!', "Type help if you're lost"].sample
  end

  def help
    puts 'help               -- Display this help'
    puts 'open [folder name] -- Show folders in [folder name]. Use "root" name to go back to the top.'
    puts 'scan [folder name] -- Scan folder name hierarchy for files to transfer ownership of.'
  end

  def open(folder_name)
    @current_root = folder_name
    load_current_root_sub_folders
    self
  end

  def scan(folder_name)
    @tp.copy_and_replace_all_files_owned_by_source folder_name
    self
  end

  private

  def load_current_root_sub_folders
    if @current_root == 'root' # special alias
      folder = OpenStruct.new(:id => 'root')
    else
      folder = @tp.target_client.search(["title = \"#{@current_root}\"", FileCriteria.is_a_folder, FileCriteria.not_trashed].join(' and ')).first
    end

    @sub_folders = []
    q = [FileCriteria.is_a_folder, FileCriteria.not_trashed].join(' and ')
    @tp.target_client.children_in_folder(folder, q) do |child_folder|
      @sub_folders << child_folder
    end
  end

end