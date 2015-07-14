module ApWp

  class BaseDownloader
    attr_reader :options, :req_parallel, :down_dir, :down_name, :download_url, :archives

    def initialize(options)
      @options = options
    end

    # TODO: Refactor so we don't have to pass the "hydra" from the parallel method
    def make_request(file, url, hydra, &block)
      request = Typhoeus::Request.new(url, timeout: 15000)

      request.on_complete do |response|
        if response.success?
          block.call(response.body)
        else
          puts Rainbow("Failed to get #{url}").red
        end

        file.close
      end

      if req_parallel and hydra
        hydra.queue(request)
      else
        request.run
      end
    end

    def _download(file_path, url, hydra)
      downloaded_file = File.open("#{file_path}", "w")

      make_request(downloaded_file, url, hydra) do |body|
        downloaded_file.write(body)
      end
    end

    # TODO: Export the zip integration to it's own class.
    def _unzipit(file, show_trace)
      Zip::File.open(file) do |zip_file|
        puts Rainbow("Unziping #{file}...").blue
        zip_file.each do |entry|
          _path = File.join(Dir.pwd, entry.name)

          if show_trace
            print Rainbow("Extracting file: ").black
            puts Rainbow("#{entry.name}").cyan
          end

          FileUtils.mkdir_p(File.dirname(_path))
          zip_file.extract(entry, _path) unless File.exists? _path
        end
      end

      FileUtils.rm_rf(file)
      puts Rainbow("#{file} removed.").green
    end

    def unzipit(file_name, show_trace)
      if file_name.is_a? Array
        # Let's go parallel
        file_name.each_with_index.map do |file, i|
          Thread.new(i) do |idx|
            _unzipit(file, show_trace)
          end
        end.each do |thr|
          thr.join
        end
      else
        # Process single file
        _unzipit(file_name, show_trace)
      end
    end
  end

end
