require 'puppet/provider/package'

Puppet::Type.type(:package).provide(:taparm, :parent => Puppet::Provider::Package) do
  desc 'Tap management using HomeBrew on OSX for arm64'

  confine :operatingsystem => :darwin

  has_feature :installable
  has_feature :uninstallable

  has_feature :install_options

  commands :brew => '/opt/homebrew/bin/brew'
  commands :stat => '/usr/bin/stat'

  def self.execute(cmd, failonfail = false, combine = true)
    owner = stat('-nf', '%Uu', '/opt/homebrew/bin/brew').to_i
    group = stat('-nf', '%Ug', '/opt/homebrew/bin/brew').to_i
    home  = Etc.getpwuid(owner).dir

    if owner == 0
      raise Puppet::ExecutionFailure, 'Homebrew does not support installations owned by the "root" user. Please check the permissions of /opt/homebrew/bin/brew'
    end

    # the uid and gid can only be set if running as root
    if Process.uid == 0
      uid = owner
      gid = group
    else
      uid = nil
      gid = nil
    end

    if Puppet.features.bundled_environment?
      Bundler.with_clean_env do
        super(cmd, :uid => uid, :gid => gid, :combine => combine,
              :custom_environment => { 'HOME' => home, 'HOMEBREW_CHANGE_ARCH_TO_ARM' => '1' }, :failonfail => failonfail)
      end
    else
      super(cmd, :uid => uid, :gid => gid, :combine => combine,
            :custom_environment => { 'HOME' => home, 'HOMEBREW_CHANGE_ARCH_TO_ARM' => '1' }, :failonfail => failonfail)
    end
  end

  def execute(*args)
    # This does not return exit codes in puppet <3.4.0
    # See https://projects.puppetlabs.com/issues/2538
    self.class.execute(*args)
  end

  def install_options
    Array(resource[:install_options]).flatten.compact
  end

  def install
    resource_name = @resource[:name].downcase

    begin
      Puppet.debug "Tapping #{resource_name}"
      execute([command(:brew), :tap, resource_name, *install_options], :failonfail => true)
    rescue Puppet::ExecutionFailure => detail
      raise Puppet::Error, "Could not tap resource: #{detail}"
    end
  end

  def uninstall
    resource_name = @resource[:name].downcase

    begin
      Puppet.debug "Untapping #{resource_name}"
      execute([command(:brew), :untap, resource_name], :failonfail => true)
    rescue Puppet::ExecutionFailure => detail
      raise Puppet::Error, "Could not untap resource: #{detail}"
    end
  end

  def query
    resource_name = @resource[:name].downcase

    begin
      Puppet.debug "Querying tap #{resource_name}"
      output = execute([command(:brew), :tap])
      output.each_line do |line|
        line.chomp!
        next unless [resource_name, resource_name.gsub('homebrew-', '')].include?(line.downcase)

        return { :name => line, :ensure => 'present', :provider => 'tap' }
      end
    rescue Puppet::ExecutionFailure => detail
      Puppet.Err "Could not query tap: #{detail}"
    end

    nil
  end

  def self.instances
    taps = []

    begin
      Puppet.debug "Listing currently tapped repositories"
      output = execute([command(:brew), :tap])
      output.each_line do |line|
        line.chomp!
        next if line.empty?

        taps << new({ :name => line, :ensure => 'present', :provider => 'tap' })
      end
      taps
    rescue Puppet::ExecutionFailure => detail
      Puppet.Err "Could not list taps: #{detail}"
      nil
    end
  end
end
