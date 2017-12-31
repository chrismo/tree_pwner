# TODO: allow this to make one pass and sort by owner
class FolderData
  attr_reader :folders, :folder, :size

  def initialize(client, folder)
    @client = client
    @folder = folder
    @folders = []
  end

  def calculate_size(visited_folders=[])
    puts "Calculating #{@folder.name}..."
    visited_folders << @folder
    folders, files = [[], []]
    @client.children_in_folder(@folder) do |f|
      if f.mime_type == FileCriteria.folder_mime_type
        folders << f
      elsif f.owned_by_me
        files << f
      else
        # ignore the file
      end
    end
    @size = files.map { |f| f.size.to_i }.reduce(&:+)
    @folders = folders.map { |_folder| FolderData.new(@client, _folder) }
    @folders.each do |fd|
      fd.calculate_size(visited_folders) unless visited_folders.map(&:id).include?(fd.folder.id)
    end
  end

  def recursive_size(format: nil)
    result = [size, @folders.map { |f| f.recursive_size }].flatten.compact.reduce(&:+)
    if format =~ /\bh/
      as_size(result)
    else
      result
    end
  end

  # TODO - rename and add sorting options (default to size desc)
  def dump(indent: 0, depth: nil, current_depth: 0)
    rock_bottom = (depth == current_depth)
    display_size = rock_bottom ? recursive_size : size
    return if rock_bottom && display_size.to_i == 0
    number, label = as_size(display_size).split(' ')
    puts "#{number.rjust(5)} #{label.ljust(5)} #{' ' * indent} #{folder.name}"

    unless rock_bottom
      @folders.each do |f|
        f.dump(indent: indent + 2, depth: depth, current_depth: current_depth + 1)
      end
    end
  end

  def drill_to(child_folder_name)
    @folders.detect {|f| f.folder.name == child_folder_name }
  end

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

## copied this out to experiment with re-designing it so it can handle sorting
## by size.
# class FolderData
#   def output(indent: 0, depth: nil, current_depth: 0)
#     rock_bottom = (depth == current_depth)
#     display_size = rock_bottom ? recursive_size : size
#     return if rock_bottom && display_size.to_i == 0
#     number, label = as_size(display_size).split(' ')
#     puts "#{number.rjust(5)} #{label.ljust(5)} #{' ' * indent} #{folder.name}"
#
#     unless rock_bottom
#       @folders.each do |f|
#         f.dump(indent: indent + 2, depth: depth, current_depth: current_depth + 1)
#       end
#     end
#   end
# end