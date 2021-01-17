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
        # remote_path = local_paths.length == 1 ? local_paths.first : 'WIP'
        remote_path = 'WIP'
      end

      @client.upload(local_paths, remote_path)
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
