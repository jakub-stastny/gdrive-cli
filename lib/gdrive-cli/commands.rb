module GDriveCLI
  class CLI
    def initialize(client)
      @client = client
    end

    def command_list(destination)
      @client.list(destination).each do |location|
        puts location.directory? ? "#{`tput setaf 4`}#{location.title}#{`tput sgr0`}" : location.title
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
  end
end
