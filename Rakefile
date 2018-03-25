task :install_with_h2o do
  h2o_path = ENV["H2O_PATH"] || "/tmp/h2o"
  install_path = "/usr/local"
  if File.writable?(install_path)
    unless File.exist?("/tmp/h2o.tar.gz")
      puts "Download h2o"
      sh "curl -s -L -o /tmp/h2o.tar.gz https://github.com/h2o/h2o/archive/v2.2.4.tar.gz", verbose: false
    end

    puts "Extract h2o"
    FileUtils.mkdir_p h2o_path
    Dir.chdir h2o_path do
      sh "tar xzf /tmp/h2o.tar.gz", verbose: false
    end

    puts "Copy mruby-mwaf in h2o deps"
    sh "cp -fr . #{h2o_path}/h2o-2.2.4/deps/mruby-mwaf", verbose: false

    puts "Compile h2o (can take some times)"
    Dir.chdir "#{h2o_path}/h2o-2.2.4" do
      sh "cmake -DEXTRA_LIBS=\"-lsqlite3 -ldl\" . > /dev/null;make --quiet -j8 > /dev/null 2>&1", verbose: false
    end

    puts "Install h2o in #{install_path}"
    Dir.chdir "#{h2o_path}/h2o-2.2.4" do
      sh "make install", verbose: false
    end
    # add binaries for project creation
    FileUtils.mkdir_p "#{install_path}/share/h2o/mruby/bin"
    sh "cp #{h2o_path}/h2o-2.2.4/mruby/host/bin/mruby #{install_path}/share/h2o/mruby/bin/"
    sh "cp #{h2o_path}/h2o-2.2.4/mruby/host/bin/mirb #{install_path}/share/h2o/mruby/bin/"
    sh "cp bin/mwaf #{install_path}/bin/"
  else
    puts "Error: you must have write permission to #{install_path}"
  end
end
