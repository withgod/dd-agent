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
             -o $VOLATILE_DIR/erlang.tar.gz\
             http://www.erlang.org/download/otp_src_17.4.tar.gz)
        sh %(curl -s -L\
             -o $VOLATILE_DIR/couchdb-#{couchdb_version}.tar.gz\
             http://mirrors.gigenet.com/apache/couchdb/source/#{couchdb_version}/apache-couchdb-#{couchdb_version}.tar.gz)
        sh %(curl -s -L\
             -o $VOLATILE_DIR/js185.tar.gz\
             http://ftp.mozilla.org/pub/mozilla.org/js/js185-1.0.0.tar.gz)
        sh %(curl -s -L\
             -o $VOLATILE_DIR/icu.tar.gz\
             http://download.icu-project.org/files/icu4c/54.1/icu4c-54_1-src.tgz)
        sh %(mkdir -p #{couchdb_rootdir}/js)
        sh %(mkdir -p #{couchdb_rootdir}/icu)
        sh %(mkdir -p #{couchdb_rootdir}/erlang)
        sh %(mkdir -p $VOLATILE_DIR/couchdb)
        sh %(mkdir -p $VOLATILE_DIR/js185)
        sh %(mkdir -p $VOLATILE_DIR/icu)
        sh %(mkdir -p $VOLATILE_DIR/erlang)
        sh %(tar zxvf $VOLATILE_DIR/erlang.tar.gz\
             -C $VOLATILE_DIR/erlang --strip-components=1)
        sh %(cd $VOLATILE_DIR/erlang\
             && ./configure --prefix=#{couchdb_rootdir}/erlang\
             && make -j $CONCURRENCY\
             && make install)
        sh %(tar zxvf $VOLATILE_DIR/couchdb-#{couchdb_version}.tar.gz\
             -C $VOLATILE_DIR/couchdb --strip-components=1)
        sh %(tar zxvf $VOLATILE_DIR/js185.tar.gz\
             -C $VOLATILE_DIR/js185 --strip-components=1)
        sh %(tar zxvf $VOLATILE_DIR/icu.tar.gz\
             -C $VOLATILE_DIR/icu --strip-components=1)
        sh %(cd $VOLATILE_DIR/js185/js/src\
             && ./configure --prefix=#{couchdb_rootdir}/js\
             && make -j $CONCURRENCY\
             && make install)
        sh %(cd $VOLATILE_DIR/icu/source\
             && ./configure --prefix=#{couchdb_rootdir}/icu\
             && make -j $CONCURRENCY\
             && make install)
        sh %(cp -R $VOLATILE_DIR/erlang/lib/public_key $VOLATILE_DIR/couchdb/src/erlang-oauth/)
        ENV['ICU_CONFIG'] = "#{couchdb_rootdir}/icu/bin/icu-config"
        sh %(cd $VOLATILE_DIR/couchdb\
             && ./configure --prefix=#{couchdb_rootdir} --with-erlang=$VOLATILE_DIR/erlang/lib/ --with-js-lib=#{couchdb_rootdir}/js/lib --with-js-include=#{couchdb_rootdir}/js/include/js\
             && make -j $CONCURRENCY\
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
