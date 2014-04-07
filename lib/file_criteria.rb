# surely some fluent api fun to be had here
class FileCriteria
  def self.is_a_folder
    'mimeType = "application/vnd.google-apps.folder"'
  end

  def self.is_not_a_folder
    'mimeType != "application/vnd.google-apps.folder"'
  end

  def self.i_own
    '"me" in owners'
  end

  def self.not_trashed
    'trashed = false'
  end

  def self.trashed
    'trashed = true'
  end
end