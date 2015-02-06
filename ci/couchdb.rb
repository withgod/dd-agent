require './ci/common'

# FIXME: use our own brew of couchdb

def couchdb_version
  ENV['COUCHDB_VERSION']  || '1.6.1'
end

def couchdb_rootdir
  "#{ENV['INTEGRATIONS_DIR']}/couchdb_#{couchdb_version}"
end

namespace :ci do
  namespace :couchdb do |flavor|
    task :before_install => ['ci:common:before_install']

    task :install => ['ci:common:install'] do
      unless Dir.exist? File.expand_path(couchdb_rootdir)
        sh %(curl -s -L\
             -o $VOLATILE_DIR/couchdb-#{couchdb_version}.tar.gz\
             http://mirrors.gigenet.com/apache/couchdb/source/#{couchdb_version}/apache-couchdb-#{couchdb_version}.tar.gz)
        sh %(mkdir -p #{couchdb_rootdir})
        sh %(mkdir -p $VOLATILE_DIR/couchdb)
        sh %(tar zxvf $VOLATILE_DIR/couchdb-#{couchdb_version}.tar.gz\
             -C $VOLATILE_DIR/couchdb --strip-components=1)
        sh %(cd $VOLATILE_DIR/couchdb\
             && ./configure --prefix=#{couchdb_rootdir}\
             && make\
             && make install)
      end
    end

    task :before_script => ['ci:common:before_script'] do
      sh %(#{couchdb_rootdir}/bin/couchdb -b)
    end

    task :script => ['ci:common:script'] do
      this_provides = [
        'couchdb'
      ]
      Rake::Task['ci:common:run_tests'].invoke(this_provides)
    end

    task :cleanup => ['ci:common:cleanup'] do
      sh %(#{couchdb_rootdir}/bin/couchdb -k)
    end

    task :execute do
      exception = nil
      begin
        %w(before_install install before_script script).each do |t|
          Rake::Task["#{flavor.scope.path}:#{t}"].invoke
        end
      rescue => e
        exception = e
        puts "Failed task: #{e.class} #{e.message}".red
      end
      if ENV['SKIP_CLEANUP']
        puts 'Skipping cleanup, disposable environments are great'.yellow
      else
        puts 'Cleaning up'
        Rake::Task["#{flavor.scope.path}:cleanup"].invoke
      end
      fail exception if exception
    end
  end
end
