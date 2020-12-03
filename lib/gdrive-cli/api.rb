# FIXME: double upload shouldn't be possible (same file name), but is is now.

module GDriveCLI
  class API
    class InvalidPathError < StandardError
    end

    class ErrorNotDirectory < StandardError
      attr_reader :file
      def initialize(file)
        @file = file
      end
    end

    class RemoteLocation
      def initialize(collection)
        @collection = collection
      end

      def directory?
        @collection.is_a?(GoogleDrive::Collection)
      end

      def title
        @collection.title
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

    def list(destination)
      collection = self.get_collection(destination)
      collection.files.uniq(&:title).sort_by(&:title).map do |file|
        RemoteLocation.new(file)
      end
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
end
