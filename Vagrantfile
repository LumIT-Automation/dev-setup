# -*- mode: ruby -*-
# vi: set ft=ruby :

module OS
    # https://stackoverflow.com/questions/26811089/vagrant-how-to-have-host-platform-specific-provisioning-steps

  def OS.windows?
    (/cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM) != nil
  end

  def OS.mac?
    (/darwin/ =~ RUBY_PLATFORM) != nil
  end

  def OS.unix?
    !OS.windows?
  end

  def OS.linux?
    OS.unix? and not OS.mac?
  end
end



# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.

# The most common configuration options are documented and commented below.
# For a complete reference, please see the online documentation at
# https://docs.vagrantup.com.

Vagrant.configure("2") do |config|

  config.env.enable # enable vagrant-env(.env).

  Dir.glob('./vagrantfile-*') do |vagrantApiFile|
    eval File.read(vagrantApiFile)
  end

end

