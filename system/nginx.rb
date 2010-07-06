dep 'cb nginx' do
  requires \
    'cb nginx built and installed',
    'cb nginx init script',
    'cb nginx sites directories and sys config',
    'cb nginx running'
end


dep 'cb nginx built and installed' do
  requires 'cb nginx 0.7.65'
end

dep 'cb nginx 0.7.65' do
  # http://wiki.nginx.org/NginxInstall
  # http://wiki.nginx.org/NginxInstallOptions
  # http://www.cyberciti.biz/faq/debian-ubuntu-linux-install-libpcre3-dev/
  # http://freelancing-gods.com/posts/script_nginx
  requires \
    'cb passenger for nginx',
    'cb sys libs for nginx',
    'cb build-essential'
  met? {
    `nginx -V 2>&1`.include?('nginx version: nginx/0.7.65') &&
    `nginx -V 2>&1`.include?('--with-pcre') &&
    `nginx -V 2>&1`.include?('--with-http_ssl_module') &&
    `nginx -V 2>&1`.include?('--with-pcre') &&
    nil | `nginx -V 2>&1`[/--add-module=.*passenger-.*/]
  }
  meet {
    Dir.chdir '/usr/local/src'
    shell 'wget http://sysoev.ru/nginx/nginx-0.7.65.tar.gz'
    shell 'tar -xzf nginx-0.7.65.tar.gz'
    shell 'rm nginx-0.7.65.tar.gz'
    Dir.chdir 'nginx-0.7.65'
    config_cmd = <<-END_OF_STRING
      ./configure \
          --with-pcre \
          --with-http_ssl_module \
          --add-module=#{`passenger-config --root`.chomp}/ext/nginx
    END_OF_STRING
    shell config_cmd
    shell 'make'
    sudo  'make install'
    sudo  'ln -sf /usr/local/nginx/sbin/nginx /usr/local/sbin/nginx'
  }
end

dep 'cb passenger for nginx' do
  # http://www.modrails.com/documentation/Users%20guide%20Nginx.html
  requires \
    'cb rubygems',
    'cb gem rake',
    'cb build-essential'
  met? { File.exist?(`passenger-config --root 2>&1`.chomp + '/ext/nginx/HelperServer') }
  meet {
    sudo "gem install passenger"
    Dir.chdir( `passenger-config --root`.chomp + '/ext/nginx' )
    sudo "rake nginx"    # doing this now means nginx ./configure can be done without sudo
  }
end

dep 'cb sys libs for nginx' do
  requires \
    'cb libpcre3-dev', # required for URL rewriting
    'cb libssl-dev',   # required for HTTPS            # defined elsewhere
    'cb zlib1g-dev'                                    # defined elsewhere
end

dep 'cb libpcre3-dev' do
  met? { `dpkg -s libpcre3-dev 2>&1`.include?("\nStatus: install ok installed\n") }
  meet { sudo "apt-get -y install libpcre3-dev" }
end


dep 'cb nginx init script' do
  # http://articles.slicehost.com/2009/3/4/ubuntu-intrepid-adding-an-nginx-init-script
  requires \
    'cb lsb-base',
    'cb nginx built and installed'
  met? {
    File.exist?('/etc/init.d/nginx') &&
    `update-rc.d -n nginx defaults 2>&1`.include?('System start/stop links for /etc/init.d/nginx already exist.')
  }
  meet {
    render_erb "nginx/etc_init.d_nginx.erb", :to => '/etc/init.d/nginx', :sudo => true
    sudo "chmod +x /etc/init.d/nginx"
    sudo "/usr/sbin/update-rc.d -f nginx defaults"
  }
end

dep 'cb lsb-base' do
  met? { `dpkg -s lsb-base 2>&1`.include?("\nStatus: install ok installed\n") }
  meet { sudo "apt-get -y install lsb-base" }
end


dep 'cb nginx sites directories and sys config' do
  # http://articles.slicehost.com/2009/3/4/ubuntu-intrepid-nginx-from-source-layout
  requires \
    'cb nginx built and installed'
  met? {
    File.exist?('/usr/local/nginx/sites-available') &&
    File.exist?('/usr/local/nginx/sites-enabled') &&
    !changed_from_erb?('/usr/local/nginx/conf/nginx.conf', 'nginx/nginx.conf.erb')
  }
  meet {
    sudo "mkdir /usr/local/nginx/sites-available"
    sudo "mkdir /usr/local/nginx/sites-enabled"
    render_erb "nginx/nginx.conf.erb", :to => '/usr/local/nginx/conf/nginx.conf', :sudo => true
    sudo "/etc/init.d/nginx restart" if File.exist?('/usr/local/nginx/logs/nginx.pid')
  }
end


dep 'cb nginx running' do
  requires \
    'cb nginx built and installed',
    'cb nginx init script'
  met? { File.exist?('/usr/local/nginx/logs/nginx.pid') }
  meet { sudo "/etc/init.d/nginx start" }
end