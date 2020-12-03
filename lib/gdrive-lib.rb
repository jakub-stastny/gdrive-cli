require 'google_drive'

# TODO: double upload shouldn't be possible (same file name), but is is now.
class CLI
  class InvalidPathError < StandardError
  end

  class ErrorNotDirectory < StandardError
    attr_reader :file
    def initialize(file)
      @file = file
    end
  end

  # This has to be a file, so it can be updated with scope and refresh token (automatically).
  def self.ensure_credentials_file(credentials_file_path)
    unless File.file?(credentials_file_path)
      id = ENV.fetch('GDRIVE_CLIENT_ID')
      secret = ENV.fetch('GDRIVE_CLIENT_SECRET')

      File.open(credentials_file_path, 'w') do |file|
        file.puts({client_id: id, client_secret: secret}.to_json)
      end
    end
  end

  # Creates a session. This will prompt the credential via command line for the
  # first time and save it to config.json file for later usages.
  # See this document to learn how to create config.json:
  # https://github.com/gimite/google-drive-ruby/blob/master/doc/authorization.md
  def self.build(credentials_file_path)
    self.new(GoogleDrive::Session.from_config(credentials_file_path))
  end

  def initialize(session)
    @session = session
  end

  def command_list(destination)
    collection = self.get_collection(destination)
    collection.files.uniq(&:title).sort_by(&:title).each do |file|
      puts file.is_a?(GoogleDrive::Collection) ? "#{`tput setaf 4`}#{file.title}#{`tput sgr0`}" : file.title
    end
  rescue ErrorNotDirectory => error # If given path points to a file, show more details.
    p error.file
  rescue Interrupt
    puts
  end

  def command_find(destination)
    self.find(self.get_collection(destination))
  rescue ErrorNotDirectory => error # If given path points to a file, show more details.
    p error.file
  rescue Interrupt
    puts
  end

  # FIXME: Doesn't work.
  def command_search(title)
    drive_service = @session.instance_variable_get(:@fetcher).drive
    query = "title contains '#{ARGV.first}'"
    puts "Query: #{query}"
    files = drive_service.list_files(q: query)
    files.items.each do |file|
      puts file.title
    end
  rescue Interrupt
    puts
  end

  def command_cat(remote_path)
    remote_path, local_path = ARGV
    local_path ||= File.basename(remote_path)
    file = self.find_file(remote_path)
    file || abort("File #{remote_path} not found")
    if file.is_a?(GoogleDrive::Collection)
      abort "File #{remote_path} is a directory"
    else
      puts file.download_to_string
    end
  rescue Interrupt
    puts
  end

  def command_download(remote_path, local_path = File.basename(remote_path))
    puts "~ Downloading '#{remote_path}' to #{local_path}"
    download(remote_path, local_path)
  rescue Interrupt
    puts
  end

  # Upload to WIP:
  # upload song.mp3 song2.mp3
  # upload song.mp3 song2.mp3 -- songs
  def command_upload(*args)
    if separator_index = args.index('--')
      local_paths = args[0..(separator_index - 1)]
      remote_paths = args[(separator_index + 1)..-1]
      if remote_path.length != 1
        abort "x"
      end
      remote_path = remote_paths.first
    else
      local_paths = args
      remote_path = local_paths.length == 1 ? local_paths.first : 'WIP'
    end
    require 'pry'; binding.pry ###
local_path, remote_path = "/#{File.basename(local_path)}"
    # If path is given as relative, File.dirname(remote_path) returns '.' and
    # self.find_file returns nil.
    remote_path = "/#{remote_path}" unless remote_path.start_with?('/')

    puts "~ Uploading '#{local_path}' to #{remote_path}"
    file = @session.upload_from_file(local_path, File.basename(remote_path), convert: false)

    # File is always uploaded to the root_collection by default.
    # https://github.com/gimite/google-drive-ruby/issues/260
    unless self.find_file(File.dirname(remote_path)) == @session.root_collection
      require 'pry'; binding.pry ###
      self.find_file(File.dirname(remote_path)).add(file)
      @session.root_collection.remove(file)
    end
  rescue Interrupt
    puts
  end

  def command_mkdir(remote_path)
    *dirnames, basename = ARGV.first.split('/')
    collection = dirnames.empty? ? @session.root_collection : self.find_file(dirnames.join('/'))
    collection.create_subcollection(ARGV.first.split('/').last)
  rescue Interrupt
    puts
  end

  def command_remove(remote_path)
    puts "~ Deleting '#{ARGV.first}'"
    file = self.find_file(ARGV.first)
    file.delete(true)
  rescue Interrupt
    puts
  end

  protected
  def get_collection(destination)
    result = destination.nil? || destination == '/' ? @session.root_collection : self.find_file(destination.sub(/^\//, ''))
    raise InvalidPathError if result.nil?
    raise ErrorNotDirectory.new(result) unless result.respond_to?(:create_subcollection)
    result
  end

  def find_file(full_path)
    full_path.split('/').reduce(@session.root_collection) do |parent, file_name|
      parent.file_by_title(file_name)
    end
  end

  def download(remote_path, local_path)
    file = self.find_file(remote_path)
    file || abort("File #{remote_path} not found")
    if file.is_a?(GoogleDrive::Collection)
      Dir.mkdir(local_path)
      Dir.chdir(local_path) do
        file.files.each do |file|
          download(file)
        end
      end
    else
      file.download_to_file(local_path)
    end
  rescue NotImplementedError
    # This will want the format to be specified most likely.
    #
    # file.export_as_file(local_path)
    binding.pry
  end

  def find(collection, dirname = nil)
    collection.files.uniq(&:title).sort_by(&:title).each do |file|
      if file.is_a?(GoogleDrive::Collection)
        self.find(file, [dirname, file.title].compact.join('/'))
      else
        puts [dirname, file.title].compact.join('/')
      end
    end
  end
end
